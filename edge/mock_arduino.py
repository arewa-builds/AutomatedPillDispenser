"""In-process mock of the Nano 33 BLE serial protocol for pre-hardware development."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass

from config import ACK_TOKEN, DISPENSE_COMMAND, MOCK_DISPENSE_LATENCY_MS

logger = logging.getLogger(__name__)


@dataclass
class MockSerialResponse:
    ok: bool
    message: str
    latency_ms: int


class MockArduino:
    """
    Emulates firmware serial commands:

      Host -> DISPENSE\\n
      Device -> ACK_DISPENSE\\n
    """

    def __init__(self, latency_ms: int = MOCK_DISPENSE_LATENCY_MS, fail_every: int = 0) -> None:
        self.latency_ms = latency_ms
        self.fail_every = fail_every
        self._calls = 0
        self.is_open = True

    def send_dispense(self) -> MockSerialResponse:
        self._calls += 1
        started = time.perf_counter()
        time.sleep(self.latency_ms / 1000.0)
        latency_ms = int((time.perf_counter() - started) * 1000)

        if self.fail_every and self._calls % self.fail_every == 0:
            logger.warning("Mock Arduino simulated failure on call %s", self._calls)
            return MockSerialResponse(False, "ERR_SERVO_TIMEOUT", latency_ms)

        logger.info("Mock Arduino acknowledged %r", DISPENSE_COMMAND.strip())
        return MockSerialResponse(True, ACK_TOKEN, latency_ms)

    def close(self) -> None:
        self.is_open = False
