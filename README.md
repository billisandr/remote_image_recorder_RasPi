# Remote image recorder – Raspberry Pi Setup & HTTPS server

Remote image recorder system through Raspberry Pi and flask server

> Developed at the [SenseLAB](http://senselab.tuc.gr/) of the [Technical University of Crete](https://www.tuc.gr/el/archi)

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/downloads/)
---

## Project Overview

This is a remote image recorder system for tide monitoring consisting of:

1. **HTTPS Flask Server** - Dockerized web server for receiving and displaying timestamped images
2. **Raspberry Pi Client** - Captures images with GPS-synced timestamps and uploads to server

The system is designed for Raspberry Pi equipped with:

- Raspberry Pi camera or USB camera
- Real-time clock (RTC) module
- uBlox GPS module for precise time synchronization

## Quick Start

The easiest way to deploy the server (Windows):

```bash
# Handles SSL certificates and Docker secrets automatically
./deploy.ps1
```

After deployment, verify success by looking for:

```txt
Docker container 'tide-recorder-server-https' started at https://<SERVER_IP>:5000
```

Access the web interface at the provided URL:
- You will receive a browser warning due to the self-signed certificate (safe to proceed for local development)
- Login page will request credentials (auto-generated and stored in docker/secrets/)

## Architecture

### Server Components (app.py)

- **Flask app with HTTPS** - Uses self-signed certificates (cert.pem/key.pem)
- **Authentication system** - Flask-Login with admin credentials from environment
- **SQLite database** - Stores photo metadata (filename, timestamp)
- **File upload handling** - Stores images in uploads/ directory
- **Web gallery** - Protected interface for viewing uploaded photos

### Raspberry Pi Components (raspi_files/)

- **photo_logger.py** - Main capture script using rpicam-still or fswebcam
- **GPS-RTC sync system** - Systemd services for accurate timestamping
- **GPIO flash control** - Optional LED flash for low-light conditions

## Requirements

- Docker and Docker Compose
- Flask app with `app.py` configured for HTTPS
- OpenSSL (available via Git Bash, WSL, or native install)

## Common Operations

### SSL Certificate Generation

Use the provided script to generate a self-signed certificate with a Subject Alternative Name (SAN). This is required for modern browsers and the Raspberry Pi client to accept the certificate without errors.

Run from inside `tide-recorder-server-https/` using Git Bash or WSL:

```bash
bash gen_certs.sh
```

The script prompts for the server IP or hostname — no sensitive data is hard-coded or logged. It auto-detects whether to set a `IP:` or `DNS:` SAN and prints a cert summary on completion.

Then re-run `deploy.ps1` to push the new certs into the Docker volume and restart the container:

```txt
./deploy.ps1
```

> Note: Browsers will still show a "Not Secure" warning because the certificate is self-signed (no trusted CA). This is expected for a private system. The SAN fix resolves connection errors on the Pi client.

### Docker Development

```bash
# Quick deploy (Windows) - handles SSL certificates and Docker secrets automatically
./deploy.ps1

# Manual deployment from docker directory
cd docker
docker-compose up --build -d

# Stop and cleanup
cd docker && docker-compose down
docker system prune -af

# Rebuild after changes
cd docker
docker-compose down
docker-compose up --build -d
```

> **Note**: All Docker-related files are organized in the `docker/` directory. The system now uses Docker secrets for secure credential management instead of environment variables. See `docker/README.md` for detailed setup instructions.

### Docker Success Verification

After running `./deploy.ps1`, look for:

```txt
Docker container 'tide-recorder-server-https' started at https://<SERVER_IP>:5000
```

> Note 1: You will receive a browser warning due to the self-signed certificate. You can safely proceed through the warning for local development.  
> Note 2: The flask app will be available at the provided url, and a login page will request credentials.

### Python Dependencies

```bash
# Install requirements
pip install -r requirements.txt
```

### Docker System Maintenance

```bash
# View running containers
docker ps

# Clean up unused Docker resources
docker system prune -af

# Remove specific container
docker rm tide-recorder-server-https

# Remove specific image
docker rmi tide-recorder-server-https
```

## Environment Configuration

### Raspberry Pi Client Configuration (`.env` file):

