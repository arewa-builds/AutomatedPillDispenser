// ============================================================================
// Host harness for firmware/pill_dispenser/pill_dispenser.ino
//
// Compiles the sketch on a PC against small stubs — a fake clock, a fake serial
// port and a recording Servo — and drives it through the sequences that matter.
// It checks behaviour, not just that the sketch compiles: the doses-per-fill the
// calibration implies and then a refusal, one 45 deg step per dose landing on the
// pulse the park budget calls for, the ramp that gets it there, the play take-up
// that flips sign when the sweep reverses, TRIM/JOG authority and its bounds, the
// servo released after every cycle and never driven at boot, and a rezero held for
// its whole multi-step sweep.
//
// Those are the failures that would otherwise be found by watching tablets fall
// into the wrong place, which is expensive to set up and easy to misread.
//
// Run it with ./run.sh. It needs nothing but g++ — no board, no arduino-cli.
//
// This is not a substitute for compiling for the real target. Do both:
//   ./firmware/verify_arduino_toolchain.sh    real toolchain, real core
//   ./firmware/test/run.sh                    behaviour, no board
// ============================================================================

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include <Servo.h>   // resolves to stubs/Servo.h, which records what is commanded

// ---------------------------------------------------------------- Arduino stubs
static unsigned long g_nowMs = 0;
unsigned long millis() { return g_nowMs; }

template <typename T>
T constrain(T v, T lo, T hi) { return v < lo ? lo : (v > hi ? hi : v); }

static bool isDigit(char c) { return c >= '0' && c <= '9'; }

// Only the String surface the sketch actually uses.
class String {
 public:
  std::string s;
  String() {}
  String(const char *p) : s(p) {}

  void trim() {
    const size_t b = s.find_first_not_of(" \t\r\n");
    const size_t e = s.find_last_not_of(" \t\r\n");
    s = (b == std::string::npos) ? "" : s.substr(b, e - b + 1);
  }
  void toUpperCase() {
    for (char &c : s) c = static_cast<char>(toupper(c));
  }
  bool startsWith(const char *p) const { return s.rfind(p, 0) == 0; }
  int indexOf(char c) const {
    const size_t p = s.find(c);
    return p == std::string::npos ? -1 : static_cast<int>(p);
  }
  String substring(int from) const {
    String r;
    r.s = s.substr(static_cast<size_t>(from));
    return r;
  }
  long toInt() const { return strtol(s.c_str(), nullptr, 10); }
  float toFloat() const { return strtof(s.c_str(), nullptr); }
  size_t length() const { return s.size(); }
  char operator[](int i) const { return s[static_cast<size_t>(i)]; }
  bool operator==(const char *p) const { return s == p; }
  String &operator+=(char c) {
    s += c;
    return *this;
  }
  String &operator=(const char *p) {
    s = p;
    return *this;
  }
};

// F() strings are just pointers here.
struct __FlashStringHelper {};
#define F(x) (reinterpret_cast<const __FlashStringHelper *>(x))

static std::vector<std::string> g_sent;    // complete lines the sketch printed
static std::string g_partial;              // line being built
static std::string g_pending;              // bytes waiting to be read

struct SerialStub {
  void begin(long) {}
  operator bool() const { return true; }
  int available() { return static_cast<int>(g_pending.size()); }
  int read() {
    const int c = g_pending[0];
    g_pending.erase(0, 1);
    return c;
  }

  void print(const char *p) { g_partial += p; }
  void print(char c) { g_partial += c; }
  void print(int v) { g_partial += std::to_string(v); }
  void print(float v, int digits = 2) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%.*f", digits, static_cast<double>(v));
    g_partial += buf;
  }
  void print(const __FlashStringHelper *f) {
    g_partial += reinterpret_cast<const char *>(f);
  }
  void println(const char *p) { print(p), endLine(); }
  void println(int v) { print(v), endLine(); }
  void println(float v, int digits = 2) { print(v, digits), endLine(); }
  void println(const __FlashStringHelper *f) { print(f), endLine(); }

 private:
  void endLine() {
    g_sent.push_back(g_partial);
    g_partial.clear();
  }
} Serial;

