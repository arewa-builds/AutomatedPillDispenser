/*
 * Automated Pill Dispenser — Arduino Nano 33 BLE
 * Firmware for the v3 mechanism: one positional MG90S, direct drive, no gate.
 *
 * How the v3 machine dispenses (see cad/v3/PLAN.md section 2):
 *   The deck holds the pills in and has one 24 deg wedge opening. The unit rests
 *   with the JUST-EMPTIED compartment centred on that opening, so nothing sits
 *   above the opening between doses. A 45 deg step sweeps the next compartment
 *   across the opening and gravity empties it down the chute into the tray.
 *
 * Two consequences drive this firmware:
 *
 *   1. Absolute positions, not timed steps. Parking has only +/- 6.2 deg of
 *      margin before the opening's edge slips past a divider and starts draining
 *      the NEXT compartment, which would be a silent double dose. A positional
 *      servo commanded to an absolute angle parks to about 1 deg. A
 *      continuous-rotation servo stepped on timing drifts past 6 deg within a
 *      few doses, so it is not supported here.
 *
 *   2. Four doses per fill. A 180 deg servo geared 1:1 to the carousel reaches
 *      five stops — 0, 45, 90, 135, 180 — which is four 45 deg steps. After the
 *      fourth dose the magazine is spent and DISPENSE is refused rather than
 *      quietly doing nothing. REZERO sweeps back to stop 0, which is safe only
 *      because the compartments it crosses are the four it just emptied.
 *
 * The servo holds its angle mechanically when unpowered, so the carousel's
 * position survives a power cycle but this sketch's idea of it does not. On boot
 * it assumes stop 0 and does not move, which is correct if you refill the way
 * cad/v3/README.md describes (return to stop 0, then refill). If the host knows
 * better — it logged every dose — it can correct the belief with SETSTOP without
 * moving anything.
 *
 * Serial protocol @ 115200. A superset of the previous one, so existing hosts
 * that only speak DISPENSE / ACK_DISPENSE keep working:
 *   Host -> "DISPENSE\n"    Device -> "ACK_DISPENSE"
 *                                     "ERR_BUSY"            mid-cycle
 *                                     "ERR_MAGAZINE_EMPTY"  stop 4 reached
 *   Host -> "REZERO\n"      Device -> "ACK_REZERO" | "ERR_BUSY"
 *   Host -> "SETSTOP n\n"   Device -> "ACK_SETSTOP" | "ERR_ARG" | "ERR_BUSY"
 *   Host -> "STATUS\n"      Device -> "STATE=n STOP=i/4 ANGLE=d"
 *   Host -> "PING\n"        Device -> "PONG"
 *
 * Pin map (PWM-capable on Nano 33 BLE):
 *   D9  -> carousel MG90S signal
 *   GND -> servo GND (common with Nano GND)
 *   5V  -> servo VCC (external 5V preferred under load; USB OK for bench)
 *
 * D10 drove the v1 latch servo. v3 has no latch — the park convention replaces
 * it — so the pin is free.
 */

#include <Servo.h>

// ----- Pins -----
const uint8_t PIN_CAROUSEL = 9;

// ----- Geometry, from cad/v3/parameters_v3.scad -----
const uint8_t CAROUSEL_BINS = 8;      // car_n
const int STEP_DEG = 45;              // car_pitch, one compartment
const int SERVO_SPAN_DEG = 180;       // usable positional range of an MG90S
const uint8_t DOSES_PER_FILL = SERVO_SPAN_DEG / STEP_DEG;   // 4

/*
 * Horn mounting offset. The horn's spline is fine enough that stop 0 lands
 * wherever the horn happened to be pressed on, so this trims all five stops
 * together until the emptied compartment is centred on the opening. Keep it well
 * inside the +/- 6.2 deg parking margin, and remember it eats into the range at
 * the far end: a +5 deg trim puts stop 4 at 185, past a 180 deg servo's stop.
 * Calibrate it once, on the first fill, by eye through the opening.
 */
const int PARK_TRIM_DEG = 0;

// The trim shifts every stop, so it can push the last one past the servo's range.
// Catch that at compile time instead of discovering a short final step.
static_assert(PARK_TRIM_DEG >= 0 &&
              DOSES_PER_FILL * STEP_DEG + PARK_TRIM_DEG <= SERVO_SPAN_DEG,
              "PARK_TRIM_DEG pushes a stop outside the servo's range");
static_assert(DOSES_PER_FILL <= CAROUSEL_BINS,
              "more stops than compartments: a sweep would revisit a bin");

// ----- Non-blocking timings (ms) -----
/*
 * MOVE_MS_PER_STEP covers one 45 deg step: an MG90S slews 60 deg in about 0.1 s
 * unloaded, so this is generous even with the carousel's inertia. A cycle scales
 * it by the number of steps, which matters for REZERO — that sweeps four steps
 * back to stop 0, and releasing the servo part way through would leave the
 * carousel stopped between compartments.
 *
 * DOSE_FALL_MS then covers the tablet's trip — about 44 mm of fall onto the ramp,
 * 65 mm of slide, and the bounce in the tray — before the servo is released and
 * the host's vision check reads the tray. Together they put a dose at roughly one
 * second.
 */
const unsigned long MOVE_MS_PER_STEP = 400;
const unsigned long DOSE_FALL_MS = 600;

enum class State : uint8_t {
  IDLE,
  MOVE,
  DOSE_FALL,
  COMPLETE
};

