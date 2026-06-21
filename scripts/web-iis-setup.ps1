param(
    [Parameter(Mandatory=$true)]
    [string]$SqlServerIp,

    [Parameter(Mandatory=$true)]
    [string]$SqlAppPassword,

    [Parameter(Mandatory=$true)]
    [string]$ServerName
)

$ErrorActionPreference = "Stop"

Write-Output "=== SmartHotel Web Setup starting on $ServerName ==="

# --- Install IIS + ASP.NET 4.8 ---
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, NET-Framework-45-ASPNET -IncludeManagementTools

# --- Open firewall for HTTP ---
New-NetFirewallRule -DisplayName "HTTP 80" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

$siteRoot = "C:\inetpub\wwwroot"

# --- web.config: connection string to the SQL VM ---
$webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <connectionStrings>
    <add name="SmartHotelDB"
         connectionString="Server=$SqlServerIp;Database=SmartHotelDB;User Id=smarthotelapp;Password=$SqlAppPassword;TrustServerCertificate=True;"
         providerName="System.Data.SqlClient" />
  </connectionStrings>
  <system.web>
    <compilation debug="false" targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" />
  </system.web>
</configuration>
"@
$webConfig | Out-File -FilePath "$siteRoot\web.config" -Encoding UTF8

# --- Default.aspx: proves the full stack is wired up end-to-end ---
$page = @"
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>
<!DOCTYPE html>
<html>
<head>
    <title>SmartHotel - $ServerName</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 40px; background: #f4f6f8; }
        h1 { color: #2b4c7e; }
        .badge { display: inline-block; background: #2b4c7e; color: white; padding: 4px 10px; border-radius: 4px; font-size: 13px; }
        table { border-collapse: collapse; width: 100%; max-width: 700px; margin-top: 20px; background: white; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background: #2b4c7e; color: white; }
        .available { color: green; font-weight: bold; }
        .booked { color: #b00020; font-weight: bold; }
    </style>
</head>
<body>
    <h1>SmartHotel360 <span class="badge">Served by $ServerName</span></h1>
    <p>Live room data pulled from SQL tier (<%= "$SqlServerIp" %>):</p>
    <table>
        <tr><th>Room</th><th>Type</th><th>Price/Night</th><th>Status</th></tr>
        <%
            string connStr = ConfigurationManager.ConnectionStrings["SmartHotelDB"].ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                SqlCommand cmd = new SqlCommand("SELECT RoomNumber, RoomType, PricePerNight, IsAvailable FROM Rooms ORDER BY RoomNumber", conn);
                SqlDataReader reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    string status = reader.GetBoolean(3) ? "<span class=\"available\">Available</span>" : "<span class=\"booked\">Booked</span>";
                    Response.Write("<tr><td>" + reader.GetString(0) + "</td><td>" + reader.GetString(1) + "</td><td>" + Convert.ToDecimal(reader[2]).ToString("C") + "</td><td>" + status + "</td></tr>");
                }
            }
        %>
    </table>
</body>
</html>
"@
$page | Out-File -FilePath "$siteRoot\Default.aspx" -Encoding UTF8

# --- Remove default IIS welcome page, make Default.aspx the default doc ---
Remove-Item "$siteRoot\iisstart.htm" -ErrorAction SilentlyContinue
Import-Module WebAdministration
Clear-WebConfiguration -Filter "/system.webServer/defaultDocument/files" -PSPath "IIS:\"
Add-WebConfiguration -Filter "/system.webServer/defaultDocument/files" -PSPath "IIS:\" -Value @{value="Default.aspx"}

Write-Output "=== SmartHotel Web Setup complete on $ServerName ==="param(
    [Parameter(Mandatory=$true)]
    [string]$SqlServerIp,

    [Parameter(Mandatory=$true)]
    [string]$SqlAppPassword,

    [Parameter(Mandatory=$true)]
    [string]$ServerName
)

$ErrorActionPreference = "Stop"

Write-Output "=== SmartHotel Web Setup starting on $ServerName ==="

# --- Install IIS + ASP.NET 4.8 ---
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45, NET-Framework-45-ASPNET -IncludeManagementTools

# --- Open firewall for HTTP ---
New-NetFirewallRule -DisplayName "HTTP 80" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

$siteRoot = "C:\inetpub\wwwroot"

# --- web.config: connection string to the SQL VM ---
$webConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <connectionStrings>
    <add name="SmartHotelDB"
         connectionString="Server=$SqlServerIp;Database=SmartHotelDB;User Id=smarthotelapp;Password=$SqlAppPassword;TrustServerCertificate=True;"
         providerName="System.Data.SqlClient" />
  </connectionStrings>
  <system.web>
    <compilation debug="false" targetFramework="4.8" />
    <httpRuntime targetFramework="4.8" />
  </system.web>
</configuration>
"@
$webConfig | Out-File -FilePath "$siteRoot\web.config" -Encoding UTF8

# --- Default.aspx: proves the full stack is wired up end-to-end ---
$page = @"
<%@ Page Language="C#" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>
<!DOCTYPE html>
<html>
<head>
    <title>SmartHotel - $ServerName</title>
    <style>
        body { font-family: Segoe UI, Arial, sans-serif; margin: 40px; background: #f4f6f8; }
        h1 { color: #2b4c7e; }
        .badge { display: inline-block; background: #2b4c7e; color: white; padding: 4px 10px; border-radius: 4px; font-size: 13px; }
        table { border-collapse: collapse; width: 100%; max-width: 700px; margin-top: 20px; background: white; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background: #2b4c7e; color: white; }
        .available { color: green; font-weight: bold; }
        .booked { color: #b00020; font-weight: bold; }
    </style>
</head>
<body>
    <h1>SmartHotel360 <span class="badge">Served by $ServerName</span></h1>
    <p>Live room data pulled from SQL tier (<%= "$SqlServerIp" %>):</p>
    <table>
        <tr><th>Room</th><th>Type</th><th>Price/Night</th><th>Status</th></tr>
        <%
            string connStr = ConfigurationManager.ConnectionStrings["SmartHotelDB"].ConnectionString;
            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();
                SqlCommand cmd = new SqlCommand("SELECT RoomNumber, RoomType, PricePerNight, IsAvailable FROM Rooms ORDER BY RoomNumber", conn);
                SqlDataReader reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    string status = reader.GetBoolean(3) ? "<span class=\"available\">Available</span>" : "<span class=\"booked\">Booked</span>";
                    Response.Write("<tr><td>" + reader.GetString(0) + "</td><td>" + reader.GetString(1) + "</td><td>" + Convert.ToDecimal(reader[2]).ToString("C") + "</td><td>" + status + "</td></tr>");
                }
            }
        %>
    </table>
</body>
</html>
"@
$page | Out-File -FilePath "$siteRoot\Default.aspx" -Encoding UTF8

# --- Remove default IIS welcome page, make Default.aspx the default doc ---
Remove-Item "$siteRoot\iisstart.htm" -ErrorAction SilentlyContinue
Import-Module WebAdministration
Clear-WebConfiguration -Filter "/system.webServer/defaultDocument/files" -PSPath "IIS:\"
Add-WebConfiguration -Filter "/system.webServer/defaultDocument/files" -PSPath "IIS:\" -Value @{value="Default.aspx"}

Write-Output "=== SmartHotel Web Setup complete on $ServerName ==="
