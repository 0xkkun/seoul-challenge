#!/usr/bin/env python3
import math
import struct
import sys
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BGM_DIR = ROOT / "assets" / "audio" / "bgm"
MIN_PEAK_DBFS = -2.0
MAX_PEAK_DBFS = -0.1
MIN_RMS_DBFS = -15.0


def _dbfs(value: float) -> float:
    if value <= 0.0:
        return float("-inf")
    return 20.0 * math.log10(value / 32768.0)


def _measure_wav(path: Path) -> tuple[int, int, float, float]:
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        sample_width = wav.getsampwidth()
        frame_count = wav.getnframes()
        sample_rate = wav.getframerate()
        frames = wav.readframes(frame_count)

    if sample_width != 2:
        raise ValueError(f"{path}: expected 16-bit PCM, got {sample_width * 8}-bit")
    if frame_count == 0:
        raise ValueError(f"{path}: empty WAV")

    sample_count = len(frames) // sample_width
    samples = struct.unpack("<%dh" % sample_count, frames)
    peak = max(abs(sample) for sample in samples)
    rms = math.sqrt(sum(sample * sample for sample in samples) / sample_count)
    return channels, sample_rate, _dbfs(float(peak)), _dbfs(rms)


def main() -> int:
    failures: list[str] = []
    bgm_files = sorted(BGM_DIR.glob("*.wav"))
    if not bgm_files:
        failures.append(f"No BGM WAV files found under {BGM_DIR.relative_to(ROOT)}")

    for path in bgm_files:
        try:
            channels, sample_rate, peak_dbfs, rms_dbfs = _measure_wav(path)
        except ValueError as exc:
            failures.append(str(exc))
            continue

        rel_path = path.relative_to(ROOT)
        print(
            f"[verify_audio_levels] {rel_path}: "
            f"{channels}ch {sample_rate}Hz peak={peak_dbfs:.2f}dBFS rms={rms_dbfs:.2f}dBFS"
        )
        if peak_dbfs < MIN_PEAK_DBFS:
            failures.append(f"{rel_path}: peak {peak_dbfs:.2f}dBFS is below {MIN_PEAK_DBFS:.1f}dBFS")
        if peak_dbfs > MAX_PEAK_DBFS:
            failures.append(f"{rel_path}: peak {peak_dbfs:.2f}dBFS is above {MAX_PEAK_DBFS:.1f}dBFS")
        if rms_dbfs < MIN_RMS_DBFS:
            failures.append(f"{rel_path}: RMS {rms_dbfs:.2f}dBFS is below {MIN_RMS_DBFS:.1f}dBFS")

    if failures:
        for failure in failures:
            print(f"[verify_audio_levels] FAIL: {failure}", file=sys.stderr)
        return 1

    print("[verify_audio_levels] OK: BGM levels are normalized for mobile playback")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
