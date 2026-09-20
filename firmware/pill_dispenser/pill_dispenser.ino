/*
 * Automated Pill Dispenser — Arduino Nano 33 BLE
 * Firmware for the v3 mechanism: one positional MG90S, direct drive, no gate.
 *
 * How the v3 machine dispenses (see cad/v3/PLAN.md sections 2 and 13):
 *   The deck holds the pills in and has one 24 deg wedge opening. The unit rests
 *   with the JUST-EMPTIED compartment centred on that opening, so nothing sits
 *   above the opening between doses. A 45 deg step sweeps the next compartment
 *   across the opening and gravity empties it down the chute into the tray.
 *
 * Everything here follows from one number: parking has only +/- 6.2 deg of margin
 * before the opening's edge slips past a divider and starts draining the NEXT
 * compartment, which would be a silent double dose. Three things spend that
 * margin and the sketch has to manage all three.
 *
 *   1. Where the horn happened to land. The output spline indexes in 17.1 deg
 *      teeth (14.4 on a 25-tooth servo), the hub's hex in 60 deg and the horn
 *      screws in 90 deg, so assembly alone can leave the carousel up to 8.6 deg
 *      off centre. Nothing mechanical adjusts finer than that, so the sketch has
 *      to: TRIM and JOG shift the whole stop table at run time, and the authority
 *      reserved for them is TRIM_RANGE_DEG.
 *
 *   2. The coupling's play. The hex is loose on purpose — it must pass torque
 *      without side-loading the carousel — which costs +/- 2.58 deg of rotational
 *      play. A move ends with the driving flats in contact, so the carousel trails
 *      the shaft by that much in whichever direction it last moved. The sketch
 *      commands the shaft that far PAST the stop so the carousel lands ON it.
 *
 *   3. The servo's own positioning error, about a degree, which is what is left.
 *
 * Because 1 and 2 have to be reserved at BOTH ends of the travel, doses per fill
 * is derived from the servo's measured travel rather than assumed:
 *
 *      DOSES_PER_FILL = (TRAVEL_DEG - 2 * HEADROOM_DEG) / STEP_DEG
 *
 * A nominal 180 deg servo gives three. Measure 203 deg or more — many MG90S reach
 * about 200 between 500 and 2500 us — and the fourth comes back on its own. The
 * commissioning procedure is in firmware/README.md, and the sketch reports what it
 * derived in its CAL banner and in STATUS, so a log always records which it was.
 *
 * Angles go out as pulse widths, not degrees. write() quantises to 1 deg (about
 * 10 us) and pins the range to whatever the core's 544-2400 us mapping happens to
 * be; this margin cannot afford either.
 *
 * Moves are ramped, not stepped. A bare write() makes the servo slam the full
 * 45 deg at maximum speed, which is the peak-current case on a small cell, the
 * peak-torque case on a printed PLA coupling, and the case most likely to overrun
 * a stop on inertia. SLEW_DEG_PER_S sets the rate and the move's own duration
 * follows from it, so the timing and the motion cannot disagree.
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
 *                                     "ERR_MAGAZINE_EMPTY"  last stop reached
 *   Host -> "REZERO\n"      Device -> "ACK_REZERO" | "ERR_BUSY"
 *   Host -> "SETSTOP n\n"   Device -> "ACK_SETSTOP" | "ERR_ARG" | "ERR_BUSY"
 *   Host -> "TRIM d\n"      Device -> "ACK_TRIM <deg>" | "ERR_ARG" | "ERR_BUSY"
 *   Host -> "JOG d\n"       Device -> "ACK_TRIM <deg>" | "ERR_ARG" | "ERR_BUSY"
 *   Host -> "PULSE us\n"    Device -> "ACK_PULSE <us>" | "ERR_ARG" | "ERR_BUSY"
 *   Host -> "STATUS\n"      Device -> "STATE=s STOP=i/n ANGLE=d US=u TRIM=t DOSES=n"
 *   Host -> "PING\n"        Device -> "PONG"
 *
 * PULSE is for commissioning: it ramps to a raw pulse anywhere in 500-2500 us so
 * the servo's own ends and travel can be measured with nothing but this sketch, and
 * it then marks the magazine spent so a stray DISPENSE cannot follow a hand-jogged
 * position. REZERO or SETSTOP re-establishes where the carousel is.
 *
 * TRIM sets the offset and JOG nudges it. Both re-seat the carousel on the stop it
 * is already on, so you can watch the wedge while you calibrate, and both answer
 * only once it has settled there. The value lives in RAM: the host is expected to
 * log it and send it back on connect.
 *
 * Pin map (PWM-capable on Nano 33 BLE):
 *   D9  -> carousel MG90S signal
 *   GND -> servo GND (common with Nano GND)
 *   5V  -> servo VCC. An MG90S is rated 4.8-6 V, so feed it 5 V with a bulk
 *          capacitor across it rather than the bare 3.7 V cell, and never from the
 *          Nano's 3.3 V rail.
 *
 * D10 drove the v1 latch servo. v3 has no latch — the park convention replaces
 * it — so the pin is free.
 */

