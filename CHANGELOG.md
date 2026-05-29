# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-05-29

### Added
- Runtime model switching from the tray menu (**v3 e2e-rnnt / v3 rnnt / v3 ctc / v2 rnnt**). Loaded models are cached in RAM and the choice persists across restarts.
- `asr.py` — shared model list and loader with automatic `int8 → fp32` and `DirectML → CPU` fallback.
- `warmup.py` — downloads and warms up all configured models (used by setup and update).
- `update.bat` / `update.ps1` — in-place updater: stops the old instance, upgrades packages, downloads models, re-points the autostart shortcut to the new folder, and restarts.
- Long-form dictation: long audio is split at pauses into ~90 s chunks and stitched back together.
- `UPDATE.txt` — short update/install reference bundled in the share archive.

### Changed
- Default model upgraded to **GigaAM v3** (`gigaam-v3-e2e-rnnt`) with built-in punctuation and number normalization.
- Recording cap raised from 60 s to 10 minutes (`MAX_SECONDS`).
- `setup.ps1` now installs packages with `--upgrade` and warms all models via `warmup.py`.
- README (RU/EN) updated; the share archive now excludes `.git` and `*.log`.

### Fixed
- Tray timer no longer freezes at 99 s — it shows the real elapsed seconds with adaptive font sizing.
- Avoided the recognition crash on very long single passes (DirectML self-attention overflow at ~>200 s) by chunking long audio.

### Notes
- GigaAM v2 (`gigaam-v2-rnnt`) is retained as a selectable fallback model.

## [1.0.0] - 2026-05-09

### Added
- Initial release: offline Russian push-to-talk dictation for Windows.
- GigaAM v2 RNNT (int8 ONNX) via [onnx-asr](https://github.com/istupakov/onnx-asr) + ONNX Runtime / DirectML with automatic CPU fallback.
- System-tray indicator (idle / recording with seconds / processing), audio cues, clipboard paste with restore, background launcher, optional autostart, and a one-click installer.

[1.1.0]: https://github.com/Dioniska/gigaam-voice-typer/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Dioniska/gigaam-voice-typer/releases/tag/v1.0.0
