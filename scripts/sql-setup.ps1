param(
    [Parameter(Mandatory=$true)]
    [string]$SqlAppPassword
)

$ErrorActionPreference = "Stop"

Write-Output "=== SmartHotel SQL Setup starting ==="

# --- Enable SQL Server + Windows mixed-mode auth ---
$regPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLSERVER\MSSQLServer"
Set-ItemProperty -Path $regPath -Name "LoginMode" -Value 2
Restart-Service -Name "MSSQLSERVER" -Force
Start-Sleep -Seconds 15

# --- Open firewall for SQL traffic ---
New-NetFirewallRule -DisplayName "SQL Server 1433" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

# --- Create login, database, table, sample data ---
$sql = @"
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'smarthotelapp')
BEGIN
    CREATE LOGIN smarthotelapp WITH PASSWORD = '$SqlAppPassword', CHECK_POLICY = OFF;
END
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SmartHotelDB')
BEGIN
    CREATE DATABASE SmartHotelDB;
END
GO

USE SmartHotelDB;
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'smarthotelapp')
BEGIN
    CREATE USER smarthotelapp FOR LOGIN smarthotelapp;
    ALTER ROLE db_owner ADD MEMBER smarthotelapp;
END
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Rooms')
BEGIN
    CREATE TABLE Rooms (
        RoomId INT PRIMARY KEY IDENTITY(1,1),
        RoomNumber NVARCHAR(10) NOT NULL,
        RoomType NVARCHAR(50) NOT NULL,
        PricePerNight DECIMAL(6,2) NOT NULL,
        IsAvailable BIT NOT NULL DEFAULT 1
    );

    INSERT INTO Rooms (RoomNumber, RoomType, PricePerNight, IsAvailable) VALUES
        ('101', 'Standard Double', 89.00, 1),
        ('102', 'Standard Double', 89.00, 0),
        ('201', 'Deluxe Suite', 159.00, 1),
        ('202', 'Deluxe Suite', 159.00, 1),
        ('301', 'Penthouse', 349.00, 1);
END
GO
"@

$sql | Out-File -FilePath "C:\sql-setup.sql" -Encoding ASCII

sqlcmd -S localhost -E -i "C:\sql-setup.sql"

Write-Output "=== SmartHotel SQL Setup complete ==="