ServoLog servoLog;

#include "../pill_dispenser/pill_dispenser.ino"

// ---------------------------------------------------------------- test driver
static int failures = 0;

static void check(bool ok, const std::string &what) {
  printf("%s  %s\n", ok ? "ok  " : "FAIL", what.c_str());
  if (!ok) failures++;
}

static void send(const char *command) {
  g_pending += command;
  g_pending += "\n";
}

// One loop() per simulated millisecond, which is far more often than the real
// sketch needs but keeps the timing arithmetic obvious.
static void run(unsigned long ms) {
  for (unsigned long i = 0; i < ms; ++i) {
    loop();
    g_nowMs++;
  }
}

static std::string lastLine() { return g_sent.empty() ? "" : g_sent.back(); }

// ---------------------------------------------------------------- expectations
//
// Worked out here from the documented formulas rather than read back out of the
// sketch, so an arithmetic mistake in the sketch still fails:
//
//   US_PER_DEG   = (2400 - 600) / 180       = 10.0 us/deg
//   HEADROOM     = TRIM_RANGE + PLAY        = 9 + 2.5827 = 11.5827 deg
//   DOSES        = (180 - 2 * 11.5827) / 45 = 3 after the floor
//   stop i       = 11.5827 + 45 * i
//   forward      = stop i + trim + PLAY     so the carousel lands ON the stop
//   reverse      = stop i + trim - PLAY     the other flank of the same play
static const int US_BOOT = 742;             // stop 0, believed, approached forwards
static const int US_STOP[3] = {1192, 1642, 2092};
static const int US_REZERO = 690;           // stop 0 arrived at in reverse
static const int US_STOP1_TRIM5 = 1242;     // stop 1 with a +5 deg trim

static const unsigned long MOVE_ONE = 270;  // 45 deg at 180 deg/s, plus the 20 ms tail
static const unsigned long SETTLE = 120;
static const unsigned long FALL = 600;

// A ramp, not a jump: several writes, starting where the sketch believed it was,
// monotonic in the direction of travel, never past the target, ending on it.
static bool ramped(int from, int target) {
  const std::vector<int> &w = servoLog.writes;
  if (w.size() < 5) return false;
  if (w.front() != from) return false;
  const bool up = target > from;
  for (size_t i = 1; i < w.size(); ++i) {
    if (up ? (w[i] < w[i - 1]) : (w[i] > w[i - 1])) return false;
    if (up ? (w[i] > target) : (w[i] < target)) return false;
  }
  return w.back() == target;
}

