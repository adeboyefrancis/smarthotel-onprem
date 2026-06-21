// =========================================================
// SmartHotel On-Premises Simulation - Stage 1
// Simulates: SmartHotelHost (Hyper-V) running 4 guest VMs
//   - UbuntuWAF        (Linux, web app firewall role)
//   - SmartHotelWeb1   (Windows, web tier)
//   - SmartHotelWeb2   (Windows, web tier)
//   - SmartHotelSQL1   (Windows + SQL Server, data tier)
// =========================================================

@description('Local admin (Windows) / sudo user (Linux) for all VMs')
param adminUsername string

@secure()
@description('Admin password - must meet Azure complexity rules (12+ chars, 3 of: upper/lower/digit/symbol)')
param adminPassword string

@description('Your public IP in CIDR form, e.g. 86.123.45.67/32 - restricts RDP/SSH/HTTP access to just you')
param allowedSourceIp string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('VM size for WAF + Web tier')
param standardVmSize string = 'Standard_B2s'

@description('VM size for SQL tier (more RAM)')
param sqlVmSize string = 'Standard_B2ms'

@description('Stage 2: deploy functional apps (IIS sites, SQL DB, Nginx WAF) on top of the infra')
param deployApps bool = true

@description('Raw GitHub content base URL for this catalog folder, e.g. https://raw.githubusercontent.com/<you>/<repo>/main/SmartHotel-OnPrem-Sim/scripts - required if deployApps is true')
param catalogRawBaseUrl string = ''

@secure()
@description('Password for the SQL app login (smarthotelapp) used by the web tier connection string - required if deployApps is true')
param sqlAppPassword string = ''

// -------------------------------
// Network: simulates the on-prem LAN behind SmartHotelHost
// -------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'SmartHotel-OnPrem-VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'SmartHotel-Subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'SmartHotel-NSG'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: allowedSourceIp
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-SSH'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: allowedSourceIp
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-HTTP-HTTPS'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['80', '443']
          sourceAddressPrefix: allowedSourceIp
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// -------------------------------
// VM definitions (the 4 boxes hanging off SmartHotelHost)
// -------------------------------
var vmConfigs = [
  {
    name: 'UbuntuWAF'
    osType: 'Linux'
    size: standardVmSize
  }
  {
    name: 'SmartHotelWeb1'
    osType: 'Windows'
    size: standardVmSize
  }
  {
    name: 'SmartHotelWeb2'
    osType: 'Windows'
    size: standardVmSize
  }
  {
    name: 'SmartHotelSQL1'
    osType: 'WindowsSQL'
    size: sqlVmSize
  }
]

var imageRefs = {
  Linux: {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
  Windows: {
    publisher: 'MicrosoftWindowsServer'
    offer: 'WindowsServer'
    sku: '2022-datacenter-azure-edition'
    version: 'latest'
  }
  WindowsSQL: {
    publisher: 'MicrosoftSQLServer'
    offer: 'sql2019-ws2022'
    sku: 'standard'
    version: 'latest'
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2023-09-01' = [for vm in vmConfigs: {
  name: '${vm.name}-pip'
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2023-09-01' = [for (vm, i) in vmConfigs: {
  name: '${vm.name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIps[i].id
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (vm, i) in vmConfigs: {
  name: vm.name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vm.size
    }
    osProfile: {
      computerName: vm.name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: imageRefs[vm.osType]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
  plan: vm.osType == 'WindowsSQL' ? {
    name: 'standard'
    publisher: 'microsoftsqlserver'
    product: 'sql2019-ws2022'
  } : null
}]

// -------------------------------
// Stage 2: Custom Script Extensions - turns the infra into a working app
// -------------------------------
var sqlPrivateIp = nics[3].properties.ipConfigurations[0].properties.privateIPAddress
var web1PrivateIp = nics[1].properties.ipConfigurations[0].properties.privateIPAddress
var web2PrivateIp = nics[2].properties.ipConfigurations[0].properties.privateIPAddress

resource sqlSetupExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (deployApps) {
  parent: vms[3]
  name: 'sql-setup'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${catalogRawBaseUrl}/sql-setup.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File sql-setup.ps1 -SqlAppPassword "${sqlAppPassword}"'
    }
  }
}

resource webSetupExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(1, 2): if (deployApps) {
  parent: vms[i]
  name: 'web-setup'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${catalogRawBaseUrl}/web-iis-setup.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File web-iis-setup.ps1 -SqlServerIp "${sqlPrivateIp}" -SqlAppPassword "${sqlAppPassword}" -ServerName "${vmConfigs[i].name}"'
    }
  }
  dependsOn: [
    sqlSetupExt
  ]
}]

resource wafSetupExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (deployApps) {
  parent: vms[0]
  name: 'waf-setup'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${catalogRawBaseUrl}/waf-nginx-setup.sh'
      ]
    }
    protectedSettings: {
      commandToExecute: 'bash waf-nginx-setup.sh ${web1PrivateIp} ${web2PrivateIp}'
    }
  }
  dependsOn: [
    webSetupExt
  ]
}

// -------------------------------
// Outputs - handy for ADE's "Outputs" tab
// -------------------------------
output ubuntuWafPublicIp string = publicIps[0].properties.ipAddress
output smartHotelWeb1PublicIp string = publicIps[1].properties.ipAddress
output smartHotelWeb2PublicIp string = publicIps[2].properties.ipAddress
output smartHotelSql1PublicIp string = publicIps[3].properties.ipAddress
output appUrl string = deployApps ? 'http://${publicIps[0].properties.ipAddress}' : 'Stage 2 not deployed - set deployApps=true'