#include <Servo.h>

#include "v3_geometry.h"

// ----- Pins -----
const uint8_t PIN_CAROUSEL = 9;

// ----- Geometry, generated from cad/v3/parameters_v3.scad -----
constexpr uint8_t CAROUSEL_BINS = V3_CAROUSEL_BINS;
constexpr float STEP_DEG = V3_STEP_DEG;                    // one compartment
constexpr float PARK_MARGIN_DEG = V3_PARK_MARGIN_DEG;      // how far off park may be
constexpr float COUPLING_PLAY_DEG = V3_COUPLING_PLAY_DEG;  // the loose hex's play

static_assert(STEP_DEG * CAROUSEL_BINS == 360.0f,
              "step and bin count disagree: regenerate v3_geometry.h");
static_assert(COUPLING_PLAY_DEG < PARK_MARGIN_DEG,
              "the coupling's play alone exceeds the park margin");

/*
 * ----- Servo calibration: MEASURED per unit, see firmware/README.md -----
 *
 * US_MIN_SAFE / US_MAX_SAFE are pulse widths just inside where this servo stops
 * moving, backed off far enough that it never buzzes against its own end stops.
 * TRAVEL_DEG is how far the output actually turns between them. The defaults are
 * a deliberately modest servo; commissioning replaces them with measurements.
 */
constexpr int US_MIN_SAFE = 600;
constexpr int US_MAX_SAFE = 2400;
constexpr float TRAVEL_DEG = 180.0f;
constexpr float US_PER_DEG = (US_MAX_SAFE - US_MIN_SAFE) / TRAVEL_DEG;

// Authority left for TRIM/JOG: the horn's teeth are 17.1 deg, so half a tooth is
// the worst assembly offset a trim has to absorb.
constexpr float TRIM_RANGE_DEG = 9.0f;

// Reserved at BOTH ends of the travel: a trim can push the table either way, and
// the play take-up adds to whichever end the move came from.
constexpr float HEADROOM_DEG = TRIM_RANGE_DEG + COUPLING_PLAY_DEG;

constexpr uint8_t DOSES_PER_FILL =
    static_cast<uint8_t>((TRAVEL_DEG - 2.0f * HEADROOM_DEG) / STEP_DEG);

static_assert(DOSES_PER_FILL >= 1,
              "calibrated travel cannot fit one step plus its trim headroom");
static_assert(DOSES_PER_FILL <= CAROUSEL_BINS,
              "more stops than compartments: a sweep would revisit a bin");
static_assert(2.0f * HEADROOM_DEG + DOSES_PER_FILL * STEP_DEG <= TRAVEL_DEG,
              "stop table plus headroom runs past the calibrated travel");
static_assert(US_MIN_SAFE < US_MAX_SAFE, "servo pulse limits are inverted");

