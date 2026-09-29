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
import numpy as np

from config import CAMERA_INDEX, FRAME_HEIGHT, FRAME_WIDTH, RETRY_LIMIT
from face_gate import FaceGate
from hardware_bridge import HardwareBridge
from pill_verify import PillVerifier, latest_frame
from telemetry import TelemetryWriter, build_event

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("pipeline")

WINDOW = "Pill Dispenser Edge (q=quit)"


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
            capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
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


def annotate(frame, face_result, pill_result, status: str):
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

    h, w = frame.shape[:2]
    y0, y1 = int(h * 0.45), int(h * 0.95)
    x0, x1 = int(w * 0.20), int(w * 0.80)
    cv2.rectangle(frame, (x0, y0), (x1, y1), (220, 180, 40), 1)
    cv2.putText(frame, status, (20, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (240, 240, 240), 2)
    if pill_result is not None:
        cv2.putText(
            frame,
            f"pills={pill_result.count} match={pill_result.matched}",
            (20, 60),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.65,
            (240, 240, 240),
            2,
        )
        # Contours are in tray-ROI coordinates. Draw them back on the full frame.
        origin_x, origin_y = int(w * 0.20), int(h * 0.45)
        for x, y, bw, bh in pill_result.contours:
            cv2.rectangle(
                frame,
                (origin_x + x, origin_y + y),
                (origin_x + x + bw, origin_y + y + bh),
                (40, 220, 220),
                2,
            )
    return frame


def settle_camera(capture: cv2.VideoCapture, frames: int = 15) -> None:
    """Show the first frames instead of counting a face against a black image.

    Laptop cameras spend the first part of a second settling exposure. Those
    frames used to be the ones the face gate was waiting on, which is the slow
    startup before the first dispense.
    """
    started = time.perf_counter()
    shown = 0
    for _ in range(frames):
        ok, frame = capture.read()
        if not ok or frame is None:
            continue
        shown += 1
        cv2.putText(
            frame,
            "Camera settling...",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (240, 240, 240),
            2,
        )
        cv2.imshow(WINDOW, frame)
        cv2.waitKey(1)
    logger.info(
        "Camera settled in %s ms (%s frames)",
        int((time.perf_counter() - started) * 1000),
        shown,
    )


def run_cycle(capture, face_gate: FaceGate, bridge: HardwareBridge, verifier: PillVerifier, writer: TelemetryWriter):
    status = "Looking for stable face..."
    pill_result = None
    face_result = face_gate.evaluate(np.zeros((480, 640, 3), dtype=np.uint8))

    # Warm until face is stable
    while True:
        ok, frame = capture.read()
        if not ok or frame is None:
            raise RuntimeError("Camera frame grab failed")
        face_result = face_gate.evaluate(frame)
        status = (
            f"Face stable ({face_result.confidence:.2f}) — dispensing"
            if face_result.stable
            else f"Face present={face_result.present} conf={face_result.confidence:.2f}"
        )
        display = annotate(frame.copy(), face_result, pill_result, status)
        cv2.imshow(WINDOW, display)
        key = cv2.waitKey(1) & 0xFF
        if key == ord("q"):
            return False
        if face_result.stable:
            break

    cycle_started = time.perf_counter()
    retries = 0
    event_status = "failure"
    pills_detected = 0
    hw_latency = 0

    while retries <= RETRY_LIMIT:
        ok, base_frame = latest_frame(capture, discard=4)
        if not ok or base_frame is None:
            logger.error("No frame for the tray baseline; not dispensing")
            event_status = "failure"
            break
        baseline = verifier.count_pills(base_frame).count
        logger.info("Tray baseline %s before dispense", baseline)

        dispense = bridge.dispense()
        hw_latency = dispense.latency_ms
        if not dispense.ok:
            logger.error("Dispense failed: %s", dispense.message)
            event_status = "failure"
            break

        def show_verify(frame, result, baseline=baseline):
            annotate(
                frame,
                face_result,
                result,
                f"Need {baseline + 1} in the tray (was {baseline})",
            )
            cv2.imshow(WINDOW, frame)
            cv2.waitKey(1)

        pill_result = verifier.wait_for_pill(capture, baseline=baseline, on_frame=show_verify)
        pills_detected = max(0, pill_result.count - baseline)
        if pill_result.matched:
            event_status = "success" if retries == 0 else "retry"
            break

        retries += 1
        event_status = "retry"
        logger.warning("Pill not verified; retry %s/%s", retries, RETRY_LIMIT)
        face_gate.reset()

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
        display = annotate(
            frame,
            face_result,
            pill_result,
            f"Result: {event_status}  new={pills_detected}",
        )
        cv2.imshow(WINDOW, display)
        if cv2.waitKey(1) & 0xFF == ord("q"):
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
        settle_camera(capture)
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
