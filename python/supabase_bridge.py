import time
import json
import uuid
import requests
try:
    import serial
except ImportError:
    serial = None

# ==========================================================
# SMART COMPOST SYSTEM - ESP32 SERIAL TELEMETRY BRIDGE
# Reads real hardware sensor data over Serial from ESP32
# and posts telemetry to Supabase day_readings table.
# ==========================================================

# 1. Supabase REST Configuration
SUPABASE_URL = "https://rlhfqpufrqibnmyhmtii.supabase.co/rest/v1"
SUPABASE_KEY = "sb_publishable_tQ2Q1GV0jRX5dlqi_wWSBg_qP3l8wJR"

# 2. Target Compost Pile UUID (Must exist in Supabase compost_piles table)
# Requirement: UUID must be configurable in a single central variable.
PILE_UUID = "c7b2a9e0-1234-4567-89ab-cdef01234567"

# 3. Serial Communication Configuration
SERIAL_PORT = "COM3"          # Update to match your ESP32 COM port (e.g. 'COM3' on Windows or '/dev/ttyUSB0' on Linux)
BAUD_RATE = 115200
UPLOAD_INTERVAL_SECONDS = 60  # Minimum interval between uploads to avoid database flooding

def is_valid_uuid(val_str):
    """Validate that the configured PILE_UUID is a valid 36-character UUID."""
    try:
        uuid_obj = uuid.UUID(val_str, version=4)
        return str(uuid_obj) == val_str
    except ValueError:
        return False

def verify_pile_exists_in_supabase(pile_uuid):
    """
    Checks Supabase compost_piles table to verify that the configured pile_uuid exists.
    Returns True if found, False otherwise.
    Never creates a replacement pile.
    """
    if not is_valid_uuid(pile_uuid):
        print(f"[ERROR] '{pile_uuid}' is not a valid 36-character UUID format.")
        return False

    url = f"{SUPABASE_URL}/compost_piles?id=eq.{pile_uuid}&select=id"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}"
    }

    try:
        res = requests.get(url, headers=headers, timeout=10)
        if res.status_code == 200:
            data = res.json()
            if isinstance(data, list) and len(data) > 0:
                print(f"[VERIFIED] Target Compost Pile UUID '{pile_uuid}' confirmed in Supabase database.")
                return True
            else:
                print(f"[REJECTED] Pile UUID '{pile_uuid}' NOT found in compost_piles table.")
                print(f"[ACTION REQUIRED] Please create or register the pile in the App or Supabase dashboard first.")
                return False
        else:
            print(f"[ERROR] Supabase verification query failed with HTTP status {res.status_code}: {res.text}")
            return False
    except Exception as e:
        print(f"[EXCEPTION] Failed to connect to Supabase during pile verification: {e}")
        return False

def sanitize_and_clean_telemetry(raw_data):
    """
    Validates sensor values received from ESP32:
    - Temperature -127.0 or out-of-bounds is treated as DISCONNECTED (omitted/NULL).
    - Moisture out-of-bounds (0-100%) is omitted/NULL.
    - pH out-of-bounds (0-14) is omitted/NULL.
    Omits unavailable fields so Supabase records NULL instead of fabricated zeros or fake data.
    """
    payload = {
        "pile_id": PILE_UUID,
        "day_number": raw_data.get("day_number", 1)
    }

    # 1. Temperature Validation
    if "temp" in raw_data and raw_data["temp"] is not None:
        try:
            temp_val = float(raw_data["temp"])
            if temp_val == -127.0 or temp_val < -20.0 or temp_val > 100.0:
                print(f"[SENSOR ALERT] Temperature sensor disconnected or invalid value ({temp_val}°C). Omitting field (Database NULL).")
            else:
                payload["temp"] = temp_val
        except (ValueError, TypeError):
            pass

    # 2. Moisture Validation
    if "moisture" in raw_data and raw_data["moisture"] is not None:
        try:
            moisture_val = float(raw_data["moisture"])
            if moisture_val < 0.0 or moisture_val > 100.0:
                print(f"[SENSOR ALERT] Moisture reading out of bounds ({moisture_val}%). Omitting field (Database NULL).")
            else:
                payload["moisture"] = moisture_val
        except (ValueError, TypeError):
            pass

    # 3. pH Validation
    if "ph" in raw_data and raw_data["ph"] is not None:
        try:
            ph_val = float(raw_data["ph"])
            if ph_val < 0.0 or ph_val > 14.0:
                print(f"[SENSOR ALERT] pH reading out of bounds ({ph_val}). Omitting field (Database NULL).")
            else:
                payload["ph"] = ph_val
        except (ValueError, TypeError):
            pass

    return payload

