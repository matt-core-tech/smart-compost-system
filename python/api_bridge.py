import os
import json
import time
import requests
from datetime import datetime, timezone
from flask import Flask, request, jsonify

# ==========================================================
# SMART COMPOST SYSTEM - PYTHON HTTP API TELEMETRY BRIDGE
# ESP32 Sensors -> Wi-Fi -> Python HTTP API -> Supabase -> Flutter App
# ==========================================================

app = Flask(__name__)

# Supabase REST Configuration
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://rlhfqpufrqibnmyhmtii.supabase.co/rest/v1")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "sb_publishable_tQ2Q1GV0jRX5dlqi_wWSBg_qP3l8wJR")

# Optional Security API Authentication Token
API_AUTH_TOKEN = os.environ.get("API_AUTH_TOKEN", "smart-compost-secret-token-123")

# Configurable Upload Rate Limiting (seconds)
MIN_READING_INTERVAL_SECONDS = 30
last_upload_timestamps = {}  # Map of pile_number -> timestamp

def get_supabase_headers():
    return {
        "Content-Type": "application/json",
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Prefer": "return=minimal"
    }

@app.route("/api/readings", methods=["POST"])
def receive_sensor_readings():
    """
    Endpoint for ESP32 hardware to post telemetry over local Wi-Fi.
    Payload expected:
    {
        "pile_number": 1,
        "temperature_c": 24.75,
        "raw_moisture": 556
    }
    """
    # 1. Validate Optional Security Token Header if provided
    auth_header = request.headers.get("X-API-Key")
    if auth_header and auth_header != API_AUTH_TOKEN:
        print("[SECURITY ALERT] Invalid API token received.")
        return jsonify({"status": "error", "message": "Unauthorized API token"}), 401

    # 2. Validate JSON Content
    data = request.get_json(silent=True)
    if not data or not isinstance(data, dict):
        print("[API WARN] Received invalid or non-JSON body.")
        return jsonify({"status": "error", "message": "Invalid JSON body"}), 400

    # 3. Extract and Validate pile_number
    if "pile_number" not in data or data["pile_number"] is None:
        print("[API ERROR] Missing 'pile_number' in payload.")
        return jsonify({"status": "error", "message": "Missing 'pile_number' field"}), 400

    try:
        pile_number = int(data["pile_number"])
        if pile_number <= 0:
            return jsonify({"status": "error", "message": "pile_number must be greater than zero"}), 400
    except (ValueError, TypeError):
        return jsonify({"status": "error", "message": "pile_number must be a valid integer"}), 400

    # 4. Rate Limiting Check
    current_time = time.time()
    last_time = last_upload_timestamps.get(pile_number, 0)
    if current_time - last_time < MIN_READING_INTERVAL_SECONDS:
        print(f"[RATE LIMIT] Skipping reading for Pile #{pile_number}: Received within {MIN_READING_INTERVAL_SECONDS}s window.")
        return jsonify({"status": "ignored", "message": "Rate limit: Upload interval not elapsed"}), 200

    # 5. Query Supabase for existing pile by pile_number to retrieve its internal UUID
    query_url = f"{SUPABASE_URL}/compost_piles?pile_number=eq.{pile_number}&select=id,name,start_date,is_archived"
    try:
        res = requests.get(query_url, headers=get_supabase_headers(), timeout=10)
        if res.status_code != 200:
            print(f"[DATABASE ERROR] Query failed with status {res.status_code}: {res.text}")
            return jsonify({"status": "error", "message": "Failed to query compost pile database"}), 500

        piles = res.json()
        if not isinstance(piles, list) or len(piles) == 0:
            print(f"[REJECTED] Pile #{pile_number} NOT found in database. Refusing to create automatic pile.")
            return jsonify({"status": "error", "message": f"Compost Pile #{pile_number} does not exist in database"}), 404

        target_pile = piles[0]
        pile_uuid = target_pile["id"]
        pile_name = target_pile.get("name", f"Pile #{pile_number}")
        is_archived = target_pile.get("is_archived", False)

        # Reject readings for completed / archived piles
        if is_archived:
            print(f"[REJECTED] Pile #{pile_number} ('{pile_name}') is marked as Completed/Archived. Sensor readings ignored.")
            return jsonify({"status": "error", "message": f"Pile #{pile_number} is completed/archived. Readings not accepted."}), 400

    except Exception as e:
        print(f"[NETWORK ERROR] Exception querying Supabase: {e}")
        return jsonify({"status": "error", "message": f"Network exception: {str(e)}"}), 500

    # 6. Validate Sensor Readings (Do NOT inject fake pH or fake 0.0 values)
    temp_val = None
    if "temperature_c" in data and data["temperature_c"] is not None:
        try:
            t = float(data["temperature_c"])
            # Rejects -127.0 (DS18B20 disconnected sensor code) and out-of-range values
            if t != -127.0 and -20.0 <= t <= 100.0:
                temp_val = round(t, 2)
            else:
                print(f"[SENSOR WARN] DS18B20 disconnected or invalid temperature reading ({t}°C). Storing NULL.")
        except (ValueError, TypeError):
            pass

    moisture_val = None
    if "raw_moisture" in data and data["raw_moisture"] is not None:
        try:
            m = float(data["raw_moisture"])
            if 0 <= m <= 4095:
                moisture_val = round(m, 1)
            else:
                print(f"[SENSOR WARN] Moisture raw ADC out of bounds ({m}). Storing NULL.")
        except (ValueError, TypeError):
            pass

    ph_val = None
    if "ph" in data and data["ph"] is not None:
        try:
            p = float(data["ph"])
            if 0.0 <= p <= 14.0:
                ph_val = round(p, 2)
        except (ValueError, TypeError):
            pass

    # 7. Calculate day_number consistently based on pile's start_date
    day_number = 1
    if target_pile.get("start_date"):
        try:
            start_dt = datetime.fromisoformat(target_pile["start_date"].replace("Z", "+00:00"))
            now_dt = datetime.now(timezone.utc)
            delta_days = (now_dt - start_dt).days
            day_number = max(1, delta_days + 1)
        except Exception:
            day_number = 1

    # 8. Post reading to day_readings referencing pile_uuid
    insert_url = f"{SUPABASE_URL}/day_readings"
    payload = {
        "pile_id": pile_uuid,
        "day_number": day_number,
        "temp": temp_val,
        "moisture": moisture_val,
        "ph": ph_val
    }

    try:
        insert_res = requests.post(insert_url, headers=get_supabase_headers(), json=payload, timeout=10)
        if insert_res.status_code in [200, 201, 204]:
            last_upload_timestamps[pile_number] = current_time
            print(f"[REAL ESP32 WI-FI SENSOR READING SAVED] Pile #{pile_number} ('{pile_name}' / UUID: {pile_uuid}): "
                  f"Temp={temp_val}°C, RawMoisture={moisture_val}, pH={ph_val}, Day={day_number}")
            return jsonify({
                "status": "success",
                "message": f"Reading saved for Pile #{pile_number}",
                "pile_id": pile_uuid,
                "recorded_fields": payload
            }), 201
        else:
            print(f"[INSERT ERROR] Failed to insert day_reading into Supabase: HTTP {insert_res.status_code} - {insert_res.text}")
            return jsonify({"status": "error", "message": "Failed to save reading to database"}), 500
    except Exception as e:
        print(f"[INSERT EXCEPTION] Exception saving day_reading: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/", methods=["GET"])
def health_check():
    return jsonify({
        "service": "Smart Compost System Python Telemetry API",
        "status": "running",
        "version": "2.0.0"
    }), 200

if __name__ == "__main__":
    host = os.environ.get("API_HOST", "0.0.0.0")
    port = int(os.environ.get("API_PORT", 5000))
    print(f"==========================================================")
    print(f" SMART COMPOST PYTHON WI-FI TELEMETRY API SERVER")
    print(f"==========================================================")
    print(f" Listening on          : http://{host}:{port}")
    print(f" Endpoint              : POST http://{host}:{port}/api/readings")
    print(f" Security Token        : {API_AUTH_TOKEN}")
    print(f"==========================================================")
    app.run(host=host, port=port, debug=False)
