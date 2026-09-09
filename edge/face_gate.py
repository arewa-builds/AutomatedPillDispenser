"""MediaPipe face presence gate for pre-dispense patient presence checks."""

from __future__ import annotations

import logging
from dataclasses import dataclass

import cv2
import mediapipe as mp
import numpy as np

from config import FACE_MIN_CONFIDENCE, FACE_STABLE_FRAMES

logger = logging.getLogger(__name__)


@dataclass
class FaceGateResult:
    present: bool
    confidence: float
    stable: bool
    box: tuple[int, int, int, int] | None


class FaceGate:
    """Requires a face above confidence for FACE_STABLE_FRAMES consecutive frames."""

    def __init__(
        self,
        min_confidence: float = FACE_MIN_CONFIDENCE,
        stable_frames: int = FACE_STABLE_FRAMES,
    ) -> None:
        self.min_confidence = min_confidence
        self.stable_frames = stable_frames
        self._streak = 0
        self._detector = None
        self._haar_detector = None
        if hasattr(mp, "solutions"):
            self._detector = mp.solutions.face_detection.FaceDetection(
                model_selection=0,
                min_detection_confidence=min_confidence,
            )
        else:
            self._haar_detector = cv2.CascadeClassifier(
                cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            )
            if self._haar_detector.empty():
                logger.warning(
                    "MediaPipe legacy API and OpenCV Haar cascade are unavailable; "
                    "face detection is disabled"
                )
                self._haar_detector = None

    def reset(self) -> None:
        self._streak = 0

    def evaluate(self, frame_bgr: np.ndarray) -> FaceGateResult:
        if self._detector is None and self._haar_detector is None:
            return FaceGateResult(False, 0.0, False, None)
        if self._haar_detector is not None:
            return self._evaluate_haar(frame_bgr)
        try:
            rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
            output = self._detector.process(rgb)
        except Exception:
            logger.exception("Face detection failed on frame")
            self._streak = 0
            return FaceGateResult(False, 0.0, False, None)

        if not output.detections:
            self._streak = 0
            return FaceGateResult(False, 0.0, False, None)

        best = max(output.detections, key=lambda d: float(d.score[0]))
        confidence = float(best.score[0])
        if confidence < self.min_confidence:
            self._streak = 0
            return FaceGateResult(False, confidence, False, None)

        self._streak += 1
        h, w = frame_bgr.shape[:2]
        rel = best.location_data.relative_bounding_box
        box = (
            max(0, int(rel.xmin * w)),
            max(0, int(rel.ymin * h)),
            max(0, int(rel.width * w)),
            max(0, int(rel.height * h)),
        )
        stable = self._streak >= self.stable_frames
        return FaceGateResult(True, confidence, stable, box)

    def _evaluate_haar(self, frame_bgr: np.ndarray) -> FaceGateResult:
        gray = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY)
        faces = self._haar_detector.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5)
        if len(faces) == 0:
            self._streak = 0
            return FaceGateResult(False, 0.0, False, None)

        x, y, width, height = max(faces, key=lambda face: int(face[2]) * int(face[3]))
        self._streak += 1
        stable = self._streak >= self.stable_frames
        return FaceGateResult(True, 1.0, stable, (int(x), int(y), int(width), int(height)))

    def close(self) -> None:
        try:
            if self._detector is not None:
                self._detector.close()
        except Exception:
            logger.exception("Failed to close FaceDetection")
