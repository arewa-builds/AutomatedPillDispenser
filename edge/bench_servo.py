"""Bench bring-up for the v3 carousel drive: Nano 33 BLE + one MG90S, no CV, no cloud.

Talks to firmware/pill_dispenser over USB serial and exercises the turns, so the
drive train can be checked before the carousel is loaded or the vision stack is in
the loop. Three things it does:

  turns    step a whole fill and rezero, timing each step   (default)
  wiggle   small moves around centre, to prove it responds    --wiggle
  ends     guided hunt for the servo's own mechanical ends   --ends
  sweep    walk raw pulses across a range so travel can be measured with a protractor

Run it with the shaft OUT of the carousel hub, or with every bin empty. A step is a
real 45 deg carousel move and it will dump whatever is above the discharge opening.

    python bench_servo.py --list
    python bench_servo.py                      # the turn check
    python bench_servo.py --wiggle             # first contact, a few degrees each way
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


def stop_of(status_line: str) -> tuple[int, int] | None:
    """Parse STOP=i/n out of a STATUS reply. None if the line is not a status."""
    for token in status_line.split():
        if token.startswith("STOP=") and "/" in token:
            left, right = token[5:].split("/", 1)
            try:
                return int(left), int(right)
            except ValueError:
                return None
    return None


def check_turns(link: NanoLink) -> int:
    """Step a whole fill, then rezero, reporting what each move actually took."""
    failures = 0
    cal = greet(link)
    doses = int(float(cal.get("DOSES", "0")))
    if doses < 1:
        raise BenchError(f"firmware reports {doses} doses per fill; check CAL")

    status = link.ask("STATUS")
    print(f"  status: {status.last}")

    # --wiggle / --ends / --sweep all use PULSE, which marks the magazine spent on
    # purpose. Recover that here so the turn check can follow them without a
    # separate REZERO, rather than failing on a refuse that is not a fault.
    parsed = stop_of(status.last)
    if parsed is not None and parsed[0] >= doses:
        print("  magazine spent (usual after --wiggle); rezeroing before the fill\n")
        recover = link.ask("REZERO", timeout_s=20.0)
        if not recover.ok("ACK_REZERO"):
            print(f"  rezero before fill failed: {recover.last!r}")
            return 1
        print(f"  rezero: ACK after {recover.elapsed_ms} ms — starting the fill from stop 0")
        status = link.ask("STATUS")
        print(f"  status: {status.last}")

    print(f"\n  Expect {doses} steps of {STEP_DEG:.0f} deg, then a rezero back to stop 0.")
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


def wiggle(link: NanoLink, centre: int = 1500, amplitude: int = 150, cycles: int = 2) -> int:
    """First contact: small moves either side of centre, just to prove it turns."""
    greet(link)
    print(f"\n  Wiggling {centre - amplitude} / {centre} / {centre + amplitude} us, "
          f"{cycles} passes. Expect a few degrees of horn movement each way.\n")

    failures = 0
    targets: list[int] = []
    for _ in range(cycles):
        targets += [centre, centre - amplitude, centre + amplitude]
    targets.append(centre)

    for us in targets:
        reply = link.ask(f"PULSE {us}", timeout_s=15.0)
        if reply.ok("ACK_PULSE"):
            print(f"  {us:>5} us: reached after {reply.elapsed_ms} ms")
        else:
            print(f"  {us:>5} us: refused — {reply.last!r}")
            failures += 1
        time.sleep(0.5)

    print("\n  Nothing moved? Check D9, the shared ground, and 5 V at the servo's red lead.")
    print("  Buzzing or stuttering? The supply is sagging under the move.")
    print("  PULSE left the stop unknown: send REZERO before dispensing.")
    return failures


# Commissioning envelope, matching US_HARD_MIN/MAX in the sketch. A hunt that is
# still moving here has not found a mechanical stop.
US_ENVELOPE_LO = 500
US_ENVELOPE_HI = 2500
END_BACKOFF_US = 50
# (TRAVEL - 2 * (TRIM_RANGE 9 + PLAY 2.58)) / 45 crosses 4 at about 203 deg.
FOUR_DOSES_AT_DEG = 203.0


def ask_moved() -> str:
    """'y' the horn moved, 'n' it did not, 'q' stop this direction.

    A blank line is not taken as yes. The previous prompt said "Enter to continue",
    and holding Enter then recorded the envelope limits as if they were the stops.
    """
    while True:
        try:
            answer = input("    did it move further the same way? [y/n/q]: ").strip().lower()
        except EOFError:
            return "q"
        if answer.startswith(("y", "n", "q")):
            return answer[0]
        print("    answer y, n or q — Enter alone does not count")


def read_dial(which: str) -> float | None:
    try:
        raw = input(f"    dial reading at the {which} end (blank to skip): ").strip()
    except EOFError:
        return None
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError:
        print("    not a number; skipping the angle")
        return None


def find_ends(link: NanoLink) -> int:
    """Guided hunt for the ends: creep outward from centre until motion stops."""
    greet(link)
    print("\n  Creeping out from 1500 us in 100 us steps.")
    print("  After each step:")
    print("    y  it moved further, the same way")
    print("    n  it only buzzed or twitched where it was — that is the stop")
    print("    q  it jumped back the other way — stop; commanding further can strip the gears")
    print("  The horn swings back to centre between the two directions on purpose.")
    print("  Enter by itself does nothing, so holding it down cannot invent an end.\n")

    measured: dict[str, int] = {}
    ran_out: dict[str, bool] = {}
    dials: dict[str, float | None] = {}
    for label, direction, which in (
        ("US_MAX_SAFE", +1, "high"),
        ("US_MIN_SAFE", -1, "low"),
    ):
        us = 1500
        reply = link.ask(f"PULSE {us}", timeout_s=15.0)
        if not reply.ok("ACK_PULSE"):
            raise BenchError(f"could not reach centre: {reply.last!r}")
        last_moving = us
        hit_envelope = False
        print(f"  hunting {label}, from {us} us:")
        while True:
            nxt = us + direction * 100
            if not US_ENVELOPE_LO <= nxt <= US_ENVELOPE_HI:
                print(
                    f"    still moving at the {US_ENVELOPE_LO}..{US_ENVELOPE_HI} us "
                    "envelope, so the mechanical stop is past what this sketch can command"
                )
                hit_envelope = True
                break
            reply = link.ask(f"PULSE {nxt}", timeout_s=15.0)
            if not reply.ok("ACK_PULSE"):
                print(f"    refused at {nxt} us — {reply.last!r}")
                break
            print(f"    {nxt} us, reached after {reply.elapsed_ms} ms")
            answer = ask_moved()
            if answer == "q":
                print("    kept the previous pulse. A jump the other way means this one")
                print("    went past the feedback pot.")
                break
            if answer != "y":
                print("    kept the previous pulse. Buzzing in place is the horn against")
                print("    its stop, not more travel.")
                break
            last_moving = nxt
            us = nxt
        measured[label] = last_moving
        ran_out[label] = hit_envelope
        print(f"    last pulse that moved the horn: {last_moving} us")
        dials[label] = read_dial(which)
        link.ask("PULSE 1500", timeout_s=15.0)
        print()

    safe_lo = measured["US_MIN_SAFE"] + END_BACKOFF_US
    safe_hi = measured["US_MAX_SAFE"] - END_BACKOFF_US
    if ran_out["US_MIN_SAFE"] or ran_out["US_MAX_SAFE"]:
        print("  These are safe command limits, not measured stops: the horn was still")
        print("  moving when the envelope ran out. The angle between them is the travel.")
    else:
        print("  Last pulses that still moved the horn, backed off 50 us so it never")
        print("  buzzes against its own stop:")
    print(f"    US_MIN_SAFE = {safe_lo}")
    print(f"    US_MAX_SAFE = {safe_hi}")

    lo, hi = dials["US_MIN_SAFE"], dials["US_MAX_SAFE"]
    if lo is not None and hi is not None:
        travel = abs(hi - lo)
        if travel > 270:
            print(
                f"  {travel:.0f} deg means the pointer crossed 0 between the readings. "
                "Re-read both ends from the same side of the dial."
            )
        else:
            doses = "four" if travel >= FOUR_DOSES_AT_DEG else "three"
            print(f"    TRAVEL_DEG = {travel:.0f}  ->  {doses} doses per fill")
            print("  Four doses needs 203 deg, once trim and play are reserved at both ends.")
    else:
        print("  TRAVEL_DEG is the angle between those two ends. The dial in")
        print("  docs/diagrams/servo_protractor.png marks the 203 deg line.")

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
    parser.add_argument("--wiggle", action="store_true",
                        help="small moves around centre, to prove the servo responds")
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
            elif args.wiggle:
                failures = wiggle(link)
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
