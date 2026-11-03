"""
Smart Compost System - Sensor Telemetry Bridge Proxy
Points directly to python/supabase_bridge.py for real ESP32 serial communication.
"""

from supabase_bridge import start_serial_bridge

if __name__ == "__main__":
    start_serial_bridge()
