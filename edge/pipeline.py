"""
End-to-end edge pipeline (software-first):

  Face presence -> hardware DISPENSE (serial or mock) -> pill verify -> telemetry JSONL

Usage:
  python pipeline.py --mode mock
  python pipeline.py --mode serial --port /dev/ttyACM0
  python pipeline.py --mode mock --headless   # single-shot using camera if available
"""

from __future__ import annotations

import argparse
import logging
import sys
import time

import cv2

from config import CAMERA_INDEX, FRAME_HEIGHT, FRAME_WIDTH, RETRY_LIMIT
from face_gate import FaceGate
from hardware_bridge import HardwareBridge
from pill_verify import PillVerifier
from telemetry import TelemetryWriter, build_event

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("pipeline")


def _capture_backends() -> list[tuple[int, str]]:
    """DirectShow first on Windows. The default MSMF backend often reports a closed camera."""
    if sys.platform == "win32" and hasattr(cv2, "CAP_DSHOW"):
        return [(cv2.CAP_DSHOW, "dshow"), (cv2.CAP_ANY, "default")]
    return [(cv2.CAP_ANY, "default")]


def try_open_camera(index: int = CAMERA_INDEX) -> cv2.VideoCapture | None:
    """Open a camera, releasing any backend that does not actually start."""
    for backend, name in _capture_backends():
        try:
            capture = cv2.VideoCapture(index, backend)
        except Exception:
            logger.exception("Camera index %s failed to open via %s", index, name)
            continue
        if capture.isOpened():
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)
            logger.info("Camera index %s opened via %s", index, name)
            return capture
        capture.release()
        logger.info("Camera index %s did not open via %s", index, name)
    return None


def open_camera(index: int = CAMERA_INDEX) -> cv2.VideoCapture:
    capture = try_open_camera(index)
    if capture is None:
        raise RuntimeError(
            f"Camera index {index} could not be opened. "
            "Allow desktop apps to use the camera, and close anything else that has it."
        )
    return capture