// PULSE is allowed outside the calibrated ends, because finding them is the whole
// point of it. This is the envelope no hobby servo should be driven past.
constexpr int US_HARD_MIN = 500;
constexpr int US_HARD_MAX = 2500;
static_assert(US_HARD_MIN <= US_MIN_SAFE && US_MAX_SAFE <= US_HARD_MAX,
              "calibrated ends must sit inside the commissioning envelope");

// ----- Motion profile -----
/*
 * 45 deg in 250 ms, which is well inside an MG90S's own 0.1 s / 60 deg and gentle
 * on both the coupling and the cell. SETTLE_MS then holds the target before the
 * tablet is allowed to start moving, so the gear train is never released while the
 * output is still creeping.
 *
 * DOSE_FALL_MS covers the tablet's trip from the chute geometry: about 44 mm of
 * fall onto the ramp, 65 mm of slide and the bounce in the tray, before the servo
 * is released and the host's vision check reads the tray.
 */
constexpr float SLEW_DEG_PER_S = 180.0f;
const unsigned long SETTLE_MS = 120;
const unsigned long DOSE_FALL_MS = 600;

enum class State : uint8_t {
  IDLE,
  MOVE,
  SETTLE,
  DOSE_FALL,
  COMPLETE
};

enum class Request : uint8_t {
  NONE,
  DISPENSE,
  REZERO,
  RESEAT,     // TRIM / JOG: same stop, new offset
  PULSE       // commissioning: a raw pulse, no stop involved
};

Servo servoCarousel;

State state = State::IDLE;
Request request = Request::NONE;
unsigned long stateStartedMs = 0;

uint8_t stopIndex = 0;          // 0 .. DOSES_PER_FILL
float parkTrimDeg = 0.0f;       // set by TRIM / JOG, RAM only
int8_t lastDir = 1;             // +1 after a forward move, -1 after a reverse one

// What the shaft was last told, as a pulse. Seeded to match the boot belief
// (stop 0, approached forwards) so the first ramp starts somewhere sensible
// without commanding anything. Microseconds rather than degrees because PULSE has
// to be able to ramp outside the calibrated ends.
int commandedUs = 0;
int lastUs = -1;
int pulseTargetUs = 0;

int moveFromUs = 0;
int moveToUs = 0;
unsigned long moveMs = 0;

String serialBuffer;

// ----- Angles -----

// Nominal shaft angle for a stop, before trim or play.
float stopDeg(uint8_t index) {
  return HEADROOM_DEG + static_cast<float>(index) * STEP_DEG;
}

// Where to put the SHAFT so the CAROUSEL ends up on the stop: it trails by the
// coupling's play in whichever direction the move is going.
float commandDeg(uint8_t index, int8_t dir) {
  return stopDeg(index) + parkTrimDeg + static_cast<float>(dir) * COUPLING_PLAY_DEG;
}

// Stop targets are clamped to the calibrated ends: a stop that needs more travel
// than the servo has is a calibration error, not something to drive into.
int usForDeg(float deg) {
  const float us = US_MIN_SAFE + deg * US_PER_DEG;
  if (us <= US_MIN_SAFE) return US_MIN_SAFE;
  if (us >= US_MAX_SAFE) return US_MAX_SAFE;
  return static_cast<int>(us + 0.5f);
}

float degForUs(int us) {
  return (us - US_MIN_SAFE) / US_PER_DEG;
}

int stopUs(uint8_t index, int8_t dir) {
  return usForDeg(commandDeg(index, dir));
}

// Only writes when the pulse actually changes, so ramping every loop costs
// nothing and the record of what was commanded stays readable.
void writeUs(int us) {
  commandedUs = us;
  if (us != lastUs) {
    lastUs = us;
    servoCarousel.writeMicroseconds(us);
  }
}

void detachServo() {
  // Fail-safe: release PWM to cut holding current / heat / battery drain. The
  // carousel is held by the servo's own gearing, not by the signal.
  servoCarousel.detach();
  lastUs = -1;
}

void enterState(State next) {
  state = next;
  stateStartedMs = millis();
}

bool stateElapsed(unsigned long durationMs) {
  return (millis() - stateStartedMs) >= durationMs;
}

