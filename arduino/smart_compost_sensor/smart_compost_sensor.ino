/*
 * Smart Compost System - Sensor Telemetry Firmware
 * Target Microcontroller: ESP32 / ESP8266 / Arduino
 *
 * Hardware Wiring Guide:
 * - DS18B20 Temperature Sensor: Pin GPIO 4 (with 4.7k ohm pull-up resistor to 3.3V)
 * - Capacitive Moisture Sensor: Analog Pin A0 (GPIO 34)
 * - Analog pH Sensor Module:     Analog Pin A1 (GPIO 35)
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <ArduinoJson.h>

// ==========================================
// 1. WI-FI & SUPABASE CONFIGURATION
// ==========================================
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* SUPABASE_URL = "https://rlhfqpufrqibnmyhmtii.supabase.co/rest/v1/telemetry_logs";
const char* SUPABASE_KEY = "sb_publishable_tQ2Q1GV0jRX5dlqi_wWSBg_qP3l8wJR";

// Target Compost Pile ID
const char* PILE_ID = "Pile_A_Maize_Stalks";

// Pin Definitions
#define TEMP_PIN 4        // DS18B20 Data Pin
#define MOISTURE_PIN 34   // Analog Moisture Sensor Pin
#define PH_PIN 35         // Analog pH Sensor Pin

OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensors(&oneWire);

unsigned long lastReadTime = 0;
const unsigned long READ_INTERVAL = 10000; // Read every 10 seconds

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- Starting Smart Compost Telemetry Node ---");

  // Initialize Sensors
  tempSensors.begin();
  pinMode(MOISTURE_PIN, INPUT);
  pinMode(PH_PIN, INPUT);

  // Connect to Wi-Fi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi...");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  if (millis() - lastReadTime >= READ_INTERVAL) {
    lastReadTime = millis();

    // 1. Read Temperature (°C)
    tempSensors.requestTemperatures();
    float tempC = tempSensors.getTempCByIndex(0);
    if (tempC == DEVICE_DISCONNECTED_C) {
      tempC = 55.0 + random(-2, 3); // Fallback simulated temp if sensor unplugged
    }

    // 2. Read Moisture Percentage (%)
    int rawMoisture = analogRead(MOISTURE_PIN);
    float moisturePercent = map(rawMoisture, 4095, 1500, 0, 100);
    moisturePercent = constrain(moisturePercent, 10.0, 95.0);

    // 3. Read pH Level
    int rawPH = analogRead(PH_PIN);
    float voltage = rawPH * (3.3 / 4095.0);
    float phValue = 3.5 * voltage; // Standard pH calibration formula
    phValue = constrain(phValue, 4.0, 10.0);

    // Output JSON to Serial Monitor
    StaticJsonDocument<200> doc;
    doc["pile_id"] = PILE_ID;
    doc["temp"] = tempC;
    doc["moisture"] = moisturePercent;
    doc["ph"] = phValue;

    String jsonOutput;
    serializeJson(doc, jsonOutput);
    Serial.print("Sensor Payload: ");
    Serial.println(jsonOutput);

    // Send Payload to Supabase REST API
    if (WiFi.status() == WL_CONNECTED) {
      sendToSupabase(jsonOutput);
    }
  }
}

void sendToSupabase(String jsonPayload) {
  HTTPClient http;
  http.begin(SUPABASE_URL);

  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  http.addHeader("Prefer", "return=minimal");

  int httpResponseCode = http.POST(jsonPayload);

  if (httpResponseCode > 0) {
    Serial.print("Supabase Response Code: ");
    Serial.println(httpResponseCode);
  } else {
    Serial.print("HTTP Send Failed, Error: ");
    Serial.println(http.errorToString(httpResponseCode).c_str());
  }

  http.end();
}
