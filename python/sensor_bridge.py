import requests
import time
import json
import uuid

# ==========================================================
# SMART COMPOST SYSTEM - PYTHON SENSOR TELEMETRY BRIDGE
# ==========================================================

# Supabase REST Configuration
SUPABASE_URL = "https://rlhfqpufrqibnmyhmtii.supabase.co/rest/v1/day_readings"
SUPABASE_KEY = "sb_publishable_tQ2Q1GV0jRX5dlqi_wWSBg_qP3l8wJR"

# Target Compost Pile UUID (Copy from Supabase compost_piles table or App)
# Requirement: UUID must be configurable in a single central variable.
PILE_UUID = "c7b2a9e0-1234-4567-89ab-cdef01234567"

def is_valid_uuid(val_str):
    """Validate that the configured PILE_UUID is a valid 36-character UUID."""
    try:
        uuid_obj = uuid.UUID(val_str, version=4)
        return str(uuid_obj) == val_str
    except ValueError:
        return False

def send_telemetry_reading(temp_c, moisture_pct, ph_val, day_num=1):
    """
    Inserts a sensor reading into day_readings referencing the existing pile UUID.
    Never creates a new compost_pile record.
    """
    if not is_valid_uuid(PILE_UUID):
        print(f"[ERROR] Invalid PILE_UUID configured: '{PILE_UUID}'. Must be a valid UUID.")
        return False

    headers = {
        "Content-Type": "application/json",
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Prefer": "return=minimal"
    }

    payload = {
        "pile_id": PILE_UUID,
        "day_number": day_num,
        "temp": temp_c,
        "moisture": moisture_pct,
        "ph": ph_val
    }

    try:
        response = requests.post(SUPABASE_URL, headers=headers, json=payload, timeout=10)
        if response.status_code in [200, 201, 204]:
            print(f"[SUCCESS] Telemetry posted for Pile UUID '{PILE_UUID}': Temp={temp_c}°C, Moisture={moisture_pct}%, pH={ph_val}")
            return True
        else:
            print(f"[ERROR] Supabase returned status code {response.status_code}: {response.text}")
            return False
    except Exception as e:
        print(f"[EXCEPTION] Failed to communicate with Supabase: {e}")
        return False

if __name__ == "__main__":
    print(f"--- Starting Smart Compost Python Sensor Bridge ---")
    print(f"Configured Target Pile UUID: {PILE_UUID}")

    # Simulated Sensor Loop
    import random
    while True:
        simulated_temp = round(random.uniform(50.0, 65.0), 1)
        simulated_moisture = round(random.uniform(48.0, 62.0), 1)
        simulated_ph = round(random.uniform(6.5, 7.5), 1)

        send_telemetry_reading(simulated_temp, simulated_moisture, simulated_ph)
        time.sleep(15) # Send reading every 15 seconds
