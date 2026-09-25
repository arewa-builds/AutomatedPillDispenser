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
    PILL_ROI_FRAC,
    PILL_VERIFY_TIMEOUT_S,
)

logger = logging.getLogger(__name__)


@dataclass
class PillVerifyResult:
    count: int
    matched: bool
    latency_ms: int
    contours: list[tuple[int, int, int, int]]
    baseline: int = 0
    target: int = 0


class PillVerifier:
    """Counts blob-like objects in the tray ROI using HSV + contour filters.

    Verification is delta-based: count the tray *before* a dispense, then wait
    until the count has risen by ``expected_count``. That way a leftover tablet
    from the previous cycle cannot fake a success, and two tablets in the tray
    do not fail a check that still expected an absolute count of one.
    """

    def __init__(
        self,
        expected_count: int = PILL_EXPECTED_COUNT,
        hsv_lower: tuple[int, int, int] = PILL_HSV_LOWER,
        hsv_upper: tuple[int, int, int] = PILL_HSV_UPPER,
        min_area: int = PILL_MIN_AREA,
        max_area: int = PILL_MAX_AREA,
        timeout_s: float = PILL_VERIFY_TIMEOUT_S,
        roi_frac: tuple[float, float, float, float] = PILL_ROI_FRAC,
    ) -> None:
        self.expected_count = expected_count
        self.hsv_lower = np.array(hsv_lower, dtype=np.uint8)
        self.hsv_upper = np.array(hsv_upper, dtype=np.uint8)
        self.min_area = min_area
        self.max_area = max_area
        self.timeout_s = timeout_s
        self.roi_frac = roi_frac

    def tray_roi(self, frame_bgr: np.ndarray) -> np.ndarray:
        """Crop the configured tray window out of the frame."""
        h, w = frame_bgr.shape[:2]
        x0f, y0f, x1f, y1f = self.roi_frac
        y0, y1 = int(h * y0f), int(h * y1f)
        x0, x1 = int(w * x0f), int(w * x1f)
        return frame_bgr[y0:y1, x0:x1]

    def roi_rect(self, frame_bgr: np.ndarray) -> tuple[int, int, int, int]:
        """Pixel rectangle of the tray ROI, for drawing the overlay."""
        h, w = frame_bgr.shape[:2]
        x0f, y0f, x1f, y1f = self.roi_frac
        return int(w * x0f), int(h * y0f), int(w * x1f), int(h * y1f)

    def count_pills(self, frame_bgr: np.ndarray) -> PillVerifyResult:
        started = time.perf_counter()
        try:
            roi = self.tray_roi(frame_bgr)
            blur = cv2.GaussianBlur(roi, (5, 5), 0)
            hsv = cv2.cvtColor(blur, cv2.COLOR_BGR2HSV)
            mask = cv2.inRange(hsv, self.hsv_lower, self.hsv_upper)
            kernel = np.ones((3, 3), dtype=np.uint8)
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
            matched=False,
            latency_ms=latency_ms,
            contours=boxes,
        )

    def baseline(self, capture: cv2.VideoCapture, samples: int = 5) -> int:
        """Median pill count over a few frames, taken before DISPENSE is sent."""
        counts: list[int] = []
        for _ in range(samples):
            try:
                ok, frame = capture.read()
            except Exception:
                logger.exception("Camera read failed during pill baseline")
                break
            if not ok or frame is None:
                logger.error("Empty camera frame during pill baseline")
                break
            counts.append(self.count_pills(frame).count)
            time.sleep(0.03)
        if not counts:
            return 0
        counts.sort()
        mid = counts[len(counts) // 2]
        logger.info("Pill baseline count=%s (samples=%s)", mid, counts)
        return mid

    def wait_for_pill(
        self,
        capture: cv2.VideoCapture,
        baseline: int = 0,
        expected_count: int | None = None,
    ) -> PillVerifyResult:
        """Poll until the tray count rises by ``expected_count`` above baseline."""
        delta = self.expected_count if expected_count is None else expected_count
        target = baseline + delta
        deadline = time.perf_counter() + self.timeout_s
        last = PillVerifyResult(0, False, 0, [], baseline=baseline, target=target)

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
            last.baseline = baseline
            last.target = target
            last.matched = last.count >= target
            if last.matched:
                return last

            time.sleep(0.03)

        last.matched = last.count >= target
        return last
