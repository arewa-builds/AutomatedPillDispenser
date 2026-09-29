"""Tray counting: a second pill is a new one, not a return to a count of 1."""

from __future__ import annotations

import numpy as np

from pill_verify import PillVerifier, dose_landed, latest_frame


def _blob(width: int, height: int, centers: list[tuple[int, int]]) -> np.ndarray:
    frame = np.zeros((height, width, 3), dtype=np.uint8)
    for cx, cy in centers:
        frame[cy - 12 : cy + 12, cx - 12 : cx + 12] = (0, 0, 220)
    return frame


def test_dose_landed_counts_the_new_pill() -> None:
    assert dose_landed(1, 0) is True
    assert dose_landed(1, 1) is False
    assert dose_landed(2, 1) is True
    assert dose_landed(3, 1) is True


def test_count_pills_sees_each_blob() -> None:
    verifier = PillVerifier()
    assert verifier.count_pills(_blob(200, 160, [])).count == 0
    assert verifier.count_pills(_blob(200, 160, [(60, 80)])).count == 1
    assert verifier.count_pills(_blob(200, 160, [(40, 80), (140, 80)])).count == 2


class _Frames:
    def __init__(self, frames: list[np.ndarray]) -> None:
        self._frames = list(frames)

    def read(self):
        if not self._frames:
            return False, None
        return True, self._frames.pop(0)


def test_wait_accepts_the_second_pill_past_the_baseline() -> None:
    verifier = PillVerifier(timeout_s=1.0)
    one = _blob(200, 160, [(60, 80)])
    two = _blob(200, 160, [(40, 80), (140, 80)])
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
    one = _blob(200, 160, [(60, 80)])
    result = verifier.wait_for_pill(_Frames([one, one, one]), baseline=1)
    assert result.matched is False
    assert result.count == 1


def test_latest_frame_returns_the_newest() -> None:
    frames = [_blob(200, 160, []), _blob(200, 160, [(60, 80)])]
    ok, frame = latest_frame(_Frames(frames), discard=2)
    assert ok
    assert PillVerifier().count_pills(frame).count == 1


if __name__ == "__main__":
    test_dose_landed_counts_the_new_pill()
    test_count_pills_sees_each_blob()
    test_wait_accepts_the_second_pill_past_the_baseline()
    test_wait_times_out_when_nothing_new_lands()
    test_latest_frame_returns_the_newest()
    print("ok")
