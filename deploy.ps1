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

# Create Docker secrets directory and files
if (-not (Test-Path "docker\secrets")) {
    New-Item -ItemType Directory -Path "docker\secrets" | Out-Null
}

$secretKey | Out-File -FilePath "docker\secrets\secret_key.txt" -Encoding ascii -NoNewline
$adminUser | Out-File -FilePath "docker\secrets\admin_user.txt" -Encoding ascii -NoNewline
$plainPass | Out-File -FilePath "docker\secrets\admin_pass.txt" -Encoding ascii -NoNewline

# Write .env with UTF-8 (no BOM) for backwards compatibility
$envPath = "$WORKDIR\.env"
$envContent | Set-Content -Path $envPath -Encoding UTF8

Write-Host "`nSecrets created and .env file created with IP ${IP}:"
Get-Content $envPath

# Create SSL certificates volume and copy certificates
if ((Test-Path "cert.pem") -and (Test-Path "key.pem")) {
    Write-Host "`nCreating SSL certificates volume..."
    docker volume create ssl_certs | Out-Null
    $unixPath = $WORKDIR.Replace('\', '/').Replace('C:', '/c')
    docker run --rm -v ssl_certs:/certs -v "${unixPath}:/host" alpine sh -c "ls -la /host/ && cp /host/cert.pem /host/key.pem /certs/ && ls -la /certs/"
    Write-Host "SSL certificates copied to Docker volume."
} else {
    Write-Host "`nWarning: cert.pem or key.pem not found. SSL certificates will need to be provided manually." -ForegroundColor Yellow
}

# Stop existing container (if any)
try { docker stop tide-recorder-server-https | Out-Null } catch {}
try { docker rm tide-recorder-server-https | Out-Null } catch {}

# Use docker-compose for deployment
Write-Host "`nStarting application with docker-compose..."
Set-Location "docker"
docker-compose up -d --build
Set-Location ".."

Write-Host "`nDocker container 'tide-recorder-server-https' started at https://${IP}:5000/login" -ForegroundColor Green