int main() {
  check(US_MIN_SAFE == 600 && US_MAX_SAFE == 2400 && TRAVEL_DEG == 180.0f &&
            TRIM_RANGE_DEG == 9.0f,
        "harness assumes the shipped calibration (recalibrated? update the pulses)");
  check(DOSES_PER_FILL == 3,
        "a 180 deg servo gives three doses once trim and play are reserved");

  setup();
  check(g_sent.size() == 2 && g_sent[0] == "READY_PILL_DISPENSER",
        "boots with the ready banner");
  check(lastLine() == "CAL US=600..2400 TRAVEL=180.0 PLAY=2.58 TRIM=0.00 DOSES=3",
        "and then reports the calibration it derived");
  check(!servoLog.attached, "servo is detached at boot");
  check(servoLog.writes.empty(),
        "boot commands no pulse, so it cannot sweep full bins");

  send("STATUS");
  run(2);
  check(lastLine() == "STATE=0 STOP=0/3 ANGLE=14.20 US=742 TRIM=0.00 DOSES=3",
        "status reports the stop, the pulse and the trim");

  for (int d = 0; d < 3; ++d) {
    const std::string dose = "dose " + std::to_string(d + 1);
    const int from = (d == 0) ? US_BOOT : US_STOP[d - 1];
    servoLog.writes.clear();
    send("DISPENSE");
    run(1);
    check(servoLog.attached, dose + " drives the servo while stepping");
    run(100);
    check(servoLog.writes.size() > 5 && servoLog.writes.back() > from &&
              servoLog.writes.back() < US_STOP[d],
          dose + " is still on its way up 100 ms in: ramped, not slammed");
    run(MOVE_ONE);
    check(ramped(from, US_STOP[d]),
          dose + " ends on " + std::to_string(US_STOP[d]) + " us, monotonically");
    check(servoLog.attached, dose + " keeps holding while the tablet falls");
    run(SETTLE + FALL + 8);
    check(lastLine() == "ACK_DISPENSE", dose + " acknowledges");
    check(!servoLog.attached, dose + " releases the servo when done");
  }

  send("DISPENSE");
  run(2);
  check(lastLine() == "ERR_MAGAZINE_EMPTY",
        "a fourth dose is refused rather than reported as dispensed");

  servoLog.writes.clear();
  send("REZERO");
  run(1);
  send("DISPENSE");
  run(1);
  check(lastLine() == "ERR_BUSY", "a command mid-cycle reports busy");
  run(1200);
  check(ramped(US_STOP[2], US_REZERO),
        "rezero ramps to 690 us: the same stop, the other flank, because it "
        "arrives in reverse");
  check(lastLine() == "ACK_REZERO", "rezero acknowledges");
  check(!servoLog.attached, "rezero releases the servo when done");

  // A multi-step sweep has to stay driven the whole way: releasing it part way
  // would leave the carousel stopped between compartments, over the opening.
  servoLog.writes.clear();
  send("SETSTOP 3");
  run(2);
  check(lastLine() == "ACK_SETSTOP" && servoLog.writes.empty(),
        "setstop changes the count without moving anything");
  send("REZERO");
  run(700);
  check(servoLog.attached && servoLog.writes.back() > US_REZERO,
        "still driving, and not yet home, 700 ms into a three-step rezero");
  run(400);
  check(!servoLog.attached, "released once the whole sweep is done");

  send("SETSTOP 0");
  run(2);
  servoLog.writes.clear();
  send("TRIM 5");
  run(1);
  check(servoLog.attached,
        "trim re-seats the carousel on its stop so the change can be watched");
  run(300);
  check(lastLine() == "ACK_TRIM 5.00",
        "trim answers only once it has settled, echoing what it applied");
  check(!servoLog.attached, "trim releases the servo when done");
  send("STATUS");
  run(2);
  check(lastLine().find("TRIM=5.00") != std::string::npos,
        "status carries the trim, so a log records the calibration");

  servoLog.writes.clear();
  send("DISPENSE");
  run(1200);
  check(servoLog.writes.back() == US_STOP1_TRIM5,
        "a trim shifts the whole stop table, not just the stop it was set on");

  send("JOG -2");
  run(300);
  check(lastLine() == "ACK_TRIM 3.00", "jog is relative to the trim in force");
  send("TRIM 12");
  run(2);
  check(lastLine() == "ERR_ARG", "a trim past the reserved authority is refused");
  send("STATUS");
  run(2);
  check(lastLine().find("TRIM=3.00") != std::string::npos,
        "and the refused trim did not take effect");
  send("TRIM -4.5");
  run(300);
  check(lastLine() == "ACK_TRIM -4.50", "negative trims are accepted");
  send("TRIM x");
  run(2);
  check(lastLine() == "ERR_ARG", "a trim that is not a number is refused");
  send("JOG");
  run(2);
  check(lastLine() == "ERR_ARG", "jog with no argument is refused");

  send("DISPENSE");
  run(1);
  send("JOG 1");
  run(1);
  check(lastLine() == "ERR_BUSY", "jog mid-cycle reports busy");
  run(1200);

  send("SETSTOP 9");
  run(2);
  check(lastLine() == "ERR_ARG", "setstop past the last stop is rejected");
  send("SETSTOP x");
  run(2);
  check(lastLine() == "ERR_ARG", "setstop with a non-number is rejected");
  send("setstop 2");
  run(2);
  check(lastLine() == "ACK_SETSTOP", "commands are case insensitive");

  send("PING");
  run(2);
  check(lastLine() == "PONG", "ping still answers");
  send("CAL");
  run(2);
  check(lastLine().rfind("CAL US=600..2400", 0) == 0,
        "cal can be asked for again at any time");
  send("WAT");
  run(2);
  check(lastLine() == "ERR_UNKNOWN_CMD", "an unknown command is reported");

  // Nothing in normal operation may command the servo outside its measured ends —
  // that is where it buzzes against its own stops and draws current for nothing.
  int lo = 100000, hi = 0;
  for (size_t i = 0; i < servoLog.all.size(); ++i) {
    if (servoLog.all[i] < lo) lo = servoLog.all[i];
    if (servoLog.all[i] > hi) hi = servoLog.all[i];
  }
  check(lo >= US_MIN_SAFE && hi <= US_MAX_SAFE,
        "every pulse of the run stayed inside " + std::to_string(US_MIN_SAFE) +
            ".." + std::to_string(US_MAX_SAFE) + " us (saw " +
            std::to_string(lo) + ".." + std::to_string(hi) + ")");

  // PULSE is the commissioning escape hatch: the one command allowed past the
  // calibrated ends, because measuring where they are is what it is for.
  const size_t beforeCommissioning = servoLog.all.size();
  const int pulseFrom = commandedUs;
  servoLog.writes.clear();
  send("PULSE 2450");
  run(1);
  check(!servoLog.writes.empty(), "pulse starts moving immediately");
  run(1200);
  check(lastLine() == "ACK_PULSE 2450", "pulse acknowledges the pulse it reached");
  check(servoLog.us == 2450,
        "pulse drove past the calibrated end, which is what commissioning needs");
  check(ramped(pulseFrom, 2450), "pulse ramps there rather than slamming");
  check(!servoLog.attached, "pulse releases the servo when done");

  // A hand-jogged shaft has no known stop, so dispensing waits for the host to
  // say where the carousel actually is.
  send("DISPENSE");
  run(2);
  check(lastLine() == "ERR_MAGAZINE_EMPTY",
        "dispense is refused after a raw pulse until the stop is re-established");
  send("STATUS");
  run(2);
  check(lastLine().find("STOP=3/3") != std::string::npos,
        "status shows the magazine spent after a raw pulse");
  send("SETSTOP 1");
  run(2);
  check(lastLine() == "ACK_SETSTOP", "setstop re-establishes the stop after a pulse");

  send("PULSE 2600");
  run(2);
  check(lastLine() == "ERR_ARG", "a pulse above the commissioning envelope is refused");
  send("PULSE 400");
  run(2);
  check(lastLine() == "ERR_ARG", "a pulse below the commissioning envelope is refused");
  send("PULSE");
  run(2);
  check(lastLine() == "ERR_ARG", "a pulse with no argument is refused");
  send("PULSE 1500");
  run(1);
  send("PULSE 1600");
  run(2);
  check(lastLine() == "ERR_BUSY", "a pulse mid-move reports busy");
  run(400);

  int clo = 100000, chi = 0;
  for (size_t i = beforeCommissioning; i < servoLog.all.size(); ++i) {
    if (servoLog.all[i] < clo) clo = servoLog.all[i];
    if (servoLog.all[i] > chi) chi = servoLog.all[i];
  }
  check(clo >= US_HARD_MIN && chi <= US_HARD_MAX,
        "commissioning pulses stayed inside the 500..2500 us envelope (saw " +
            std::to_string(clo) + ".." + std::to_string(chi) + ")");

  printf("\n%s\n", failures ? "FAILED" : "all checks passed");
  return failures ? 1 : 0;
}