Servo servoCarousel;

State state = State::IDLE;
unsigned long stateStartedMs = 0;
unsigned long moveMs = MOVE_MS_PER_STEP;   // allowance for the move under way
uint8_t stopIndex = 0;                     // 0 .. DOSES_PER_FILL
bool dispenseRequested = false;
bool rezeroRequested = false;

String serialBuffer;

int stopAngle(uint8_t index) {
  const int angle = static_cast<int>(index) * STEP_DEG + PARK_TRIM_DEG;
  return constrain(angle, 0, SERVO_SPAN_DEG);
}

void detachServo() {
  // Fail-safe: release PWM to cut holding current / heat / battery drain. The
  // carousel is held by the servo's own gearing, not by the signal.
  servoCarousel.detach();
}

void enterState(State next) {
  state = next;
  stateStartedMs = millis();
}

bool stateElapsed(unsigned long durationMs) {
  return (millis() - stateStartedMs) >= durationMs;
}

void startMoveTo(uint8_t index) {
  const uint8_t steps = (index > stopIndex) ? index - stopIndex : stopIndex - index;
  moveMs = MOVE_MS_PER_STEP * (steps == 0 ? 1 : steps);
  stopIndex = index;
  servoCarousel.attach(PIN_CAROUSEL);
  servoCarousel.write(stopAngle(stopIndex));
  enterState(State::MOVE);
}

void finishCycle(const __FlashStringHelper *reply) {
  detachServo();
  enterState(State::IDLE);
  dispenseRequested = false;
  rezeroRequested = false;
  Serial.println(reply);
}

void reportStatus() {
  Serial.print(F("STATE="));
  Serial.print(static_cast<int>(state));
  Serial.print(F(" STOP="));
  Serial.print(static_cast<int>(stopIndex));
  Serial.print('/');
  Serial.print(static_cast<int>(DOSES_PER_FILL));
  Serial.print(F(" ANGLE="));
  Serial.println(stopAngle(stopIndex));
}

void handleCommand(const String &line) {
  String verb = line;
  verb.toUpperCase();

  if (verb == "DISPENSE") {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
    } else if (stopIndex >= DOSES_PER_FILL) {
      // Refuse rather than step into the servo's end stop and report a dose that
      // never fell. Refill, then REZERO.
      Serial.println(F("ERR_MAGAZINE_EMPTY"));
    } else {
      dispenseRequested = true;
    }
    return;
  }

  if (verb == "REZERO") {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
    } else {
      rezeroRequested = true;
    }
    return;
  }

  if (verb.startsWith("SETSTOP")) {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
      return;
    }
    const int space = verb.indexOf(' ');
    const String arg = (space > 0) ? verb.substring(space + 1) : String();
    // toInt() reads any non-number as 0, which would silently accept "SETSTOP x"
    // as stop 0, so check for a digit first.
    const int requested = (arg.length() > 0 && isDigit(arg[0])) ? arg.toInt() : -1;
    if (requested < 0 || requested > DOSES_PER_FILL) {
      Serial.println(F("ERR_ARG"));
    } else {
      // Belief only: the carousel does not move, which is the whole point.
      stopIndex = static_cast<uint8_t>(requested);
      Serial.println(F("ACK_SETSTOP"));
    }
    return;
  }

  if (verb == "PING") {
    Serial.println(F("PONG"));
    return;
  }

  if (verb == "STATUS") {
    reportStatus();
    return;
  }

  Serial.println(F("ERR_UNKNOWN_CMD"));
}

void pollSerial() {
  while (Serial.available() > 0) {
    const char c = static_cast<char>(Serial.read());
    if (c == '\n' || c == '\r') {
      serialBuffer.trim();
      if (serialBuffer.length() > 0) {
        handleCommand(serialBuffer);
      }
      serialBuffer = "";
    } else if (serialBuffer.length() < 64) {
      serialBuffer += c;
    }
  }
}

void serviceStateMachine() {
  switch (state) {
    case State::IDLE:
      if (dispenseRequested) {
        startMoveTo(stopIndex + 1);
      } else if (rezeroRequested) {
        // Sweeps back across every compartment emptied this fill. Safe only
        // because they are empty — which is why it is a separate command and not
        // something the sketch does on its own.
        startMoveTo(0);
      }
      break;

    case State::MOVE:
      if (stateElapsed(moveMs)) {
        // Nothing falls during a rezero — the compartments it crosses are the
        // ones already emptied — so there is nothing to wait for.
        enterState(rezeroRequested ? State::COMPLETE : State::DOSE_FALL);
      }
      break;

    case State::DOSE_FALL:
      if (stateElapsed(DOSE_FALL_MS)) {
        enterState(State::COMPLETE);
      }
      break;

    case State::COMPLETE:
      finishCycle(rezeroRequested ? F("ACK_REZERO") : F("ACK_DISPENSE"));
      break;

    default:
      break;
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 3000) {
    // Non-blocking wait for USB serial host; continue after timeout for BLE-only use later.
  }
  // Deliberately no move here: the servo already holds the carousel wherever it
  // was left, and writing an angle now could sweep full compartments across the
  // opening and dump them.
  detachServo();
  enterState(State::IDLE);
  Serial.println(F("READY_PILL_DISPENSER"));
}

void loop() {
  pollSerial();
  serviceStateMachine();
  // No delay() — loop stays responsive for serial / future BLE.
}
