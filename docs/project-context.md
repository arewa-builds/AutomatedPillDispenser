# Project Context — Schedule, Resources & Budget

**Project:** Automated Pill Dispensing & Visual Medication Compliance Monitor  
**Timeline:** August 10 – September 20, 2026 (6 weeks)  
**Budget target:** Well under $300 USD; expected **$93–$108** (or ~$73–$88 with laptop camera)

## 1. Resource & Cost List

### Hardware & Physical Components

| Item | Specification / Purpose | Estimated Cost (USD) |
| :--- | :--- | ---: |
| Microcontroller | Arduino Nano 33 BLE (BLE & sensor onboard) | $26.00 |
| Actuators | MG90S Metal-Gear Micro Servos (2-pack for carousel & latch) | $12.00 |
| Camera | Built-in laptop camera (preferred) **or** 1080p USB Webcam / ESP32-CAM | $0.00 – $20.00 |
| Power Supply | 3.7V 500mAh LiPo Battery + USB-C TP4056 Charger Board | $10.00 |
| Enclosure & Frame | 3D Printable Filament (PLA/PETG) / Hardware fasteners | $15.00 |
| Prototyping Essentials | Breadboard, jumper wires, resistors, calibration pills/candies | $10.00 |
| **Subtotal Hardware** | | **$73.00 – $93.00** |

### Software, Cloud & Tools

| Service / Tool | Tier & Usage | Estimated Cost (USD) |
| :--- | :--- | ---: |
| Python Ecosystem | Local Python 3.10+, OpenCV, MediaPipe, PySerial (Open-Source) | $0.00 |
| Arduino IDE | Desktop C++ compiler and library manager | $0.00 |
| Databricks Environment | Community Edition **or** Standard 14-day Free Trial + micro-VM fees | $0.00 – $15.00 |
| Power BI Desktop | Free Desktop application | $0.00 |
| **Subtotal Software/Cloud** | | **$0.00 – $15.00** |

**Estimated Total Budget: $93.00 – $108.00 USD** (laptop-camera path can reduce hardware to ~$73).

## 2. Detailed 6-Week Execution Schedule

### Week 1: Physical Prototype & Microcontroller Firmware
**Focus:** Assembling the physical mechanism and proving local servo control.  
**Days 1–2:** Source hardware; download or modify open-source carousel STL files for 3D printing.  
**Days 3–4:** Flash Arduino Nano 33 BLE. Write C++ firmware for MG90S indexing + release latching.  
**Days 5–7:** Wire LiPo + TP4056. Test dispensing repeatability with candy/dummy pills over Serial.  
**Milestone 1:** Reliable physical dispenser that drops a single pill on command.

### Week 2: Edge Computer Vision Engine (Python)
**Focus:** Local vision verification for patient identity and pill count.  
**Days 8–10:** Set up `opencv-python`, `mediapipe`. Aim camera at dispensing tray.  
**Days 11–12:** MediaPipe Face Detection — require user presence before dispense.  
**Days 13–14:** OpenCV contour/color/size pipeline to count pills on the tray.  
**Milestone 2:** Face detect → release command → visual pill confirm in under 2 seconds.

### Week 3: Edge-Hardware Integration & Telemetry Pipeline
**Focus:** Link vision logic with Arduino; format JSON logs.  
**Days 15–17:** Connect via BLE or Serial (`PySerial`).  
**Days 18–19:** Standardize telemetry JSON (`timestamp`, `patient_id`, `face_match_confidence`, `pills_detected`, `dispense_latency_ms`).  
**Days 20–21:** Retry loops if no pill is visually detected after actuation.  
**Milestone 3:** Integrated edge system generating structured JSON per dispensing cycle.

### Week 4: Databricks Pipeline Development (Bronze & Silver)
**Focus:** Ingest telemetry into Delta Lake via PySpark.  
**Days 22–24:** Launch workspace; Bronze ingest of JSON payloads.  
**Days 25–27:** Silver — clean timestamps, compliance deltas vs schedule, dedupe hardware pings.  
**Milestone 4:** Automated Bronze → Silver transforms.

### Week 5: Machine Learning & Risk Forecasting (Gold & MLflow)
**Focus:** Anomaly / adherence risk prediction.  
**Days 28–30:** Gold aggregations (7-day adherence, average time drift).  
**Days 31–33:** Train sklearn model; track in MLflow (progressive later dosing → risk).  
**Day 34:** Databricks alerts for High Adherence Risk.  
**Milestone 5:** Model forecasting non-adherence from telemetry.

### Week 6: BI Dashboard & Final Integration Testing
**Focus:** Power BI, E2E tests, documentation.  
**Days 35–37:** Power BI → Databricks SQL Warehouse / DirectQuery; clinical KPIs.  
**Days 38–40:** Full E2E (Hardware → Vision → Databricks → ML → Dashboard).  
**Days 41–42:** Architecture diagrams, repo cleanup, build videos.  
**Milestone 6:** Demo-ready cloud-connected MedTech prototype.

## 3. Laptop Camera Notes

OpenCV selects the built-in camera with index `0`:

```python
import cv2

cap = cv2.VideoCapture(0)
```

**Practical tips**
- Place the tray on the desk in front of the keyboard; tilt the laptop screen so the lens sees the tray.
- Sequential workflow: detect face looking at the screen, then verify the pill drop on the tray.
- Skipping a USB webcam saves ~$20 on the BOM.
