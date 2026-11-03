"""
Smart Compost System - Main Serial Bridge Launcher
Imports and executes start_serial_bridge() from python/supabase_bridge.py
"""

import sys
import os

# Add python/ directory to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), 'python'))

from supabase_bridge import start_serial_bridge

if __name__ == "__main__":
    start_serial_bridge()
