#!/usr/bin/env python3

import gps
import time
import subprocess
from datetime import datetime

def wait_for_gps_fix(timeout=120):
    session = gps.gps(mode=gps.WATCH_ENABLE)
    print("Looking for GPS fix...")
    start_time = time.time()

    while time.time() - start_time < timeout:
        try:
            report = session.next()

            if report['class'] == 'TPV':
                if hasattr(report, 'time') and hasattr(report, 'mode') and report.mode >= 2:
                    gps_time = report.time
                    print("GPS fix acquired.")
                    return gps_time

        except KeyError:
            pass
        except StopIteration:
            session = gps.gps(mode=gps.WATCH_ENABLE)
        except Exception as e:
            print("GPS error:", e)

        time.sleep(1)

    print("Timeout: No GPS fix acquired within {} seconds.".format(timeout))
    return None

def set_system_and_rtc_time(gps_time_str):
    try:
        dt = datetime.strptime(gps_time_str, "%Y-%m-%dT%H:%M:%S.%fZ")
        subprocess.run(["sudo", "date", "-s", dt.strftime("%Y-%m-%d %H:%M:%S")], check=True)
        print(f"System time set to: {dt}")
        subprocess.run(["sudo", "hwclock", "-w"], check=True)
        print("RTC time updated from GPS.")
    except Exception as e:
        print("Failed to set time:", e)

def main():
    gps_time = wait_for_gps_fix()
    if gps_time:
        set_system_and_rtc_time(gps_time)
    else:
        print("Skipping RTC update due to lack of GPS time.")

if __name__ == "__main__":
    main()
