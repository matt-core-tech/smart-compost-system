import time
import json
import uuid
import hashlib
import requests
try:
    import serial
except ImportError:
    serial = None

# ==========================================================
# SMART COMPOST SYSTEM - ESP32 SERIAL TELEMETRY BRIDGE
# Reads real hardware sensor data over Serial from ESP32,
# validates metrics, debounces duplicate payloads,
# and posts telemetry to Supabase day_readings table.
# ==========================================================

# 1. Supabase REST API Configuration
SUPABASE_URL = "https://rlhfqpufrqibnmyhmtii.supabase.co/rest/v1"
SUPABASE_KEY = "sb_publishable_tQ2Q1GV0jRX5dlqi_wWSBg_qP3l8wJR"

# 2. Central Configurable Target Compost Pile UUID
# REQUIREMENT: Must match an existing UUID in compost_piles table.
# Replace with your actual compost pile UUID from Supabase dashboard or mobile app.
PILE_UUID = "c7b2a9e0-1234-4567-89ab-cdef01234567"

# 3. Serial Communication Configuration
SERIAL_PORT = "COM10"          # Configured Serial Port (COM10 on Windows)
BAUD_RATE = 115200             # Baud rate matching ESP32 firmware
UPLOAD_INTERVAL_SECONDS = 60   # Continuous upload interval in seconds

# ==========================================================
# PROVISIONAL MOISTURE SENSOR CALIBRATION
# Note: Raw capacitive soil moisture sensors output raw ADC values (e.g., 0 - 4095).
# Calibration Bounds:
#   DRY_SENSOR_ADC = 3200 (Air / Dry soil)
#   WET_SENSOR_ADC = 1400 (Submerged / Saturated soil)
# IMPORTANT: Adjust these bounds based on physical calibration with your sensor.
# ==========================================================
DRY_SENSOR_ADC = 3200.0
WET_SENSOR_ADC = 1400.0


def is_valid_uuid(val_str):
    """Validates that the configured PILE_UUID is a valid 36-character UUID."""
    try:
        uuid_obj = uuid.UUID(val_str, version=4)
        return str(uuid_obj) == val_str
    except ValueError:
        return False


def verify_pile_exists_in_supabase(pile_uuid):
    """
    Verifies that the target pile_uuid exists in the compost_piles table.
    Refuses to create a new pile if missing. Returns True if verified, False otherwise.
    """
    if not is_valid_uuid(pile_uuid):
        print(f"[ERROR] '{pile_uuid}' is not a valid 36-character UUID format.")
        return False

    url = f"{SUPABASE_URL}/compost_piles?id=eq.{pile_uuid}&select=id,name"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}"
    }

    try:
        res = requests.get(url, headers=headers, timeout=10)
        if res.status_code == 200:
            data = res.json()
            if isinstance(data, list) and len(data) > 0:
                pile_name = data[0].get("name", "Unnamed Pile")
                print(f"[VERIFIED] Target Compost Pile '{pile_name}' (UUID: {pile_uuid}) confirmed in Supabase database.")
                return True
            else:
                print(f"[CRITICAL ERROR] Target Pile UUID '{pile_uuid}' does NOT exist in compost_piles table!")
                print(f"[ACTION REQUIRED] Please select or register an existing compost pile first.")
                return False
        else:
            print(f"[ERROR] Supabase pile verification failed with status {res.status_code}: {res.text}")
            return False
    except Exception as e:
        print(f"[EXCEPTION] Could not connect to Supabase during pile verification: {e}")
        return False


def convert_raw_soil_to_moisture_percentage(raw_soil_adc):
    """
    Converts raw ADC soil moisture reading to a percentage (0.0% - 100.0%).
    Provisional linear interpolation based on DRY_SENSOR_ADC and WET_SENSOR_ADC.
    """
    try:
        adc_val = float(raw_soil_adc)
        if adc_val < 0 or adc_val > 4095:
            return None # Out of bounds ADC reading

        # Map ADC value linearly to percentage
        pct = ((DRY_SENSOR_ADC - adc_val) / (DRY_SENSOR_ADC - WET_SENSOR_ADC)) * 100.0
        return round(max(0.0, min(100.0, pct)), 1)
    except (ValueError, TypeError):
        return None


def sanitize_and_clean_telemetry(raw_data):
    """
    Validates ESP32 JSON payload:
    - Moisture: Converts raw_soil or moisture value; rejects invalid values.
    - Temperature: Rejects -127.0 (DS18B20 disconnect value) or out-of-bounds.
    - pH: Included ONLY if valid pH value transmitted.
    Omits unavailable fields so Supabase records NULL instead of 0 or fake data.
    """
    payload = {
        "pile_id": PILE_UUID,
        "day_number": raw_data.get("day_number", 1)
    }

    # 1. Moisture Validation & Conversion
    moisture_pct = None
    if "moisture" in raw_data and raw_data["moisture"] is not None:
        try:
            m_val = float(raw_data["moisture"])
            if 0.0 <= m_val <= 100.0:
                moisture_pct = round(m_val, 1)
        except (ValueError, TypeError):
            pass

    if moisture_pct is None and "raw_soil" in raw_data and raw_data["raw_soil"] is not None:
        moisture_pct = convert_raw_soil_to_moisture_percentage(raw_data["raw_soil"])

    if moisture_pct is not None:
        payload["moisture"] = moisture_pct
    else:
        print("[SENSOR ALERT] Moisture reading unavailable or invalid. Omitting field (Database NULL).")

    # 2. Temperature Validation (-127.0 means DS18B20 sensor disconnected)
    if "temp" in raw_data and raw_data["temp"] is not None:
        try:
            temp_val = float(raw_data["temp"])
            if temp_val == -127.0 or temp_val < -20.0 or temp_val > 100.0:
                print(f"[SENSOR ALERT] DS18B20 Temperature sensor disconnected/invalid ({temp_val}°C). Omitting field (Database NULL).")
            else:
                payload["temp"] = round(temp_val, 1)
        except (ValueError, TypeError):
            print("[SENSOR ALERT] Malformed temperature value. Omitting field.")
    else:
        print("[SENSOR ALERT] Temperature reading omitted in ESP32 message.")

    # 3. pH Validation (Include ONLY when valid pH value is explicitly transmitted)
    if "ph" in raw_data and raw_data["ph"] is not None:
        try:
            ph_val = float(raw_data["ph"])
            if 0.0 <= ph_val <= 14.0:
                payload["ph"] = round(ph_val, 2)
            else:
                print(f"[SENSOR ALERT] pH reading out of physical bounds ({ph_val}). Omitting field.")
        except (ValueError, TypeError):
            pass

    return payload


