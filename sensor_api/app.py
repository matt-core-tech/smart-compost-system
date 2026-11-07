
import os
import math
import hmac
import requests

from flask import Flask, request, jsonify
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# Load configuration from .env
SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
COMPOST_PILE_ID = os.getenv("COMPOST_PILE_ID", "")
DEVICE_TOKEN = os.getenv("DEVICE_TOKEN", "")

# Validate configuration before starting
required_settings = {
    "SUPABASE_URL": SUPABASE_URL,
    "SUPABASE_SERVICE_ROLE_KEY": SUPABASE_SERVICE_ROLE_KEY,
    "COMPOST_PILE_ID": COMPOST_PILE_ID,
    "DEVICE_TOKEN": DEVICE_TOKEN,
}

missing = [name for name, value in required_settings.items() if not value]

if missing:
    raise RuntimeError(
        "Missing configuration in .env: " + ", ".join(missing)
    )


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "online",
        "service": "Smart Compost Sensor API"
    }), 200


@app.route("/api/readings", methods=["POST"])
def receive_reading():

    # Authenticate the ESP32
    received_token = request.headers.get("X-Device-Token", "")

    if not hmac.compare_digest(received_token, DEVICE_TOKEN):
        return jsonify({
            "success": False,
            "error": "Unauthorized device"
        }), 401

    # Read JSON payload
    data = request.get_json(silent=True)

    if not isinstance(data, dict):
        return jsonify({
            "success": False,
            "error": "A valid JSON object is required"
        }), 400

    temperature = data.get("temperature_c")
    moisture = data.get("raw_moisture")

    # Validate numeric values
    if (
        isinstance(temperature, bool)
        or not isinstance(temperature, (int, float))
        or not math.isfinite(temperature)
    ):
        return jsonify({
            "success": False,
            "error": "Invalid temperature reading"
        }), 400

    if (
        isinstance(moisture, bool)
        or not isinstance(moisture, (int, float))
        or not math.isfinite(moisture)
    ):
        return jsonify({
            "success": False,
            "error": "Invalid moisture reading"
        }), 400

    # Validate sensor ranges
    if temperature < -55 or temperature > 125:
        return jsonify({
            "success": False,
            "error": "Temperature is outside the DS18B20 range"
        }), 400

    if moisture < 0 or moisture > 4095 or not moisture.is_integer():
        return jsonify({
            "success": False,
            "error": "Moisture must be a whole ADC value between 0 and 4095"
        }), 400

    
    # Prepare Supabase RPC request
    endpoint = (
        f"{SUPABASE_URL}/rest/v1/rpc/record_sensor_reading"
    )

    headers = {
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Content-Type": "application/json"
    }

    payload = {
        "p_pile_id": COMPOST_PILE_ID,
        "p_temperature_c": temperature,
        "p_raw_moisture": int(moisture)
    }


    try:
        response = requests.post(
            endpoint,
            headers=headers,
            json=payload,
            timeout=15
        )

        if not response.ok:
            app.logger.error(
                "Supabase returned HTTP %s: %s",
                response.status_code,
                response.text[:500]
            )

            return jsonify({
                "success": False,
                "error": "Could not save reading to the database"
            }), 502

        reading_id = response.json()

        app.logger.info(
            "Reading saved. ID=%s Temperature=%s Moisture=%s",
            reading_id,
            temperature,
            moisture
        )

        return jsonify({
            "success": True,
            "message": "Reading saved successfully",
            "reading_id": reading_id
        }), 200

    except requests.exceptions.RequestException:
        app.logger.exception("Could not communicate with Supabase")

        return jsonify({
            "success": False,
            "error": "Database connection failed"
        }), 502


if __name__ == "__main__":
    print("Smart Compost Sensor API starting...")
    print("Listening on port 5000")

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False
    )
