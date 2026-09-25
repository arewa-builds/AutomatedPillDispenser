// Host stub for the Arduino Servo library, used only by host_harness.cpp.
// Records what the sketch commands so the harness can assert on it.
#pragma once

#include <cstdint>
#include <vector>

struct ServoLog {
  bool attached = false;
  int us = -1;                 // last pulse commanded
  std::vector<int> writes;     // pulses since the harness last cleared this
  std::vector<int> all;        // every pulse of the whole run, never cleared
};

extern ServoLog servoLog;

class Servo {
 public:
  void attach(uint8_t) { servoLog.attached = true; }
  void detach() { servoLog.attached = false; }

  // The sketch commands pulse widths, not degrees — the park margin cannot afford
  // write()'s 1 deg quantisation — but keep write() so the stub stays a stand-in
  // for the real library rather than for this one sketch.
  void write(int angle) { writeMicroseconds(544 + angle * 1856 / 180); }

  void writeMicroseconds(int us) {
    servoLog.us = us;
    servoLog.writes.push_back(us);
    servoLog.all.push_back(us);
  }
};