def compute_payload_hash(payload_dict):
    """
    Computes an MD5 hash of the payload values (excluding timestamp)
    to enable duplicate detection and prevent uploading redundant data.
    """
    filtered = {k: v for k, v in payload_dict.items() if k != "day_number"}
    serialized = json.dumps(filtered, sort_keys=True)
    return hashlib.md5(serialized.encode('utf-8')).hexdigest()


def upload_telemetry_to_supabase(payload):
    """
    Inserts validated telemetry record into day_readings table ONLY.
    Never creates or modifies records in compost_piles.
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
            print(f"[REAL ESP32 SERIAL TELEMETRY] Uploaded successfully to day_readings!")
            print(f"                               Payload: {json.dumps(payload)}")
            return True
        else:
            print(f"[DATABASE ERROR] Supabase HTTP {res.status_code}: {res.text}")
            return False
    except Exception as e:
        print(f"[NETWORK EXCEPTION] Could not post to Supabase: {e}")
        return False


def start_serial_bridge():
    """
    Main continuous execution function called by bridge.py / sensor_bridge.py.
    """
    if serial is None:
        print("[ERROR] 'pyserial' library is not installed. Please run: pip install pyserial")
        return

    print("==========================================================")
    print(" SMART COMPOST SYSTEM - REAL ESP32 TELEMETRY SERIAL BRIDGE")
    print("==========================================================")
    print(f" Target Serial Port    : {SERIAL_PORT}")
    print(f" Baud Rate             : {BAUD_RATE}")
    print(f" Configured Pile UUID  : {PILE_UUID}")
    print(f" Upload Interval       : {UPLOAD_INTERVAL_SECONDS} seconds")
    print("==========================================================")

    # Step 1: Pre-verify that target pile UUID exists in Supabase compost_piles table
    if not verify_pile_exists_in_supabase(PILE_UUID):
        print("\n[CRITICAL ABORT] Bridge execution stopped: PILE_UUID is not verified in Supabase.")
        return

    # Step 2: Open Serial Port Connection to ESP32
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=2)
        print(f"\n[CONNECTED] Serial port '{SERIAL_PORT}' opened successfully at {BAUD_RATE} baud.")
    except serial.SerialException as e:
        print(f"\n[SERIAL CONNECTION ERROR] Could not open port '{SERIAL_PORT}': {e}")
        print("[TROUBLESHOOTING] Check USB connection, confirm port in Device Manager, and verify baud rate.")
        return

    last_upload_time = 0
    last_uploaded_hash = None
    latest_received_data = None

    try:
        while True:
            # Continuously check for incoming ESP32 Serial lines
            try:
                if ser.in_waiting > 0:
                    raw_line = ser.readline().decode('utf-8', errors='ignore').strip()
                    if raw_line.startswith('{') and raw_line.endswith('}'):
                        print(f"[RAW SERIAL RECEIVED] {raw_line}")
                        parsed = json.loads(raw_line)
                        latest_received_data = parsed
            except json.JSONDecodeError:
                print(f"[SERIAL WARN] Malformed JSON received over serial line: '{raw_line}'")
            except serial.SerialException as e:
                print(f"[SERIAL DISCONNECT WARNING] Serial connection error: {e}")
                time.sleep(2)

            # Check if the 60-second upload interval has elapsed
            current_time = time.time()
            if current_time - last_upload_time >= UPLOAD_INTERVAL_SECONDS:
                if latest_received_data is not None:
                    payload = sanitize_and_clean_telemetry(latest_received_data)
                    payload_hash = compute_payload_hash(payload)

                    # DUPLICATE DETECTION: Compare hash with previous upload
                    if payload_hash == last_uploaded_hash:
                        print(f"\n[DUPLICATE DETECTED] Telemetry values unchanged from previous upload. Skipping duplicate payload.")
                    else:
                        print(f"\n--- Uploading Real ESP32 Sensor Telemetry ---")
                        success = upload_telemetry_to_supabase(payload)
                        if success:
                            last_uploaded_hash = payload_hash

                    latest_received_data = None # Reset after processing
                    last_upload_time = current_time
                else:
                    print(f"[MONITORING] {UPLOAD_INTERVAL_SECONDS}s interval elapsed. Waiting for next hardware reading from ESP32...")
                    last_upload_time = current_time

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n[STOPPING] Serial bridge stopped by user.")
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("[CLOSED] Serial port connection closed cleanly.")


if __name__ == "__main__":
    start_serial_bridge()
