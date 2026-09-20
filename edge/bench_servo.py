"""Bench bring-up for the v3 carousel drive: Nano 33 BLE + one MG90S, no CV, no cloud.

Talks to firmware/pill_dispenser over USB serial and exercises the turns, so the
drive train can be checked before the carousel is loaded or the vision stack is in
the loop. Three things it does:

  turns    step a whole fill and rezero, timing each step   (default)
  ends     guided hunt for the servo's own mechanical ends   --ends
  sweep    walk raw pulses across a range so travel can be measured with a protractor

Run it with the shaft OUT of the carousel hub, or with every bin empty. A step is a
real 45 deg carousel move and it will dump whatever is above the discharge opening.

    python bench_servo.py --list
    python bench_servo.py                      # the turn check
    python bench_servo.py --ends
    python bench_servo.py --sweep 600 2400 --step 200 --dwell 1.5
    python bench_servo.py --cmd "TRIM 3" --cmd STATUS
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
from dataclasses import dataclass, field

import serial
from serial.tools import list_ports

LOG = logging.getLogger("bench_servo")

BAUD = 115200
# Tokens that end a reply. Everything else the device prints is progress or noise.
TERMINATORS = ("ACK_", "ERR_", "PONG", "CAL ", "STATE=", "READY_")
# A step is one bin of an eight bin carousel; useful to print next to each move.
STEP_DEG = 45.0


class BenchError(RuntimeError):
    """Anything that makes the bench check meaningless: no port, no reply, bad reply."""


@dataclass
class Reply:
    lines: list[str] = field(default_factory=list)
    elapsed_ms: int = 0

    @property
    def last(self) -> str:
        return self.lines[-1] if self.lines else ""

    def ok(self, prefix: str) -> bool:
        return self.last.startswith(prefix)


class NanoLink:
    """One serial conversation with the sketch, line in / lines out."""

    def __init__(self, port: str, baud: int = BAUD, timeout_s: float = 1.0) -> None:
        self.port = port
        try:
            self._serial = serial.Serial(port, baud, timeout=timeout_s)
        except (serial.SerialException, OSError) as exc:
            raise BenchError(f"cannot open {port}: {exc}") from exc
        LOG.info("event=port_open port=%s baud=%d", port, baud)

    def close(self) -> None:
        try:
            self._serial.close()
        except (serial.SerialException, OSError) as exc:  # nothing useful left to do
            LOG.warning("event=port_close_failed port=%s error=%s", self.port, exc)

    def __enter__(self) -> "NanoLink":
        return self

    def __exit__(self, *_exc: object) -> None:
        self.close()

    def _readline(self) -> str:
        try:
            raw = self._serial.readline()
        except (serial.SerialException, OSError) as exc:
            raise BenchError(f"read failed on {self.port}: {exc}") from exc
        return raw.decode("utf-8", errors="replace").strip()

    def drain(self, window_s: float = 2.0) -> list[str]:
        """Collect whatever the device is already saying, e.g. the boot banner."""
        lines: list[str] = []
        deadline = time.monotonic() + window_s
        while time.monotonic() < deadline:
            line = self._readline()
            if line:
                LOG.debug("event=rx line=%r", line)
                lines.append(line)
        return lines

    def ask(self, command: str, timeout_s: float = 6.0) -> Reply:
        """Send one command, return every line up to and including the terminator."""
        try:
            self._serial.reset_input_buffer()
            self._serial.write(f"{command}\n".encode("ascii"))
            self._serial.flush()
        except (serial.SerialException, OSError, UnicodeEncodeError) as exc:
            raise BenchError(f"write of {command!r} failed: {exc}") from exc

        started = time.monotonic()
        reply = Reply()
        deadline = started + timeout_s
        while time.monotonic() < deadline:
            line = self._readline()
            if not line:
                continue
            LOG.debug("event=rx line=%r", line)
            reply.lines.append(line)
            if line.startswith(TERMINATORS):
                break
        reply.elapsed_ms = int((time.monotonic() - started) * 1000)
        if not reply.lines:
            raise BenchError(
                f"no reply to {command!r} within {timeout_s:.1f}s — wrong port, "
                "or the sketch is not the one in firmware/pill_dispenser"
            )
        LOG.info(
            "event=exchange command=%s reply=%s elapsed_ms=%d",
            command,
            reply.last,
            reply.elapsed_ms,
        )
        return reply


def candidate_ports() -> list[str]:
    ports = list(list_ports.comports())
    # Anything that announces itself as an Arduino first, then the usual CDC names.
    named = [p.device for p in ports if "arduino" in (p.manufacturer or "").lower()]
    cdc = [p.device for p in ports if p.device.startswith(("/dev/ttyACM", "/dev/cu.usbmodem", "COM"))]
    seen: list[str] = []
    for device in named + cdc + [p.device for p in ports]:
        if device not in seen:
            seen.append(device)
    return seen


def resolve_port(requested: str | None) -> str:
    if requested:
        return requested
    ports = candidate_ports()
    if not ports:
        raise BenchError(
            "no serial ports found — plug the Nano in, and on Linux check you are "
            "in the dialout group (sudo usermod -aG dialout $USER, then log out)"
        )
    LOG.info("event=port_autodetect chosen=%s candidates=%s", ports[0], ",".join(ports))
    return ports[0]


def greet(link: NanoLink) -> dict[str, str]:
    """Pick up the banner if the board just reset, then confirm it is alive.

    The Nano 33 BLE has native USB, so opening the port does not necessarily reset
    it; a missing banner is normal and only silence from PING is a problem.
    """
    banner = link.drain(window_s=2.0)
    for line in banner:
        print(f"  boot: {line}")

    pong = link.ask("PING", timeout_s=3.0)
    if not pong.ok("PONG"):
        raise BenchError(f"expected PONG, got {pong.last!r}")

    cal = link.ask("CAL")
    if not cal.ok("CAL "):
        raise BenchError(f"expected a CAL line, got {cal.last!r}")
    fields = dict(
        token.split("=", 1) for token in cal.last.split()[1:] if "=" in token
    )
    print(f"  calibration: {cal.last}")
    return fields


def check_turns(link: NanoLink) -> int:
    """Step a whole fill, then rezero, reporting what each move actually took."""
    failures = 0
    cal = greet(link)
    doses = int(float(cal.get("DOSES", "0")))
    if doses < 1:
        raise BenchError(f"firmware reports {doses} doses per fill; check CAL")

    status = link.ask("STATUS")
    print(f"  status: {status.last}\n")
    print(f"  Expect {doses} steps of {STEP_DEG:.0f} deg, then a rezero back to stop 0.")
    print("  Watch the mark on the shaft: each ACK_DISPENSE is one bin.\n")

    served = 0
    for dose in range(1, doses + 2):  # one past the fill, to see the refusal
        reply = link.ask("DISPENSE", timeout_s=15.0)
        if reply.ok("ACK_DISPENSE"):
            served += 1
            print(
                f"  step {served}: ACK after {reply.elapsed_ms} ms "
                f"({served * STEP_DEG:.0f} deg from stop 0)"
            )
        elif reply.ok("ERR_MAGAZINE_EMPTY"):
            print(f"  step {dose}: refused, magazine spent — correct after {served} doses")
            break
        else:
            print(f"  step {dose}: unexpected reply {reply.last!r}")
            failures += 1
            break

    if served != doses:
        print(f"  MISMATCH: served {served} doses, firmware promised {doses}")
        failures += 1

    rezero = link.ask("REZERO", timeout_s=20.0)
    if rezero.ok("ACK_REZERO"):
        print(f"\n  rezero: ACK after {rezero.elapsed_ms} ms — shaft should be back on the mark")
    else:
        print(f"\n  rezero: unexpected reply {rezero.last!r}")
        failures += 1

    print("\n  If the mark did not come back to where it started, the coupling is")
    print("  slipping on the horn; if it overshot the mark, TRIM it (see firmware/README).")
    return failures


def sweep(link: NanoLink, lo: int, hi: int, step: int, dwell_s: float) -> int:
    """Walk raw pulses so travel can be measured with a protractor at each end."""
    greet(link)
    if step <= 0:
        raise BenchError("--step must be positive")
    print(f"\n  Sweeping {lo}..{hi} us in {step} us steps, {dwell_s:.1f}s dwell.")
    print("  Measure the horn angle at the first and last pulse that still moves it.\n")

    failures = 0
    pulses = list(range(lo, hi + 1, step))
    if pulses[-1] != hi:
        pulses.append(hi)
    for us in pulses:
        reply = link.ask(f"PULSE {us}", timeout_s=15.0)
        if reply.ok("ACK_PULSE"):
            print(f"  {us:>5} us: reached after {reply.elapsed_ms} ms")
        else:
            print(f"  {us:>5} us: refused — {reply.last!r}")
            failures += 1
        time.sleep(dwell_s)

    print("\n  Put US_MIN_SAFE / US_MAX_SAFE / TRAVEL_DEG in the sketch, then rebuild.")
    print("  PULSE left the stop unknown: send REZERO or SETSTOP before dispensing.")
    return failures


def find_ends(link: NanoLink) -> int:
    """Guided hunt for the ends: creep outward from centre until motion stops."""
    greet(link)
    print("\n  Creeping out from 1500 us in 100 us steps, one key press at a time.")
    print("  Press Enter to take the next step, or q when the horn stops moving.\n")

    measured: dict[str, int] = {}
    for label, direction in (("US_MAX_SAFE", +1), ("US_MIN_SAFE", -1)):
        us = 1500
        link.ask(f"PULSE {us}", timeout_s=15.0)
        last_moving = us
        print(f"  hunting {label}:")
        while 500 <= us <= 2500:
            try:
                answer = input(f"    at {us} us — Enter to continue, q to stop: ")
            except EOFError:
                answer = "q"
            if answer.strip().lower().startswith("q"):
                break
            us += direction * 100
            if not 500 <= us <= 2500:
                print("    hit the 500..2500 us envelope; stopping there")
                us -= direction * 100
                break
            reply = link.ask(f"PULSE {us}", timeout_s=15.0)
            if not reply.ok("ACK_PULSE"):
                print(f"    refused at {us} us — {reply.last!r}")
                break
            last_moving = us
        measured[label] = last_moving
        print(f"    {label} = {last_moving} us\n")
        link.ask("PULSE 1500", timeout_s=15.0)

    span = measured["US_MAX_SAFE"] - measured["US_MIN_SAFE"]
    print("  Back off each end by ~50 us so the servo never buzzes against it, then")
    print("  measure the horn angle between the two and set TRAVEL_DEG to it:")
    print(f"    US_MIN_SAFE = {measured['US_MIN_SAFE'] + 50}")
    print(f"    US_MAX_SAFE = {measured['US_MAX_SAFE'] - 50}")
    print(f"    (raw span {span} us; TRAVEL_DEG is the angle you measure, not a guess)")
    print("  PULSE left the stop unknown: send REZERO or SETSTOP before dispensing.")
    return 0


def run_commands(link: NanoLink, commands: list[str]) -> int:
    greet(link)
    failures = 0
    for command in commands:
        reply = link.ask(command, timeout_s=20.0)
        for line in reply.lines:
            print(f"  {command} -> {line}")
        if reply.last.startswith("ERR_"):
            failures += 1
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", help="serial port; autodetected when omitted")
    parser.add_argument("--baud", type=int, default=BAUD)
    parser.add_argument("--list", action="store_true", help="list serial ports and exit")
    parser.add_argument("--ends", action="store_true", help="guided endpoint hunt")
    parser.add_argument(
        "--sweep", nargs=2, type=int, metavar=("LO", "HI"), help="walk raw pulses LO..HI"
    )
    parser.add_argument("--step", type=int, default=200, help="sweep increment, us")
    parser.add_argument("--dwell", type=float, default=1.0, help="sweep dwell, seconds")
    parser.add_argument(
        "--cmd", action="append", default=[], help="send a raw command (repeatable)"
    )
    parser.add_argument("--verbose", action="store_true", help="log every serial line")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
        stream=sys.stderr,
    )

    if args.list:
        for port in list_ports.comports():
            print(f"  {port.device}  {port.description}  [{port.manufacturer or '?'}]")
        return 0

    print("\n  Shaft out of the carousel hub, or all bins empty — a step really turns it.\n")
    try:
        with NanoLink(resolve_port(args.port), args.baud) as link:
            if args.cmd:
                failures = run_commands(link, args.cmd)
            elif args.ends:
                failures = find_ends(link)
            elif args.sweep:
                failures = sweep(link, args.sweep[0], args.sweep[1], args.step, args.dwell)
            else:
                failures = check_turns(link)
    except BenchError as exc:
        LOG.error("event=bench_failed error=%s", exc)
        return 2
    except KeyboardInterrupt:
        LOG.warning("event=interrupted")
        return 130

    print(f"\n  {'FAILED: ' + str(failures) + ' problem(s)' if failures else 'all good'}\n")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
