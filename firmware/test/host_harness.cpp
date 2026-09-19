// ============================================================================
// Host harness for firmware/pill_dispenser/pill_dispenser.ino
//
// Compiles the sketch on a PC against small stubs — a fake clock, a fake serial
// port and a recording Servo — and drives it through the sequences that matter.
// It checks behaviour, not just that the sketch compiles: four doses per fill and
// then a refusal, one 45 deg step per dose at the right absolute angle, the servo
// released after every cycle and never driven at boot, and a rezero held for its
// whole four-step sweep.
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
  void print(const __FlashStringHelper *f) {
    g_partial += reinterpret_cast<const char *>(f);
  }
  void println(const char *p) { print(p), endLine(); }
  void println(int v) { print(v), endLine(); }
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

static const unsigned long MOVE = 400;      // MOVE_MS_PER_STEP
static const unsigned long FALL = 600;      // DOSE_FALL_MS

int main() {
  setup();
  check(lastLine() == "READY_PILL_DISPENSER", "boots with the ready banner");
  check(!servoLog.attached, "servo is detached at boot");
  check(servoLog.writes.empty(),
        "boot commands no angle, so it cannot sweep full bins");

  send("STATUS");
  run(2);
  check(lastLine() == "STATE=0 STOP=0/4 ANGLE=0", "status reports stop 0 of 4");

  const int expected[4] = {45, 90, 135, 180};
  for (int d = 0; d < 4; ++d) {
    const std::string dose = "dose " + std::to_string(d + 1);
    servoLog.writes.clear();
    send("DISPENSE");
    run(1);
    check(servoLog.writes.size() == 1 && servoLog.writes[0] == expected[d],
          dose + " commands " + std::to_string(expected[d]) + " deg, once");
    check(servoLog.attached, dose + " drives the servo while stepping");
    run(MOVE + FALL + 4);
    check(lastLine() == "ACK_DISPENSE", dose + " acknowledges");
    check(!servoLog.attached, dose + " releases the servo when done");
  }

  send("DISPENSE");
  run(2);
  check(lastLine() == "ERR_MAGAZINE_EMPTY",
        "a fifth dose is refused rather than reported as dispensed");

  send("REZERO");
  run(1);
  send("DISPENSE");
  run(1);
  check(lastLine() == "ERR_BUSY", "a command mid-cycle reports busy");
  check(servoLog.writes.back() == 0, "rezero commands 0 deg");
  run(MOVE * 4 + 10);
  check(lastLine() == "ACK_REZERO", "rezero acknowledges after four steps");
  check(!servoLog.attached, "rezero releases the servo when done");

  send("STATUS");
  run(2);
  check(lastLine() == "STATE=0 STOP=0/4 ANGLE=0", "rezero returns the count to 0");

  // The four-step sweep must stay driven throughout: releasing it early would
  // leave the carousel stopped between compartments, over the opening.
  servoLog.writes.clear();
  send("SETSTOP 4");
  run(2);
  check(lastLine() == "ACK_SETSTOP" && servoLog.writes.empty(),
        "setstop changes the count without moving anything");
  send("REZERO");
  run(1 + MOVE * 3);
  check(servoLog.attached, "still driving three steps into a four-step rezero");
  run(MOVE + 10);
  check(!servoLog.attached, "released once the whole sweep is done");

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
  send("WAT");
  run(2);
  check(lastLine() == "ERR_UNKNOWN_CMD", "an unknown command is reported");

  printf("\n%s\n", failures ? "FAILED" : "all checks passed");
  return failures ? 1 : 0;
}
