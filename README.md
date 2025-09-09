# Remote image recorder – Raspberry Pi Setup & Https server

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/downloads/)

This guide walks you through setting up a dockerized Flask-based HTTPS server (with self-signed certificate) locally or on a Raspberry Pi. The HTTPS server is used to store timestamped images captured through a Raspberry Pi eqquiped with Raspberry Pi camera, an RTC, and a uBlox GPS module.

> Disclaimer: This work is part of a non-funded prototype research idea condacted  at the [SenseLAB](http://senselab.tuc.gr/) of the [TUC](https://www.tuc.gr/el/archi).

## PART I: HTTPS Server

## Requirements

- Docker and Docker Compose
- Flask app with `app.py` configured for HTTPS
- OpenSSL (available via Git Bash, WSL, or native install)

## I.1. Project Structure Example

```
tide-recorder-server-https/
├── raspi_files/
├── templates/
     ├── gallery.html
     └── login.html
├── uploads/
├── .dockerignore
├── .env
├── key.pem
├── cert.pem
├── app.py
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── deploy.sl1
└──README.md
```

## I.2. Generate a Self-Signed Certificate

In your project folder, run the following command using Git Bash or WSL:

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

When prompted, set the Common Name (CN) to `localhost` or your Pi’s IP address.

## I.3. Docker Compose Configuration

Here’s an example `docker-compose.yml` to support self-signed HTTPS:

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

## I.4. Build and Run the Container

```bash
docker compose build
docker compose up --build -d
```

Make sure the docker machine has started successfully, and run on PowerShell or Command Window:

```bash
./deploy.ps1
```

If the last command runs successfully a message will appear:
Docker container 'tide-recorder-server-https' started at [https://\<SERVER\_IP>:5000](https://<SERVER_IP>:5000)

> Note 1: You will receive a browser warning due to the self-signed certificate. You can safely proceed through the warning for local development.  
> Note 2: The flask app will be available at the provided url, and a login page will request credentials.

## I.5. Recommended .dockerignore

To avoid copying sensitive files into your Docker image:

```
.env
key.pem
cert.pem
__pycache__/
*.pyc
*.log
```

## I.6. Cleanup and Reuse

To rebuild the container:

```bash
docker compose down
docker compose up --build -d
```

To clean up unused Docker resources:

```bash
docker system prune -af
```

---

## PART II: Raspberry Pi Setup

## II.1. Required files on Raspberry Pi

The scripts and bash files included in the 'raspi_files' directory should be copied to the Raspberry Pi as follows:

a) /usr/local/bin/gps_to_rtc_sync.sh
b) /usr/local/bin/photo_logger.py  
c) /etc/systemd/system/gps-to-rtc.service  
d) /etc/systemd/system/gps-to-rtc.timer  

## II.2. Setup RTC and GPS time sync as a system service

Make bash file executable:

```bash
sudo chmod +x /usr/local/bin/gps_to_rtc_sync.sh
```

Enable timer and check if service and timer work:

```bash
sudo systemctl enable gps-to-rtc.timer
sudo systemctl start gps-to-rtc.timer
```

Checks and log files

```bash
sudo systemctl list-timers –all #see all timers
sudo systemctl status gps-to-rtc.timer #see specific timer
sudo journalctl -u gps-to-rtc.service #see service log files
cat /var/log/gps_to_rtc_sync.log #see alternative service log files
```

Reload and restart system service (troubleshooting only)

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now gps-to-rtc.timer
sudo systemctl restart gps-to-rtc.service
```

## II.3. Start capturing images (manually)

Run on the Raspberry Pi (after making sure that the HTTPS server is up):

```bash
sudo python3 /usr/local/bin/photo_logger.py
```

> Note: This step could be converted to a system service as well, instead of manual start/stop.

## II.4 Find captured images

You now have an image recorder setup on your Raspberry Pi =, which uploads the captured images on your HTTPS server. The captured images can be found in 3 locations:  
a) /home/<username>/captured directory on Raspberry Pi,  
b) /tide-recorder-server-https/uploads directory on the server machine, and  
c) the server url (read-only).

## Final notes
>
> Note 1: Remember to share the "cert.pem" file with the clients that need to have access to the server to upload or view the server (e.g. Rasp Pi uploading photos). Keep key.pem on the server only.  
> Note 2: Remember to modify the .env file and set the environment params to correctly set the desired login credentials.

---

## License

[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
