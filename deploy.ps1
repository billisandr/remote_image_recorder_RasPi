# Set working directory
$WORKDIR = "$PSScriptRoot"
Set-Location $WORKDIR

# Get the local IP address using .NET
${IP} = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
    Where-Object { $_.AddressFamily -eq 'InterNetwork' -and $_.IPAddressToString -notlike '169.*' } |
    Select-Object -First 1

${IP} = ${IP}.IPAddressToString

if (-not ${IP}) {
    Write-Host "Could not detect a valid IP address." -ForegroundColor Red
    exit 1
}

# Prompt for credentials
$adminUser = Read-Host "Enter admin username"
$adminPass = Read-Host "Enter admin password (input hidden)" -AsSecureString
$plainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass)
)
$secretKey = [guid]::NewGuid().ToString()

# Create .env content
$envContent = @"
FLASH_GPIO=5
PHOTO_INTERVAL=30
SERVER_URL=https://${IP}:5000/upload

# Login credentials for web server
ADMIN_USER=$adminUser
ADMIN_PASS=$plainPass
SECRET_KEY=$secretKey
"@

# Write .env with UTF-8 (no BOM)
$envPath = "$WORKDIR\.env"
$envContent | Set-Content -Path $envPath -Encoding UTF8

Write-Host "`n.env file created with IP ${IP}:"
Get-Content $envPath

# Stop existing container (if any)
try { docker stop tide-recorder-server-https | Out-Null } catch {}
try { docker rm tide-recorder-server-https | Out-Null } catch {}

# Run container
docker run -d `
  --env-file .env `
  -p 5000:5000 `
  -v "$WORKDIR\uploads:/app/uploads" `
  -v "$WORKDIR\cert.pem:/app/cert.pem" `
  -v "$WORKDIR\key.pem:/app/key.pem" `
  --name tide-recorder-server-https `
  tide-recorder-server-https

Write-Host "`nDocker container 'tide-recorder-server-https' started at https://${IP}:5000/login" -ForegroundColor Green
