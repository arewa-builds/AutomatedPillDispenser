"""Serial bridge to Arduino Nano 33 BLE with automatic mock fallback."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from typing import Literal

import serial
from serial.tools import list_ports

from config import ACK_TOKEN, DISPENSE_COMMAND, SERIAL_BAUD, SERIAL_PORT
from mock_arduino import MockArduino, MockSerialResponse

logger = logging.getLogger(__name__)

HardwareMode = Literal["serial", "mock"]


@dataclass
class DispenseCommandResult:
    ok: bool
    message: str
    latency_ms: int
    mode: HardwareMode


class HardwareBridge:
    def __init__(
        self,
        port: str = SERIAL_PORT,
        baud: int = SERIAL_BAUD,
        force_mock: bool = False,
        timeout_s: float = 2.0,
    ) -> None:
        self.port = port
        self.baud = baud
        self.timeout_s = timeout_s
        self._serial: serial.Serial | None = None
        self._mock: MockArduino | None = None
        self.mode: HardwareMode = "mock"

        if force_mock:
            self._mock = MockArduino()
            self.mode = "mock"
            logger.info("HardwareBridge forced into mock mode")
            return

        opened = self._try_open_serial()
        if not opened:
            self._mock = MockArduino()
            self.mode = "mock"
            logger.warning("No Arduino serial port found; using MockArduino")

    def _try_open_serial(self) -> bool:
        candidates: list[str] = []
        if self.port:
            candidates.append(self.port)
        else:
            for item in list_ports.comports():
                desc = f"{item.device} {item.description} {item.manufacturer}".lower()
                if any(token in desc for token in ("arduino", "nano", "usb serial", "ttyacm", "ttyusb")):
                    candidates.append(item.device)

        for candidate in candidates:
            try:
                self._serial = serial.Serial(candidate, self.baud, timeout=self.timeout_s)
                time.sleep(1.5)  # Nano soft-reset settle
                self._serial.reset_input_buffer()
                self.port = candidate
                self.mode = "serial"
                logger.info("Opened Arduino serial on %s @ %s", candidate, self.baud)
                return True
            except Exception:
                logger.exception("Failed opening serial port %s", candidate)
                self._serial = None
        return False

    def dispense(self) -> DispenseCommandResult:
        if self.mode == "mock":
            assert self._mock is not None
            response: MockSerialResponse = self._mock.send_dispense()
            return DispenseCommandResult(
                ok=response.ok,
                message=response.message,
                latency_ms=response.latency_ms,
                mode="mock",
            )

        assert self._serial is not None
        started = time.perf_counter()
        try:
            self._serial.reset_input_buffer()
            self._serial.write(DISPENSE_COMMAND.encode("utf-8"))
            self._serial.flush()
            line = self._serial.readline().decode("utf-8", errors="replace").strip()
            latency_ms = int((time.perf_counter() - started) * 1000)
            ok = ACK_TOKEN in line
            return DispenseCommandResult(ok=ok, message=line or "NO_RESPONSE", latency_ms=latency_ms, mode="serial")
        except Exception as exc:
            latency_ms = int((time.perf_counter() - started) * 1000)
            logger.exception("Serial dispense command failed")
            return DispenseCommandResult(ok=False, message=str(exc), latency_ms=latency_ms, mode="serial")

    def close(self) -> None:
        try:
            if self._serial is not None and self._serial.is_open:
                self._serial.close()
        except Exception:
            logger.exception("Error closing serial port")
        if self._mock is not None:
            self._mock.close()
