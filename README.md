# Remote image recorder – Raspberry Pi Setup & HTTPS server

## Project Overview

This is a remote image recorder system for tide monitoring consisting of:

1. **HTTPS Flask Server** - Dockerized web server for receiving and displaying timestamped images
2. **Raspberry Pi Client** - Captures images with GPS-synced timestamps and uploads to server

The system is designed for Raspberry Pi equipped with:

- Raspberry Pi camera or USB camera
- Real-time clock (RTC) module
- uBlox GPS module for precise time synchronization

> **Disclaimer**: This is a non-funded prototype research project conducted at the [SenseLAB](http://senselab.tuc.gr/) of the [TUC](https://www.tuc.gr/el/archi). Licensed under BSD 3-Clause.

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/downloads/)

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

## Common Development Steps

### SSL Certificate Generation

```bash
# Generate self-signed certificates (required for HTTPS)
# Set Common Name (CN) to 'localhost' or Pi's IP address when prompted
# Use Git Bash, WSL, or OpenSSL directly
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

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

```
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

```
tide-recorder-server-https/
├── docker/                # Docker configuration directory
│   ├── secrets/           # Docker secrets (auto-generated)
│   ├── .dockerignore      # Docker ignore file
│   ├── Dockerfile         # Container build instructions
│   ├── docker-compose.yml # Container orchestration with security
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

### Troubleshooting GPS-RTC Service

```bash
# Reload and restart (troubleshooting only)
sudo systemctl daemon-reload
sudo systemctl enable --now gps-to-rtc.timer
sudo systemctl restart gps-to-rtc.service
```

### Manual Photo Capture

```bash
# Set server URL environment variable (update IP as needed)
export SERVER_URL=https://<docker_server_ip>:5000/upload

# Start image capture (after server is running)
sudo python3 /usr/local/bin/photo_logger.py
```

> **Note**: This step could be converted to a system service as well, instead of manual start/stop.

## Image Storage Locations

Captured images are stored in three locations:

1. `/home/<username>/captured/` - Local Pi storage
2. `/tide-recorder-server-https/uploads/` - Server directory (Docker volume)
3. Server web interface - Gallery view at `/gallery` (read-only access)

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

## License

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)