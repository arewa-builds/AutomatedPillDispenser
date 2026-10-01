"""Tray counting: a second pill is a new one, not a return to a count of 1."""

from __future__ import annotations

import numpy as np

from pill_verify import PillVerifier, dose_landed, latest_frame


def _inside_tray(width: int = 640, height: int = 480) -> tuple[int, int]:
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    x0, y0, x1, y1 = PillVerifier.roi_bounds(frame)
    return (x0 + x1) // 2, (y0 + y1) // 2


def _blob(
    width: int,
    height: int,
    centers: list[tuple[int, int]],
    color: tuple[int, int, int] = (0, 0, 220),
) -> np.ndarray:
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    for cx, cy in centers:
        frame[cy - 12 : cy + 12, cx - 12 : cx + 12] = color
    return frame


def test_dose_landed_counts_the_new_pill() -> None:
    assert dose_landed(1, 0) is True
    assert dose_landed(1, 1) is False
    assert dose_landed(2, 1) is True
    assert dose_landed(3, 1) is True


def test_count_pills_sees_each_blob() -> None:
    verifier = PillVerifier()
    cx, cy = _inside_tray()
    assert verifier.count_pills(_blob(640, 480, [])).count == 0
    assert verifier.count_pills(_blob(640, 480, [(cx, cy)])).count == 1
    assert verifier.count_pills(_blob(640, 480, [(cx - 18, cy), (cx + 18, cy)])).count == 2


def test_white_capsule_counts_and_the_gray_tray_does_not() -> None:
    verifier = PillVerifier()
    cx, cy = _inside_tray()
    gray = np.full((480, 640, 3), 160, dtype=np.uint8)
    assert verifier.count_pills(gray).count == 0
    white = gray.copy()
    white[cy - 12 : cy + 12, cx - 12 : cx + 12] = (255, 255, 255)
    assert verifier.count_pills(white).count == 1


class _Frames:
    def __init__(self, frames: list[np.ndarray]) -> None:
        self._frames = list(frames)

    def read(self):
        if not self._frames:
            return False, None
        return True, self._frames.pop(0)


def test_wait_accepts_the_second_pill_past_the_baseline() -> None:
    verifier = PillVerifier(timeout_s=1.0)
    cx, cy = _inside_tray()
    one = _blob(640, 480, [(cx, cy)])
    two = _blob(640, 480, [(cx - 18, cy), (cx + 18, cy)])
    seen: list[int] = []
    result = verifier.wait_for_pill(
        _Frames([one, one, two]),
        baseline=1,
        on_frame=lambda _frame, result: seen.append(result.count),
    )
    assert result.matched
    assert result.count == 2
    assert seen == [1, 2]


def test_wait_times_out_when_nothing_new_lands() -> None:
    verifier = PillVerifier(timeout_s=0.05)
    cx, cy = _inside_tray()
    one = _blob(640, 480, [(cx, cy)])
    result = verifier.wait_for_pill(_Frames([one, one, one]), baseline=1)
    assert result.matched is False
    assert result.count == 1


def test_latest_frame_returns_the_newest() -> None:
    cx, cy = _inside_tray()
    frames = [_blob(640, 480, []), _blob(640, 480, [(cx, cy)])]
    ok, frame = latest_frame(_Frames(frames), discard=2)
    assert ok
    assert PillVerifier().count_pills(frame).count == 1


if __name__ == "__main__":
    test_dose_landed_counts_the_new_pill()
    test_count_pills_sees_each_blob()
    test_white_capsule_counts_and_the_gray_tray_does_not()
    test_wait_accepts_the_second_pill_past_the_baseline()
    test_wait_times_out_when_nothing_new_lands()
    test_latest_frame_returns_the_newest()
    print("ok")
