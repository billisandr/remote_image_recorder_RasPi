#!/usr/bin/env python3

import os
import time
import subprocess
import requests
import RPi.GPIO as GPIO
from datetime import datetime
from dotenv import load_dotenv

# Load .env file
load_dotenv()

# Read environment variables
FLASH_GPIO = int(os.getenv("FLASH_GPIO", 5))
PHOTO_INTERVAL = int(os.getenv("PHOTO_INTERVAL", 30))
SERVER_URL = os.getenv("SERVER_URL", "https://147.27.118.210:5000/upload")

# Setup flash GPIO
GPIO.setmode(GPIO.BCM)
GPIO.setup(FLASH_GPIO, GPIO.OUT)

SAVE_DIR = "/home/pi/captured"
os.makedirs(SAVE_DIR, exist_ok=True)

def get_rtc_time():
    try:
        output = subprocess.check_output(["hwclock", "-r"]).decode().strip()
        dt = datetime.strptime(output, "%Y-%m-%d %H:%M:%S.%f" if '.' in output else "%Y-%m-%d %H:%M:%S")
        return dt.isoformat()
    except Exception as e:
        print("[ERROR] Failed to read RTC:", e)
        return datetime.now().isoformat()

def capture_photo_usb():
    filename = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    filepath = os.path.join(SAVE_DIR, filename)

    print(f"[FLASH] GPIO {FLASH_GPIO} ON")
    GPIO.output(FLASH_GPIO, GPIO.LOW)

    # Wait for flash to stabilize (adjust based on your hardware)
    time.sleep(0.7)  # try increasing if needed

    try:
        result = subprocess.run(["fswebcam", "-r", "1280x640", "--jpeg", "95", "--no-banner", "--set", "Brightness=85%", "--set", "Contrast=60%", "--set", "Gain=210", "--set", "Exposure=Auto", "--set", "White Balance Temperature, Auto=1", filepath], timeout=5) # fail if it takes longer than 20 seconds

        #GPIO.output(FLASH_GPIO,GPIO.LOW)

        if result.returncode == 0:
            print(f"[CAPTURE] Photo saved to {filepath}")
            return filepath
        else:
            print("[ERROR] fswebcam failed with return code", result.returncode)
            return None

    except subprocess.TimeoutExpired:
        print("[ERROR] fswebcam timed out")
        return None

    except Exception as e:
        print(f"[ERROR] Unexpected capture error: {e}")
        return None

    finally:
        print(f"[FLASH] GPIO {FLASH_GPIO} OFF")
        GPIO.output(FLASH_GPIO, GPIO.HIGH)


def capture_photo_picam_fl():
    filename = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    filepath = os.path.join(SAVE_DIR, filename)

    # Make sure the save directory exists
    os.makedirs(SAVE_DIR, exist_ok=True)

    print(f"[FLASH] GPIO {FLASH_GPIO} ON")
    GPIO.output(FLASH_GPIO, GPIO.LOW)

    # Allow the flash/LED to stabilize; adjust if needed for your hardware
    time.sleep(0.7)

    cmd = [
        "rpicam-still",
        "--width", "640",
        "--height", "480",
        "-t", "1000",          # 1s warm-up
        "-o", filepath
    ]

    try:
        # timeout can be tuned; 10s gives room for startup/capture
        result = subprocess.run(cmd, timeout=10)

        if result.returncode == 0 and os.path.isfile(filepath):
            print(f"[CAPTURE] Photo saved to {filepath}")
            return filepath
        else:
            print("[ERROR] picam-still failed with return code", result.returncode)
            return None

    except subprocess.TimeoutExpired:
        print("[ERROR] picam-still timed out")
        return None

    except Exception as e:
        print(f"[ERROR] Unexpected capture error: {e}")
        return None

    finally:
        print(f"[FLASH] GPIO {FLASH_GPIO} OFF")
        GPIO.output(FLASH_GPIO, GPIO.HIGH)
        
def capture_photo_picam():
    filename = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg"
    filepath = os.path.join(SAVE_DIR, filename)

    # Make sure the save directory exists
    os.makedirs(SAVE_DIR, exist_ok=True)

    cmd = [
        "rpicam-still",
        "--width", "640",
        "--height", "480",
        "-t", "1000",          # 1s warm-up
        "-o", filepath
    ]

    try:
        # timeout can be tuned; 10s gives room for startup/capture
        result = subprocess.run(cmd, timeout=10)

        if result.returncode == 0 and os.path.isfile(filepath):
            print(f"[CAPTURE] Photo saved to {filepath}")
            return filepath
        else:
            print("[ERROR] picam-still failed with return code", result.returncode)
            return None

    except subprocess.TimeoutExpired:
        print("[ERROR] picam-still timed out")
        return None

    except Exception as e:
        print(f"[ERROR] Unexpected capture error: {e}")
        return None

def upload_photo(filepath, timestamp):
    with open(filepath, "rb") as f:
        files = {'image': f}
        data = {'timestamp': timestamp}
        try:
            r = requests.post(SERVER_URL, files=files, data=data, verify=False) #use for devel and testing
            #r = requests.post(SERVER_URL, files=files, data=data, ssl_context=("cert.pem", "key.pem")) # use for production
            print(f"[UPLOAD] Status {r.status_code}: {r.text}")
        except Exception as e:
            print("[ERROR] Upload failed:", e)

def main():
    try:
        while True:
            timestamp = get_rtc_time()
            photo_path = capture_photo_picam()
            if photo_path:
                upload_photo(photo_path, timestamp)
            time.sleep(PHOTO_INTERVAL)
    finally:
        GPIO.cleanup()

if __name__ == "__main__":
    main()