def annotate(frame, face_result, pill_result, status: str, verifier: PillVerifier | None = None):
    if face_result.box is not None:
        x, y, w, h = face_result.box
        color = (40, 200, 40) if face_result.stable else (40, 180, 220)
        cv2.rectangle(frame, (x, y), (x + w, y + h), color, 2)
        cv2.putText(
            frame,
            f"face {face_result.confidence:.2f}",
            (x, max(20, y - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            color,
            2,
        )

    if verifier is not None:
        x0, y0, x1, y1 = verifier.roi_rect(frame)
    else:
        h, w = frame.shape[:2]
        y0, y1 = int(h * 0.55), int(h * 0.98)
        x0, x1 = int(w * 0.02), int(w * 0.48)
    cv2.rectangle(frame, (x0, y0), (x1, y1), (220, 180, 40), 1)
    cv2.putText(frame, status, (20, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (240, 240, 240), 2)
    if pill_result is not None:
        cv2.putText(
            frame,
            f"pills={pill_result.count} base={pill_result.baseline} "
            f"need>={pill_result.target} match={pill_result.matched}",
            (20, 60),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (240, 240, 240),
            2,
        )
    return frame


def wait_for_face(
    capture,
    face_gate: FaceGate,
    verifier: PillVerifier,
    want_present: bool,
    status_when_waiting: str,
):
    """Block until the face is stably present, or fully gone.

    Between doses the patient has to leave the frame and come back — otherwise a
    still-present face immediately burns the next slot of a three-dose magazine.
    """
    while True:
        ok, frame = capture.read()
        if not ok or frame is None:
            raise RuntimeError("Camera frame grab failed")
        face_result = face_gate.evaluate(frame)
        if want_present:
            ready = face_result.stable
            status = (
                f"Face stable ({face_result.confidence:.2f}) — dispensing"
                if ready
                else f"Waiting for face… present={face_result.present} "
                f"conf={face_result.confidence:.2f}"
            )
        else:
            ready = not face_result.present
            status = status_when_waiting if not ready else "Clear — ready for next patient"
        display = annotate(frame.copy(), face_result, None, status, verifier)
        cv2.imshow("Pill Dispenser Edge (q=quit)", display)
        key = cv2.waitKey(1) & 0xFF
        if key == ord("q"):
            return None, False
        if ready:
            return face_result, True


def run_cycle(capture, face_gate: FaceGate, bridge: HardwareBridge, verifier: PillVerifier, writer: TelemetryWriter):
    face_result, cont = wait_for_face(
        capture, face_gate, verifier, want_present=True, status_when_waiting=""
    )
    if not cont or face_result is None:
        return False

    cycle_started = time.perf_counter()
    event_status = "failure"
    pills_detected = 0
    hw_latency = 0
    pill_result = None
    retries = 0

    # Count what is already in the tray so a leftover tablet cannot pass for a
    # new dose, and so two tablets do not fail a check that still expected "1".
    baseline = verifier.baseline(capture)

    dispense = bridge.dispense()
    hw_latency = dispense.latency_ms
    if not dispense.ok:
        logger.error("Dispense failed: %s", dispense.message)
        if "ERR_MAGAZINE_EMPTY" in dispense.message:
            logger.warning("Magazine empty — sending REZERO; refill the carousel")
            recover = bridge.rezero()
            if recover.ok:
                logger.info("REZERO acknowledged in %s ms", recover.latency_ms)
            else:
                logger.error("REZERO failed: %s", recover.message)
            event_status = "failure"
            # Hold until the face leaves so we do not spam DISPENSE into an empty magazine.
            _, cont = wait_for_face(
                capture,
                face_gate,
                verifier,
                want_present=False,
                status_when_waiting="Magazine empty — refill, then step out of frame",
            )
            if not cont:
                return False
        else:
            event_status = "failure"
    else:
        # One physical dispense per cycle. Retries only re-check the camera —
        # re-sending DISPENSE was burning the three-dose magazine on CV noise.
        while retries <= RETRY_LIMIT:
            pill_result = verifier.wait_for_pill(capture, baseline=baseline)
            pills_detected = pill_result.count
            if pill_result.matched:
                event_status = "success" if retries == 0 else "retry"
                break
            retries += 1
            if retries <= RETRY_LIMIT:
                logger.warning(
                    "Pill not verified (count=%s baseline=%s need>=%s); "
                    "re-checking camera %s/%s — clear the tray if a leftover is sitting there",
                    pill_result.count,
                    pill_result.baseline,
                    pill_result.target,
                    retries,
                    RETRY_LIMIT,
                )
            else:
                event_status = "failure"
                logger.error(
                    "Pill not verified after dispense (count=%s baseline=%s need>=%s)",
                    pill_result.count,
                    pill_result.baseline,
                    pill_result.target,
                )

    total_latency = int((time.perf_counter() - cycle_started) * 1000)
    source = "mock" if bridge.mode == "mock" else "serial"
    event = build_event(
        face_match_confidence=face_result.confidence,
        pills_detected=pills_detected,
        dispense_latency_ms=total_latency if total_latency > 0 else hw_latency,
        event_status=event_status,  # type: ignore[arg-type]
        hardware_source=source,  # type: ignore[arg-type]
        retry_count=retries,
    )
    writer.write(event)
    logger.info("Cycle complete: %s", event.to_dict())

    # Brief status overlay
    deadline = time.perf_counter() + 1.2
    while time.perf_counter() < deadline:
        ok, frame = capture.read()
        if not ok:
            break
        display = annotate(frame, face_result, pill_result, f"Result: {event_status}", verifier)
        cv2.imshow("Pill Dispenser Edge (q=quit)", display)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            return False

    # Require the face to leave before the next cycle can arm — this is what
    # stops a seated patient from emptying the magazine in three seconds.
    face_gate.reset()
    if event_status != "failure" or "ERR_MAGAZINE_EMPTY" not in (dispense.message if not dispense.ok else ""):
        _, cont = wait_for_face(
            capture,
            face_gate,
            verifier,
            want_present=False,
            status_when_waiting="Dose done — step out of frame before the next one",
        )
        if not cont:
            return False
    face_gate.reset()
    return True


def run_headless_smoke(bridge: HardwareBridge, writer: TelemetryWriter) -> None:
    """No GUI path for CI / remote agents without a camera display."""
    logger.info("Running headless mock smoke (no camera UI)")
    dispense = bridge.dispense()
    event = build_event(
        face_match_confidence=0.91,
        pills_detected=1 if dispense.ok else 0,
        dispense_latency_ms=dispense.latency_ms,
        event_status="success" if dispense.ok else "failure",
        hardware_source="mock",
        retry_count=0,
    )
    path = writer.write(event)
    logger.info("Headless smoke wrote %s", path)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Automated pill dispenser edge pipeline")
    parser.add_argument("--mode", choices=("mock", "serial"), default="mock")
    parser.add_argument("--port", default="", help="Serial port for Arduino (serial mode)")
    parser.add_argument("--headless", action="store_true", help="Skip camera UI; mock telemetry only")
    parser.add_argument("--cycles", type=int, default=0, help="Stop after N cycles (0 = until quit)")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    force_mock = args.mode == "mock"
    bridge = HardwareBridge(port=args.port, force_mock=force_mock)
    writer = TelemetryWriter()

    if args.headless or (force_mock and not _camera_available()):
        if not args.headless and force_mock:
            logger.warning(
                "Camera index %s did not open; falling back to headless smoke. "
                "The face confidence and pill count in that log line are placeholders, "
                "not a detection. Allow desktop apps to use the camera and close anything else using it.",
                CAMERA_INDEX,
            )
        try:
            run_headless_smoke(bridge, writer)
            return 0
        finally:
            bridge.close()

    capture = None
    face_gate = FaceGate()
    verifier = PillVerifier()
    completed = 0
    try:
        capture = open_camera()
        while True:
            cont = run_cycle(capture, face_gate, bridge, verifier, writer)
            if not cont:
                break
            completed += 1
            if args.cycles and completed >= args.cycles:
                break
        return 0
    except Exception:
        logger.exception("Pipeline terminated with error")
        return 1
    finally:
        face_gate.close()
        bridge.close()
        if capture is not None:
            capture.release()
        cv2.destroyAllWindows()


def _camera_available(index: int = CAMERA_INDEX) -> bool:
    capture = try_open_camera(index)
    if capture is None:
        return False
    capture.release()
    return True


if __name__ == "__main__":
    raise SystemExit(main())
