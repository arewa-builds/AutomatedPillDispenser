"""MediaPipe face presence gate for pre-dispense patient presence checks.

Uses MediaPipe Tasks FaceDetector (BlazeFace) by default. Falls back to the
legacy ``mp.solutions.face_detection`` API when available, then OpenCV Haar.
Works with MediaPipe 0.10.x and 1.x; does not require OpenCV Haar data files.
"""

from __future__ import annotations

import logging
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np

from config import FACE_MIN_CONFIDENCE, FACE_STABLE_FRAMES

logger = logging.getLogger(__name__)

MODEL_DIR = Path(__file__).resolve().parent / "models"
MODEL_PATH = MODEL_DIR / "blaze_face_short_range.tflite"
MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/face_detector/"
    "blaze_face_short_range/float16/1/blaze_face_short_range.tflite"
)


@dataclass
class FaceGateResult:
    present: bool
    confidence: float
    stable: bool
    box: tuple[int, int, int, int] | None


def ensure_face_model(path: Path = MODEL_PATH) -> Path:
    """Return local BlazeFace model path, downloading once if missing."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.stat().st_size > 0:
        return path
    logger.info("Downloading MediaPipe face model -> %s", path)
    try:
        urllib.request.urlretrieve(MODEL_URL, path)
    except Exception:
        logger.exception("Failed to download face model from %s", MODEL_URL)
        raise
    if not path.exists() or path.stat().st_size == 0:
        raise FileNotFoundError(f"Face model missing after download: {path}")
    return path


class FaceGate:
    """Requires a face above confidence for FACE_STABLE_FRAMES consecutive frames."""

    def __init__(
        self,
        min_confidence: float = FACE_MIN_CONFIDENCE,
        stable_frames: int = FACE_STABLE_FRAMES,
        model_path: Path | None = None,
    ) -> None:
        self.min_confidence = min_confidence
        self.stable_frames = stable_frames
        self._streak = 0
        self._backend = "none"
        self._detector = None
        self._haar = None
        self._timestamp_ms = 0
        self._model_path = model_path or MODEL_PATH

        if self._init_tasks():
            return
        if self._init_solutions():
            return
        if self._init_haar():
            return
        raise RuntimeError(
            "No face detector available. Install mediapipe>=0.10.14 with the "
            "bundled BlazeFace model under edge/models/, or use OpenCV 4.x "
            "with Haar cascades. OpenCV 5 does not ship Haar face models."
        )

    def _init_tasks(self) -> bool:
        try:
            from mediapipe.tasks import python as mp_python
            from mediapipe.tasks.python import vision
        except Exception:
            logger.info("MediaPipe Tasks API not available; trying legacy solutions")
            return False

        try:
            model = ensure_face_model(self._model_path)
            base_options = mp_python.BaseOptions(model_asset_path=str(model))
            options = vision.FaceDetectorOptions(
                base_options=base_options,
                running_mode=vision.RunningMode.VIDEO,
                min_detection_confidence=self.min_confidence,
            )
            self._detector = vision.FaceDetector.create_from_options(options)
            self._backend = "tasks"
            logger.info("FaceGate backend: MediaPipe Tasks (%s)", model.name)
            return True
        except Exception:
            logger.exception("Failed to init MediaPipe Tasks FaceDetector")
            self._detector = None
            return False

    def _init_solutions(self) -> bool:
        try:
            solutions = getattr(mp, "solutions", None)
            if solutions is None or not hasattr(solutions, "face_detection"):
                return False
            self._detector = solutions.face_detection.FaceDetection(
                model_selection=0,
                min_detection_confidence=self.min_confidence,
            )
            self._backend = "solutions"
            logger.info("FaceGate backend: MediaPipe solutions (legacy)")
            return True
        except Exception:
            logger.exception("Failed to init MediaPipe solutions FaceDetection")
            self._detector = None
            return False

    def _init_haar(self) -> bool:
        # OpenCV 4 ships cascades; OpenCV 5 typically does not.
        try:
            haar_dir = getattr(getattr(cv2, "data", None), "haarcascades", None)
            if not haar_dir:
                return False
            cascade_path = Path(haar_dir) / "haarcascade_frontalface_default.xml"
            if not cascade_path.exists():
                logger.warning("Haar cascade file missing at %s", cascade_path)
                return False
            self._haar = cv2.CascadeClassifier(str(cascade_path))
            if self._haar.empty():
                return False
            self._backend = "haar"
            logger.info("FaceGate backend: OpenCV Haar (%s)", cascade_path.name)
            return True
        except Exception:
            logger.exception("Failed to init OpenCV Haar face detector")
            self._haar = None
            return False

    def reset(self) -> None:
        self._streak = 0

    def evaluate(self, frame_bgr: np.ndarray) -> FaceGateResult:
        try:
            if self._backend == "tasks":
                return self._evaluate_tasks(frame_bgr)
            if self._backend == "solutions":
                return self._evaluate_solutions(frame_bgr)
            if self._backend == "haar":
                return self._evaluate_haar(frame_bgr)
        except Exception:
            logger.exception("Face detection failed on frame (backend=%s)", self._backend)
            self._streak = 0
            return FaceGateResult(False, 0.0, False, None)
        self._streak = 0
        return FaceGateResult(False, 0.0, False, None)

    def _finish(self, confidence: float, box: tuple[int, int, int, int] | None) -> FaceGateResult:
        if box is None or confidence < self.min_confidence:
            self._streak = 0
            return FaceGateResult(False, confidence, False, box)
        self._streak += 1
        stable = self._streak >= self.stable_frames
        return FaceGateResult(True, confidence, stable, box)

    def _evaluate_tasks(self, frame_bgr: np.ndarray) -> FaceGateResult:
        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        # MediaPipe Image expects contiguous uint8 RGB
        rgb = np.ascontiguousarray(rgb)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        self._timestamp_ms += 33  # ~30 FPS monotonic stream clock
        result = self._detector.detect_for_video(mp_image, self._timestamp_ms)
        if not result.detections:
            self._streak = 0
            return FaceGateResult(False, 0.0, False, None)

        best = max(
            result.detections,
            key=lambda d: float(d.categories[0].score) if d.categories else 0.0,
        )
        confidence = float(best.categories[0].score) if best.categories else 0.0
        bb = best.bounding_box
        box = (
            max(0, int(bb.origin_x)),
            max(0, int(bb.origin_y)),
            max(0, int(bb.width)),
            max(0, int(bb.height)),
        )
        return self._finish(confidence, box)

    def _evaluate_solutions(self, frame_bgr: np.ndarray) -> FaceGateResult:
        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        output = self._detector.process(rgb)
        if not output.detections:
            self._streak = 0
            return FaceGateResult(False, 0.0, False, None)

        best = max(output.detections, key=lambda d: float(d.score[0]))
        confidence = float(best.score[0])
        h, w = frame_bgr.shape[:2]
        rel = best.location_data.relative_bounding_box
        box = (
            max(0, int(rel.xmin * w)),
            max(0, int(rel.ymin * h)),
            max(0, int(rel.width * w)),
            max(0, int(rel.height * h)),
        )
        return self._finish(confidence, box)

    def _evaluate_haar(self, frame_bgr: np.ndarray) -> FaceGateResult:
        gray = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY)
        faces = self._haar.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60))
        if faces is None or len(faces) == 0:
            self._streak = 0
            return FaceGateResult(False, 0.0, False, None)
        x, y, w, h = max(faces, key=lambda f: int(f[2]) * int(f[3]))
        # Haar has no score; treat larger faces as higher confidence proxy
        confidence = min(0.99, 0.70 + (w * h) / float(frame_bgr.shape[0] * frame_bgr.shape[1]))
        return self._finish(float(confidence), (int(x), int(y), int(w), int(h)))

    def close(self) -> None:
        try:
            if self._detector is not None and hasattr(self._detector, "close"):
                self._detector.close()
        except Exception:
            logger.exception("Failed to close face detector")
        self._detector = None
        self._haar = None
