// Host stub for the Arduino Servo library, used only by host_harness.cpp.
// Records what the sketch commands so the harness can assert on it.
#pragma once

#include <cstdint>
#include <vector>

struct ServoLog {
  bool attached = false;
  int angle = -1;
  std::vector<int> writes;
};

extern ServoLog servoLog;

class Servo {
 public:
  void attach(uint8_t) { servoLog.attached = true; }
  void detach() { servoLog.attached = false; }
  void write(int angle) {
    servoLog.angle = angle;
    servoLog.writes.push_back(angle);
  }
};
