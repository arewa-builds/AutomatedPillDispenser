"""OpenCV contour / color / size pill verification on the dispensing tray ROI."""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass

import cv2
import numpy as np

from config import (
    PILL_EXPECTED_COUNT,
    PILL_HSV_LOWER,
    PILL_HSV_UPPER,
    PILL_MAX_AREA,
    PILL_MIN_AREA,
    PILL_VERIFY_TIMEOUT_S,
)

logger = logging.getLogger(__name__)


@dataclass
class PillVerifyResult:
    count: int
    matched: bool
    latency_ms: int
    contours: list[tuple[int, int, int, int]]


class PillVerifier:
    """Counts blob-like objects in the lower tray ROI using HSV + contour filters."""

    def __init__(
        self,
        expected_count: int = PILL_EXPECTED_COUNT,
        hsv_lower: tuple[int, int, int] = PILL_HSV_LOWER,
        hsv_upper: tuple[int, int, int] = PILL_HSV_UPPER,
        min_area: int = PILL_MIN_AREA,
        max_area: int = PILL_MAX_AREA,
        timeout_s: float = PILL_VERIFY_TIMEOUT_S,
    ) -> None:
        self.expected_count = expected_count
        self.hsv_lower = np.array(hsv_lower, dtype=np.uint8)
        self.hsv_upper = np.array(hsv_upper, dtype=np.uint8)
        self.min_area = min_area
        self.max_area = max_area
        self.timeout_s = timeout_s

    @staticmethod
    def tray_roi(frame_bgr: np.ndarray) -> np.ndarray:
        """Use the lower-central portion of the frame as the tray view."""
        h, w = frame_bgr.shape[:2]
        y0, y1 = int(h * 0.45), int(h * 0.95)
        x0, x1 = int(w * 0.20), int(w * 0.80)
        return frame_bgr[y0:y1, x0:x1]

    def count_pills(self, frame_bgr: np.ndarray) -> PillVerifyResult:
        started = time.perf_counter()
        try:
            roi = self.tray_roi(frame_bgr)
            blur = cv2.GaussianBlur(roi, (5, 5), 0)
            hsv = cv2.cvtColor(blur, cv2.COLOR_BGR2HSV)
            mask = cv2.inRange(hsv, self.hsv_lower, self.hsv_upper)
            kernel = np.ones((3, 3), np.uint8)
            mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
            mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        except Exception:
            logger.exception("Pill contour analysis failed")
            return PillVerifyResult(0, False, 0, [])

        boxes: list[tuple[int, int, int, int]] = []
        for contour in contours:
            area = cv2.contourArea(contour)
            if area < self.min_area or area > self.max_area:
                continue
            x, y, bw, bh = cv2.boundingRect(contour)
            aspect = bw / float(bh) if bh else 0.0
            if aspect < 0.35 or aspect > 2.8:
                continue
            boxes.append((x, y, bw, bh))

        count = len(boxes)
        latency_ms = int((time.perf_counter() - started) * 1000)
        return PillVerifyResult(
            count=count,
            matched=count == self.expected_count,
            latency_ms=latency_ms,
            contours=boxes,
        )

    def wait_for_pill(
        self,
        capture: cv2.VideoCapture,
        expected_count: int | None = None,
    ) -> PillVerifyResult:
        """Poll the camera until expected count matches or timeout."""
        target = self.expected_count if expected_count is None else expected_count
        deadline = time.perf_counter() + self.timeout_s
        last = PillVerifyResult(0, False, 0, [])

        while time.perf_counter() < deadline:
            try:
                ok, frame = capture.read()
            except Exception:
                logger.exception("Camera read failed during pill verify")
                break
            if not ok or frame is None:
                logger.error("Empty camera frame during pill verify")
                break

            last = self.count_pills(frame)
            last.matched = last.count == target
            if last.matched:
                return last

            time.sleep(0.03)

        last.matched = last.count == target
        return last
