/*
 * Smart Compost System - IoT Wi-Fi Sensor Telemetry Firmware
 * Target Microcontroller: ESP32 DevKit V1
 *
 * Hardware Pins:
 * - DS18B20 Temperature Sensor: GPIO 2 (with 4.7k ohm pull-up resistor to 3.3V)
 * - Capacitive Moisture Sensor:  GPIO 34 (Analog Input)
 *
 * Data Flow Architecture:
 * ESP32 Sensors -> Wi-Fi -> Python HTTP API -> Supabase -> Flutter Application
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <ArduinoJson.h>

// ==========================================
// 1. WI-FI & PYTHON API CONFIGURATION
// ==========================================
const char* WIFI_SSID     = "YOUR_WIFI_SSID";       // Replace with your local Wi-Fi name
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";   // Replace with your local Wi-Fi password

// Python HTTP API Server Configuration
const char* API_HOST      = "192.168.1.100";        // Replace with your computer's local IP address
const int   API_PORT      = 5000;                   // Match API_PORT in python/api_bridge.py
const char* API_TOKEN     = "smart-compost-secret-token-123";

// User-facing Numeric Pile ID (Must match an existing active pile in database)
const int TARGET_PILE_NUMBER = 1;

// Hardware Pin Definitions
#define TEMP_PIN 2        // DS18B20 Data Pin (GPIO 2)
#define MOISTURE_PIN 34   // Capacitive Moisture Sensor Analog Pin (GPIO 34)

OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensors(&oneWire);

unsigned long lastSendTime = 0;
const unsigned long SEND_INTERVAL_MS = 15000; // Send telemetry every 15 seconds

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n==========================================================");
  Serial.println(" SMART COMPOST SYSTEM - ESP32 WI-FI TELEMETRY NODE");
  Serial.println("==========================================================");
  Serial.printf(" Target Pile Number : #%d\n", TARGET_PILE_NUMBER);
  Serial.printf(" Temperature Pin    : GPIO %d (DS18B20)\n", TEMP_PIN);
  Serial.printf(" Moisture Pin       : GPIO %d (Capacitive ADC)\n", MOISTURE_PIN);
  Serial.println("==========================================================");

  // Initialize Hardware Sensors
  tempSensors.begin();
  pinMode(MOISTURE_PIN, INPUT);

  // Connect to Wi-Fi
  connectToWiFi();
}

void loop() {
  // Automatic Wi-Fi Reconnection Check
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WI-FI WARN] Connection lost. Attempting reconnection...");
    connectToWiFi();
  }

  // Periodic Telemetry Send Loop
  if (millis() - lastSendTime >= SEND_INTERVAL_MS) {
    lastSendTime = millis();
    readAndPostTelemetry();
  }
}

void connectToWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.printf("Connecting to Wi-Fi SSID '%s'...", WIFI_SSID);
  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 20) {
    delay(500);
    Serial.print(".");
    retries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WI-FI SUCCESS] Connected to network!");
    Serial.print("ESP32 IP Address : ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\n[WI-FI ERROR] Failed to connect to Wi-Fi. Will retry automatically.");
  }
}

void readAndPostTelemetry() {
  // 1. Read DS18B20 Temperature Sensor
  tempSensors.requestTemperatures();
  float tempC = tempSensors.getTempCByIndex(0);

  // 2. Read Capacitive Moisture Sensor (Raw ADC value 0 - 4095)
  int rawMoisture = analogRead(MOISTURE_PIN);

  Serial.println("\n--- Real Hardware Sensor Sampling ---");
  if (tempC == DEVICE_DISCONNECTED_C) {
    Serial.println(" Temperature Sensor : DISCONNECTED (-127.0°C)");
  } else {
    Serial.printf(" Temperature Sensor : %.2f °C\n", tempC);
  }
  Serial.printf(" Moisture Sensor ADC: %d\n", rawMoisture);

  // 3. Build JSON Telemetry Payload
  StaticJsonDocument<200> doc;
  doc["pile_number"] = TARGET_PILE_NUMBER;

  // Include temperature only if valid
  if (tempC != DEVICE_DISCONNECTED_C && tempC >= -20.0 && tempC <= 100.0) {
    doc["temperature_c"] = tempC;
  }

  // Include raw moisture if valid ADC
  if (rawMoisture >= 0 && rawMoisture <= 4095) {
    doc["raw_moisture"] = rawMoisture;
  }

  String jsonPayload;
  serializeJson(doc, jsonPayload);

  // 4. Send HTTP POST to Python API Server over Wi-Fi
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String apiEndpoint = String("http://") + API_HOST + ":" + String(API_PORT) + "/api/readings";

    Serial.printf("Posting payload to %s...\n", apiEndpoint.c_str());
    http.begin(apiEndpoint);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-API-Key", API_TOKEN);

    int httpCode = http.POST(jsonPayload);

    if (httpCode > 0) {
      Serial.printf("[HTTP SUCCESS] Server Response Code: %d\n", httpCode);
      if (httpCode == HTTP_CODE_OK || httpCode == HTTP_CODE_CREATED) {
        String responseBody = http.getString();
        Serial.printf("Server Response     : %s\n", responseBody.c_str());
      }
    } else {
      Serial.printf("[HTTP ERROR] Failed to send POST request. Error: %s\n", http.errorToString(httpCode).c_str());
    }

    http.end();
  } else {
    Serial.println("[HTTP ERROR] Cannot send POST: Wi-Fi not connected.");
  }
}
