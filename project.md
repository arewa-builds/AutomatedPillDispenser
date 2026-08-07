The purpose of this project is to build
Automated Pill Dispensing & Visual Medication Compliance Monitor
An intelligent, 3D-printed pill station that physically dispenses medication, visually verifies pill type and patient identity via CV, and tracks compliance patterns to prevent dangerous missed doses.

The Problem: Non-adherence to medication costs the healthcare system billions and severely impacts elderly or neurodivergent patients.

Hardware Rig ($100–$160):

3D-printed continuous-rotation or servo-driven carousel dispenser connected to an Arduino.

USB Webcam pointed at the dispensing tray.

Computer Vision (Python Edge):

Uses MediaPipe Face Mesh / facial detection to verify the correct patient is at the dispenser.

Employs an OpenCV contour and color classification pipeline to visually confirm that the correct pill size, color, and count were dropped onto the tray before opening the latch.

Databricks Integration:

Data Lake Pipeline: Logs every successful dispense, facial match confidence score, and time-to-ingestion latency into Delta Lake.

Predictive ML: Uses MLflow to model "Adherence Risk." The model detects subtle shifts in dispense timing (e.g., patient taking meds later and later each day) to alert caregivers before a complete missed dose occurs.

Storytelling Focus: Patient Safety, MedTech Automation, and Non-Invasive Caregiving.