void startRamp(int targetUs) {
  moveFromUs = commandedUs;
  moveToUs = targetUs;

  const int deltaUs = (moveToUs > moveFromUs) ? moveToUs - moveFromUs
                                              : moveFromUs - moveToUs;
  // The rate sets the duration, so a multi-step rezero takes that many steps'
  // worth without anyone multiplying anything.
  moveMs = static_cast<unsigned long>(deltaUs / US_PER_DEG / SLEW_DEG_PER_S * 1000.0f) + 20;

  servoCarousel.attach(PIN_CAROUSEL);
  writeUs(moveFromUs);
  enterState(State::MOVE);
}

void startMoveTo(uint8_t index, int8_t dir) {
  stopIndex = index;
  lastDir = dir;
  startRamp(stopUs(index, dir));
}

// Commissioning only: drive a pulse directly, then treat the magazine as spent so
// a stray DISPENSE cannot follow a hand-jogged position. REZERO or SETSTOP first.
void startPulse(int targetUs) {
  lastDir = (targetUs >= commandedUs) ? +1 : -1;
  stopIndex = DOSES_PER_FILL;
  startRamp(targetUs);
}

void finishCycle(const __FlashStringHelper *reply) {
  detachServo();
  enterState(State::IDLE);
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
  Serial.print(degForUs(commandedUs), 2);
  Serial.print(F(" US="));
  Serial.print(commandedUs);
  Serial.print(F(" TRIM="));
  Serial.print(parkTrimDeg, 2);
  Serial.print(F(" DOSES="));
  Serial.println(static_cast<int>(DOSES_PER_FILL));
}

void reportCalibration() {
  Serial.print(F("CAL US="));
  Serial.print(US_MIN_SAFE);
  Serial.print(F(".."));
  Serial.print(US_MAX_SAFE);
  Serial.print(F(" TRAVEL="));
  Serial.print(TRAVEL_DEG, 1);
  Serial.print(F(" PLAY="));
  Serial.print(COUPLING_PLAY_DEG, 2);
  Serial.print(F(" TRIM="));
  Serial.print(parkTrimDeg, 2);
  Serial.print(F(" DOSES="));
  Serial.println(static_cast<int>(DOSES_PER_FILL));
}

// ----- Commands -----

String argumentOf(const String &verb) {
  const int space = verb.indexOf(' ');
  return (space > 0) ? verb.substring(space + 1) : String();
}

// toFloat()/toInt() read any non-number as 0, which would silently accept
// "TRIM x" as 0, so insist on something numeric first.
bool parseNumber(const String &arg, float &out) {
  if (arg.length() == 0) return false;
  const char c = arg[0];
  if (!isDigit(c) && c != '-' && c != '+' && c != '.') return false;
  out = arg.toFloat();
  return true;
}

void ackTrim() {
  Serial.print(F("ACK_TRIM "));
  Serial.println(parkTrimDeg, 2);
}

// Shared by TRIM (absolute) and JOG (relative): bound it, keep it, and re-seat the
// carousel on the stop it is already on so the change can be watched.
void applyTrim(float requested) {
  if (requested < -TRIM_RANGE_DEG || requested > TRIM_RANGE_DEG) {
    Serial.println(F("ERR_ARG"));
    return;
  }
  parkTrimDeg = requested;
  request = Request::RESEAT;
}