def upload_telemetry_to_supabase(payload):
    """
    Inserts telemetry payload directly into public.day_readings table.
    Never creates a new record in compost_piles.
    """
    url = f"{SUPABASE_URL}/day_readings"
    headers = {
        "Content-Type": "application/json",
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Prefer": "return=minimal"
    }

    try:
        res = requests.post(url, headers=headers, json=payload, timeout=10)
        if res.status_code in [200, 201, 204]:
            print(f"[REAL ESP32 SERIAL SENSOR READINGS] Successfully uploaded to day_readings!")
            print(f"                                   Payload: {json.dumps(payload)}")
            return True
        else:
            print(f"[UPLOAD ERROR] Supabase HTTP {res.status_code}: {res.text}")
            return False
    except Exception as e:
        print(f"[UPLOAD EXCEPTION] Network error posting to Supabase: {e}")
        return False

def start_serial_bridge():
    """
    Main loop reading real ESP32 JSON data over Serial and forwarding to Supabase.
    """
    if serial is None:
        print("[ERROR] 'pyserial' library is not installed. Please run: pip install pyserial")
        return

    print("==========================================================")
    print(" SMART COMPOST SYSTEM - REAL ESP32 SERIAL SENSOR BRIDGE")
    print("==========================================================")
    print(f" Target Serial Port    : {SERIAL_PORT}")
    print(f" Baud Rate             : {BAUD_RATE}")
    print(f" Configured Pile UUID  : {PILE_UUID}")
    print(f" Upload Interval       : {UPLOAD_INTERVAL_SECONDS} seconds")
    print("==========================================================")

    # Step 1: Verify target compost pile exists in database
    if not verify_pile_exists_in_supabase(PILE_UUID):
        print("\n[CRITICAL] Refusing to start serial bridge: Target pile UUID does not exist in Supabase.")
        return

    # Step 2: Open Serial Port Connection
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2)
        print(f"\n[CONNECTED] Serial port {SERIAL_PORT} opened successfully at {BAUD_RATE} baud.")
    except serial.SerialException as e:
        print(f"\n[SERIAL ERROR] Could not open serial port '{SERIAL_PORT}': {e}")
        print("[TIP] Ensure ESP32 is plugged in via USB and update SERIAL_PORT in script.")
        return

    last_upload_time = 0
    latest_received_data = None

    try:
        while True:
            if ser.in_waiting > 0:
                try:
                    raw_line = ser.readline().decode('utf-8', errors='ignore').strip()
                    if raw_line.startswith('{') and raw_line.endswith('}'):
                        print(f"[SERIAL RECEIVED] {raw_line}")
                        parsed = json.loads(raw_line)
                        latest_received_data = parsed
                except json.JSONDecodeError:
                    print(f"[SERIAL WARN] Malformed JSON line received: '{raw_line}'")
                except Exception as e:
                    print(f"[SERIAL EXCEPTION] Error reading line: {e}")

            # Check if upload interval has elapsed and real data is available
            current_time = time.time()
            if current_time - last_upload_time >= UPLOAD_INTERVAL_SECONDS:
                if latest_received_data is not None:
                    print(f"\n--- Uploading Real ESP32 Sensor Readings ---")
                    payload = sanitize_and_clean_telemetry(latest_received_data)
                    upload_telemetry_to_supabase(payload)
                    latest_received_data = None # Reset after upload
                    last_upload_time = current_time
                else:
                    print(f"[WAITING] Interval elapsed, awaiting next hardware reading from ESP32...")
                    last_upload_time = current_time

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n[STOPPING] Serial bridge stopped by user.")
    finally:
        ser.close()
        print("[CLOSED] Serial port connection closed.")

if __name__ == "__main__":
    start_serial_bridge()
