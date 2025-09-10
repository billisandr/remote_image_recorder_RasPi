# Remote image recorder – Raspberry Pi Setup & Https server

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

### .dockerignore Configuration

```
.env
cert.pem
key.pem
__pycache__/
*.pyc
*.log
.git/
uploads/
raspi_files/
```

### Docker Compose Configuration

Example `docker-compose.yml` for HTTPS support:

```yaml
version: "3.8"

services:
  web:
    build: .
    container_name: tide-recorder-server-https
    image: tide-recorder-server-https
    ports:
      - "5000:5000"
    volumes:
      - ./uploads:/app/uploads
      - ./.env:/app/.env
      - ./cert.pem:/app/cert.pem
      - ./key.pem:/app/key.pem
    environment:
      - SECRET_KEY=${SECRET_KEY}
      - ADMIN_USER=${ADMIN_USER}
      - ADMIN_PASS=${ADMIN_PASS}
    restart: always
```

### Docker Development

```bash
# Build and start server
docker compose build
docker compose up --build -d

# Quick deploy (Windows)
./deploy.ps1

# Stop and cleanup
docker compose down
docker system prune -af

# Rebuild after changes
docker compose down
docker compose up --build -d
```

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

Required `.env` file variables:

- `SECRET_KEY` - Flask session encryption key
- `ADMIN_USER` - Web interface username
- `ADMIN_PASS` - Web interface password
- `FLASH_GPIO` - GPIO pin for camera flash (Pi only)
- `PHOTO_INTERVAL` - Seconds between captures (Pi only)
- `SERVER_URL` - Upload endpoint URL (Pi only)

## Key Endpoints

- `/login` - Authentication page
- `/upload` - POST endpoint for image uploads (from Pi)
- `/gallery` - Protected web interface for viewing photos
- `/photos` - JSON API for photo metadata
- `/uploads/<filename>` - Serve uploaded images

## File Structure

```
tide-recorder-server-https/
├── raspi_files/           # Raspberry Pi scripts
│   ├── photo_logger.py    # Main capture script
│   ├── gps_to_rtc_sync.sh # GPS time synchronization
│   ├── gps-to-rtc.service # Systemd service configuration
│   └── gps-to-rtc.timer   # Systemd timer configuration
├── templates/             # HTML templates
│   ├── gallery.html       # Photo gallery interface  
│   └── login.html         # Authentication page
├── uploads/               # Uploaded images directory
├── .dockerignore          # Docker ignore file
├── .env                   # Environment variables
├── key.pem                # SSL private key (generated)
├── cert.pem               # SSL certificate (generated)
├── app.py                 # Main Flask application
├── Dockerfile             # Container build instructions
├── docker-compose.yml     # Container orchestration
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

- Server uses self-signed HTTPS certificates
- Client uploads bypass SSL verification (verify=False) for development
- **Certificate Distribution**: Share `cert.pem` with Pi clients, keep `key.pem` server-only
- Browser will show security warnings for self-signed certificates - you can safely proceed for local development
- Authentication via Flask-Login session management
- Passwords hashed with Werkzeug security functions
- Remember to modify `.env` file to set desired login credentials

## License

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)