void handleCommand(const String &line) {
  String verb = line;
  verb.toUpperCase();

  if (verb == "DISPENSE") {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
    } else if (stopIndex >= DOSES_PER_FILL) {
      // Refuse rather than step into the end of the travel and report a dose that
      // never fell. Refill, then REZERO.
      Serial.println(F("ERR_MAGAZINE_EMPTY"));
    } else {
      request = Request::DISPENSE;
    }
    return;
  }

  if (verb == "REZERO") {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
    } else {
      request = Request::REZERO;
    }
    return;
  }

  if (verb.startsWith("SETSTOP")) {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
      return;
    }
    float requested = 0.0f;
    if (!parseNumber(argumentOf(verb), requested) || requested < 0 ||
        requested > static_cast<float>(DOSES_PER_FILL)) {
      Serial.println(F("ERR_ARG"));
    } else {
      // Belief only: the carousel does not move, which is the whole point. The
      // commanded angle moves with it so the next ramp starts from the new belief.
      stopIndex = static_cast<uint8_t>(requested);
      commandedUs = stopUs(stopIndex, lastDir);
      Serial.println(F("ACK_SETSTOP"));
    }
    return;
  }

  if (verb.startsWith("TRIM")) {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
      return;
    }
    float requested = 0.0f;
    if (!parseNumber(argumentOf(verb), requested)) {
      Serial.println(F("ERR_ARG"));
    } else {
      applyTrim(requested);
    }
    return;
  }

  if (verb.startsWith("JOG")) {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
      return;
    }
    float delta = 0.0f;
    if (!parseNumber(argumentOf(verb), delta)) {
      Serial.println(F("ERR_ARG"));
    } else {
      applyTrim(parkTrimDeg + delta);
    }
    return;
  }

  if (verb.startsWith("PULSE")) {
    if (state != State::IDLE) {
      Serial.println(F("ERR_BUSY"));
      return;
    }
    float requested = 0.0f;
    if (!parseNumber(argumentOf(verb), requested) || requested < US_HARD_MIN ||
        requested > US_HARD_MAX) {
      Serial.println(F("ERR_ARG"));
    } else {
      pulseTargetUs = static_cast<int>(requested + 0.5f);
      request = Request::PULSE;
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

  if (verb == "CAL") {
    reportCalibration();
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
      switch (request) {
        case Request::DISPENSE:
          startMoveTo(stopIndex + 1, +1);
          break;
        case Request::REZERO:
          // Sweeps back across every compartment emptied this fill. Safe only
          // because they are empty — which is why it is a separate command and
          // not something the sketch does on its own.
          startMoveTo(0, -1);
          break;
        case Request::RESEAT:
          startMoveTo(stopIndex, lastDir);
          break;
        case Request::PULSE:
          startPulse(pulseTargetUs);
          break;
        default:
          break;
      }
      break;

    case State::MOVE: {
      const unsigned long elapsed = millis() - stateStartedMs;
      if (elapsed >= moveMs) {
        writeUs(moveToUs);
        enterState(State::SETTLE);
      } else {
        const float f = static_cast<float>(elapsed) / static_cast<float>(moveMs);
        const float us = moveFromUs + (moveToUs - moveFromUs) * f;
        writeUs(static_cast<int>(us + 0.5f));
      }
      break;
    }

    case State::SETTLE:
      if (stateElapsed(SETTLE_MS)) {
        // Nothing falls during a rezero or a re-seat — a rezero only crosses
        // compartments already emptied, and a re-seat barely moves — so only a
        // dose waits for the tablet.
        enterState(request == Request::DISPENSE ? State::DOSE_FALL
                                                : State::COMPLETE);
      }
      break;

    case State::DOSE_FALL:
      if (stateElapsed(DOSE_FALL_MS)) {
        enterState(State::COMPLETE);
      }
      break;

    case State::COMPLETE: {
      const Request done = request;
      request = Request::NONE;
      switch (done) {
        case Request::REZERO:
          finishCycle(F("ACK_REZERO"));
          break;
        case Request::RESEAT:
          detachServo();
          enterState(State::IDLE);
          ackTrim();
          break;
        case Request::PULSE:
          detachServo();
          enterState(State::IDLE);
          Serial.print(F("ACK_PULSE "));
          Serial.println(commandedUs);
          break;
        default:
          finishCycle(F("ACK_DISPENSE"));
          break;
      }
      break;
    }

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
  commandedUs = stopUs(0, lastDir);
  detachServo();
  enterState(State::IDLE);
  Serial.println(F("READY_PILL_DISPENSER"));
  reportCalibration();
}

void loop() {
  pollSerial();
  serviceStateMachine();
  // No delay() — loop stays responsive for serial / future BLE.
}
