/*
 * Automated Pill Dispenser — Arduino Nano 33 BLE
 * Week 1 firmware: non-blocking carousel + latch servo state machine.
 *
 * Serial protocol @ 115200:
 *   Host  -> "DISPENSE\n"
 *   Device -> "ACK_DISPENSE\n" on success
 *             "ERR_BUSY\n" / "ERR_STATE\n" on failure
 *
 * Pin map (PWM-capable on Nano 33 BLE):
 *   D9  -> carousel MG90S signal
 *   D10 -> latch MG90S signal
 *   GND -> servo GND (common with Nano GND)
 *   5V  -> servo VCC (external 5V preferred under load; USB OK for bench)
 */

#include <Servo.h>

// ----- Pins -----
const uint8_t PIN_CAROUSEL = 9;
const uint8_t PIN_LATCH = 10;

// ----- Servo angles (tune after hardware arrives) -----
const int CAROUSEL_REST_DEG = 0;
const int CAROUSEL_INDEX_DEG = 45;   // one pocket step
const int LATCH_CLOSED_DEG = 0;
const int LATCH_OPEN_DEG = 70;

// ----- Non-blocking timings (ms) -----
const unsigned long CAROUSEL_MOVE_MS = 450;
const unsigned long LATCH_OPEN_MS = 350;
const unsigned long LATCH_HOLD_MS = 200;
const unsigned long SETTLE_MS = 150;

enum class State : uint8_t {
  IDLE,
  CAROUSEL_MOVE,
  LATCH_OPEN,
  LATCH_HOLD,
  LATCH_CLOSE,
  SETTLE,
  COMPLETE
};

Servo servoCarousel;
Servo servoLatch;

State state = State::IDLE;
unsigned long stateStartedMs = 0;
bool dispenseRequested = false;

String serialBuffer;

void attachServos() {
  servoCarousel.attach(PIN_CAROUSEL);
  servoLatch.attach(PIN_LATCH);
}

void detachServos() {
  // Fail-safe: release PWM to cut holding current / heat / battery drain.
  servoCarousel.detach();
  servoLatch.detach();
}

void enterState(State next) {
  state = next;
  stateStartedMs = millis();
}

bool stateElapsed(unsigned long durationMs) {
  return (millis() - stateStartedMs) >= durationMs;
}

void startDispenseCycle() {
  attachServos();
  servoCarousel.write(CAROUSEL_REST_DEG);
  servoLatch.write(LATCH_CLOSED_DEG);
  enterState(State::CAROUSEL_MOVE);
  servoCarousel.write(CAROUSEL_INDEX_DEG);
}

void completeDispenseCycle(bool success) {
  servoCarousel.write(CAROUSEL_REST_DEG);
  servoLatch.write(LATCH_CLOSED_DEG);
  detachServos();
  enterState(State::IDLE);
  dispenseRequested = false;
  if (success) {
    Serial.println(F("ACK_DISPENSE"));
  } else {
    Serial.println(F("ERR_STATE"));
  }
}

void pollSerial() {
  while (Serial.available() > 0) {
    const char c = static_cast<char>(Serial.read());
    if (c == '\n' || c == '\r') {
      serialBuffer.trim();
      if (serialBuffer.length() == 0) {
        continue;
      }
      if (serialBuffer.equalsIgnoreCase("DISPENSE")) {
        if (state != State::IDLE) {
          Serial.println(F("ERR_BUSY"));
        } else {
          dispenseRequested = true;
        }
      } else if (serialBuffer.equalsIgnoreCase("PING")) {
        Serial.println(F("PONG"));
      } else if (serialBuffer.equalsIgnoreCase("STATUS")) {
        Serial.print(F("STATE="));
        Serial.println(static_cast<int>(state));
      } else {
        Serial.println(F("ERR_UNKNOWN_CMD"));
      }
      serialBuffer = "";
    } else {
      if (serialBuffer.length() < 64) {
        serialBuffer += c;
      }
    }
  }
}

void serviceStateMachine() {
  if (state == State::IDLE) {
    if (dispenseRequested) {
      startDispenseCycle();
    }
    return;
  }

  switch (state) {
    case State::CAROUSEL_MOVE:
      if (stateElapsed(CAROUSEL_MOVE_MS)) {
        servoLatch.write(LATCH_OPEN_DEG);
        enterState(State::LATCH_OPEN);
      }
      break;

    case State::LATCH_OPEN:
      if (stateElapsed(LATCH_OPEN_MS)) {
        enterState(State::LATCH_HOLD);
      }
      break;

    case State::LATCH_HOLD:
      if (stateElapsed(LATCH_HOLD_MS)) {
        servoLatch.write(LATCH_CLOSED_DEG);
        enterState(State::LATCH_CLOSE);
      }
      break;

    case State::LATCH_CLOSE:
      if (stateElapsed(LATCH_OPEN_MS)) {
        servoCarousel.write(CAROUSEL_REST_DEG);
        enterState(State::SETTLE);
      }
      break;

    case State::SETTLE:
      if (stateElapsed(SETTLE_MS)) {
        enterState(State::COMPLETE);
      }
      break;

    case State::COMPLETE:
      completeDispenseCycle(true);
      break;

    case State::IDLE:
    default:
      break;
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 3000) {
    // Non-blocking wait for USB serial host; continue after timeout for BLE-only use later.
  }
  detachServos();
  enterState(State::IDLE);
  Serial.println(F("READY_PILL_DISPENSER"));
}

void loop() {
  pollSerial();
  serviceStateMachine();
  // No delay() — loop stays responsive for serial / future BLE.
}