- `FLASH_GPIO` - GPIO pin for camera flash
- `PHOTO_INTERVAL` - Seconds between captures  
- `SERVER_URL` - Upload endpoint URL (e.g., https://SERVER_IP:5000/upload)

### Server Credentials (Docker Secrets):

Server authentication is managed through Docker secrets in `docker/secrets/`:
- `secret_key.txt` - Flask session encryption key
- `admin_user.txt` - Web interface username  
- `admin_pass.txt` - Web interface password

> **Security Note**: Server credentials are no longer stored in `.env` files. The deploy script automatically generates and stores them securely using Docker secrets.

## Key Endpoints

- `/login` - Authentication page
- `/upload` - POST endpoint for image uploads (from Pi)
- `/gallery` - Protected web interface for viewing photos
- `/photos` - JSON API for photo metadata
- `/uploads/<filename>` - Serve uploaded images
- `/health` - Health check endpoint for monitoring (returns JSON status)

## File Structure

```txt
tide-recorder-server-https/
├── docker/                # Docker configuration directory
│   ├── secrets/           # Docker secrets (auto-generated)
│   ├── .dockerignore      # Docker ignore file
│   ├── Dockerfile         # Container build instructions
│   ├── docker-compose.yml # Container orchestration with security
│   ├── entrypoint.sh      # Fixes volume ownership at startup, drops to appuser
│   └── README.md          # Docker setup instructions
├── raspi_files/           # Raspberry Pi scripts
│   ├── photo_logger.py    # Main capture script
│   ├── gps_to_rtc_sync.sh # GPS time synchronization
│   ├── gps-to-rtc.service # Systemd service configuration
│   └── gps-to-rtc.timer   # Systemd timer configuration
├── templates/             # HTML templates
│   ├── gallery.html       # Photo gallery interface  
│   └── login.html         # Authentication page
├── uploads/               # Uploaded images directory
├── .env                   # Environment variables (legacy support)
├── key.pem                # SSL private key (generated)
├── cert.pem               # SSL certificate (generated)
├── app.py                 # Main Flask application
├── requirements.txt       # Python dependencies
├── deploy.ps1             # Windows deployment script
└── README.md              # Project documentation
```

## Database Schema

SQLite database `photo_log.db`:

```sql
CREATE TABLE photos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT,
    timestamp TEXT
);
```

## Raspberry Pi Setup

### Required File Locations

Copy `raspi_files/` contents to these Pi locations:

- `/usr/local/bin/gps_to_rtc_sync.sh`
- `/usr/local/bin/photo_logger.py`  
- `/etc/systemd/system/gps-to-rtc.service`
- `/etc/systemd/system/gps-to-rtc.timer`

### File Permissions Setup

```bash
# Make script executable
sudo chmod +x /usr/local/bin/gps_to_rtc_sync.sh
```

### GPS-RTC Time Sync Service

```bash
# Enable and start timer
sudo systemctl enable gps-to-rtc.timer
sudo systemctl start gps-to-rtc.timer

# Check all system timers
sudo systemctl list-timers --all

# Monitor specific timer and service
sudo systemctl status gps-to-rtc.timer
sudo journalctl -u gps-to-rtc.service
cat /var/log/gps_rtc_sync.log
```

### Pi Client Configuration

`photo_logger.py` reads its configuration from a `.env` file in the same directory (`/usr/local/bin/.env`). This file must be created manually on the Pi — it is not copied automatically.

Create it with:

```bash
sudo nano /usr/local/bin/.env
```

Add the following contents (update `SERVER_URL` to match your server's LAN IP):

```txt
FLASH_GPIO=5
PHOTO_INTERVAL=30
SERVER_URL=https://<docker_server_ip>:5000/upload
```

Save and exit. Without this file, `photo_logger.py` will fall back to the hardcoded default IP in the script, which will likely be wrong.

To find the correct server IP on Windows, run `ipconfig` and use the Ethernet or Wi-Fi adapter address — not any `172.x.x.x` addresses, which are Docker or WSL virtual adapters.

### Manual Photo Capture

```bash
# Start image capture (after server is running and .env is configured)
sudo python3 /usr/local/bin/photo_logger.py
```

> **Note**: This step could be converted to a system service as well, instead of manual start/stop.

## Image Storage Locations

Captured images are stored in three locations:

1. `/home/<username>/captured/` - Local Pi storage
2. `/tide-recorder-server-https/uploads/` - Server directory (Docker volume)
3. Server web interface - Gallery view at `/gallery` (read-only access)

## Troubleshooting

### GPS-RTC Service Issues

```bash
# Reload and restart services
sudo systemctl daemon-reload
sudo systemctl enable --now gps-to-rtc.timer
sudo systemctl restart gps-to-rtc.service

# Verify timer is active
sudo systemctl list-timers --all | grep gps-to-rtc

# Check service logs for errors
sudo journalctl -u gps-to-rtc.service -n 50 --no-pager
sudo journalctl -u gps-to-rtc.service -f #real-time tailing
cat /var/log/gps_rtc_sync.log
```

Expected output for active timer:
```txt
NEXT                         LEFT          LAST                         PASSED       UNIT                ACTIVATES
Mon 2024-XX-XX 12:00:00 UTC  Xmin Xs left  Mon 2024-XX-XX 11:55:00 UTC  Xmin Xs ago  gps-to-rtc.timer    gps-to-rtc.service
```

### Docker Secrets Mount Failure (WSL2 Drive Mount Stale)

**Symptom:**

```txt
Error response from daemon: invalid mount config for type "bind": stat /run/desktop/mnt/host/h/...: no such device
```

**Cause:** Docker Desktop translates Windows drive paths (e.g., `H:`) into WSL2 mount points at `/run/desktop/mnt/host/h`. After a system sleep, restart, or Docker Desktop restart, this automount can go stale — the path exists on Windows but the WSL2 device node is broken.

**Fix — Reset the WSL2 mount:**

```txt
# In PowerShell (run as Administrator)
wsl --shutdown
# Wait ~5 seconds, then start Docker Desktop again
```

After Docker Desktop restarts, re-run `deploy.ps1` or `docker-compose up`.

**Permanent fix:** Move the project to the `C:` drive. WSL2 automounts `C:` reliably; secondary drives (e.g., `H:`) are prone to this issue.

## Security Notes

### SSL/TLS Security
- Server uses self-signed HTTPS certificates for development
- Client uploads bypass SSL verification (verify=False) for development
- **Certificate Distribution**: Share `cert.pem` with Pi clients, keep `key.pem` server-only
- Browser will show security warnings for self-signed certificates - you can safely proceed for local development

### Credential Management
- **Docker Secrets**: Server credentials stored securely in Docker secrets, not environment variables
- **Authentication**: Flask-Login session management with secure password hashing (Werkzeug)
- **Container Security**: Non-root user execution, read-only certificate volumes, no new privileges
- **Multi-stage Build**: Smaller attack surface with dependency separation
- **Health Monitoring**: Built-in health checks for container monitoring

### Production Recommendations
- Replace self-signed certificates with CA-issued certificates
- Use external secrets management (e.g., Docker Swarm secrets, Kubernetes secrets)
- Enable container resource limits and monitoring
- Implement proper log management and rotation

## Deployment Checklist

### Server (Windows host)

- [ ] Docker Desktop is running (restart it / `wsl --shutdown` if mounts fail — see [Troubleshooting](#docker-secrets-mount-failure-wsl2-drive-mount-stale))
- [ ] SSL certificate generated with the correct SAN for the server's LAN IP (`bash gen_certs.sh`)
- [ ] `./deploy.ps1` run successfully and prints `Docker container 'tide-recorder-server-https' started at https://<SERVER_IP>:5000`
- [ ] `docker ps` shows the container as `healthy`
- [ ] Web interface reachable at `https://<SERVER_IP>:5000` and login page loads
- [ ] Admin credentials retrieved from `docker/secrets/admin_user.txt` and `admin_pass.txt`
- [ ] Note the server's LAN IP (`ipconfig`, Ethernet/Wi-Fi adapter — not `172.x.x.x`) for the Pi `.env`

### Raspberry Pi Client

- [ ] Camera connected and enabled (`rpicam-still` or `fswebcam` working)
- [ ] RTC module wired and detected (`hwclock --show` returns a valid time)
- [ ] GPS module wired to `/dev/serial0` (TX→RXD pin 10, RX→TXD pin 8, VCC, GND)
- [ ] Pi UART configured for the GPS module (serial console disabled, `dtoverlay=disable-bt` if needed)
- [ ] `gpsd` running and producing `TPV` fixes (`gpspipe -w -n 5` shows position data)
- [ ] `raspi_files/` copied to required locations (see [Required File Locations](#required-file-locations))
- [ ] `gps_to_rtc_sync.sh` is executable (`sudo chmod +x`)
- [ ] `gps-to-rtc.timer` enabled and active (`sudo systemctl status gps-to-rtc.timer`)
- [ ] First sync completed successfully (`cat /var/log/gps_rtc_sync.log` shows "RTC updated from GPS time")
- [ ] `/usr/local/bin/.env` created with `FLASH_GPIO`, `PHOTO_INTERVAL`, and `SERVER_URL` matching the server's LAN IP
- [ ] `cert.pem` from the server copied to the Pi (if required by `photo_logger.py` for SSL verification)
- [ ] `photo_logger.py` runs and successfully uploads a test image (visible in server `/gallery`)

## License
This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) file for details. 

