# GigaAM Voice Typer

[![Release](https://img.shields.io/github/v/release/Dioniska/gigaam-voice-typer)](https://github.com/Dioniska/gigaam-voice-typer/releases/latest)
[![License: MIT](https://img.shields.io/github/license/Dioniska/gigaam-voice-typer)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)

Offline Russian voice dictation for Windows. Hold a hotkey, speak, release — recognized text is pasted at the cursor in any application: browser, IDE, Word, Telegram, anywhere.

Speech recognition runs locally via [GigaAM v3](https://github.com/salute-developers/GigaAM) (ONNX) on ONNX Runtime with DirectML acceleration. The default variant is `gigaam-v3-e2e-rnnt`, which adds **automatic punctuation and text normalization**. You can switch models at runtime from the tray menu (v3 e2e-rnnt / v3 rnnt / v3 ctc / v2 rnnt). The loader auto-negotiates quantization (int8 → fp32) and provider (DirectML → CPU). No cloud, no telemetry, no internet required after the initial setup.

> Distributed as a portable folder with a one-click installer that handles Python, dependencies, and model download.

## Features

- Push-to-talk hotkey (`Ctrl+Win` by default), with race-safe combo handling
- Runtime model switching via the tray menu (GigaAM v3 e2e/rnnt/ctc + v2 fallback); loaded models are cached in RAM and the choice persists across restarts
- System-tray indicator: green (idle) / red pulsing with seconds counter (recording) / blue (processing)
- Audio cues for start, stop, success, and error
- Hardware-accelerated inference via DirectML on iGPU; transparent CPU fallback
- Clipboard-based paste with original clipboard content restoration
- Background-mode launcher (no console window) via `pythonw` + `.vbs`
- Optional autostart on Windows logon
- Structured UTF-8 log file with rotation-friendly format
- Self-respawn in UTF-8 mode to handle non-English Windows locales correctly

## Requirements

- Windows 10 or 11, x64
- ~5 GB free disk space (Python runtime + dependencies + model cache for all variants)
- A working microphone
- Internet connection during initial setup only (~1.5 GB total downloads for all models)

The installer provisions Python 3.12 via `winget` if it is not already present.

## Quick start

```
git clone https://github.com/Dioniska/gigaam-voice-typer
cd gigaam-voice-typer
setup.bat            # one-time install (5-15 min)
start_silent.vbs     # run in background
```

Then click into any text field, hold `Ctrl+Win`, speak, release. The recognized text is pasted at the cursor.

To launch automatically with Windows:

```
add_autostart.bat
```

## Usage

| Tray icon | Meaning |
|---|---|
| Green disc | Idle, waiting for hotkey |
| Pulsing red disc with number | Recording in progress; the number is elapsed seconds |
| Blue disc | Recognition and paste in progress |

Right-clicking the tray icon opens a menu with **Open log** and **Quit**.

## Scripts

| Script | Purpose |
|---|---|
| `setup.bat` / `setup.ps1` | First-time installation: provisions Python, creates a virtualenv, installs packages, downloads the models, performs a warm-up inference |
| `update.bat` / `update.ps1` | Update an existing install in place: upgrades `onnx-asr`/`onnxruntime`, downloads any new models, warms up. Falls back to full setup if no `.venv` exists |
| `start_silent.vbs` | Launch in background (recommended) |
| `start.bat` | Launch with a console window (for debugging) |
| `stop.bat` | Terminate the background process |
| `add_autostart.bat` / `remove_autostart.bat` | Manage Windows logon autostart via shortcut in `shell:startup` |
| `uninstall.bat` | Remove the virtualenv and optionally the model cache |
| `pack_for_share.bat` | Produce a clean ZIP archive (without `.venv`) for distribution |

## Configuration

Tunable constants are defined at the top of `voice_typer.py`:

| Constant | Default | Description |
|---|---|---|
| `SAMPLE_RATE` | `16000` | Microphone sampling rate (Hz). GigaAM expects 16 kHz mono |
| `MAX_SECONDS` | `600` | Absolute recording cap (10 min); longer audio is truncated |
| `CHUNK_SECONDS` | `90` | Long audio is split into ~this-long pieces (cut at pauses) and recognized sequentially, then joined. Avoids the DirectML self-attention overflow that crashes recognition on very long (~>200 s) single passes |
| `MIN_SECONDS` | `0.3` | Minimum audio length to trigger recognition |
| `MIN_HOLD_MS` | `150` | Minimum hotkey hold duration; shorter holds are ignored |
| `ADD_SPACE_BEFORE` | `True` | Prepend a space to pasted text — useful when appending mid-sentence |

The model list, provider choice (`USE_DIRECTML`) and the int8→fp32 / DirectML→CPU loader live in `asr.py` (`MODELS`, `build_providers()`, `load_asr()`). Edit `MODELS` there to add/remove/reorder the models shown in the tray menu; the first entry is the default. `warmup.py` and `voice_typer.py` both consume this list, so they never drift apart.

The hotkey is currently hardcoded to `Ctrl+Win`. To change it, edit the `CTRL_KEYS` and `WIN_KEYS` sets and the `both_down()` predicate in `voice_typer.py`.

## How it works

```
voice_typer.py
├── UTF-8 self-respawn         (-X utf8 to avoid cp1251 on non-English Windows)
├── keyboard.hook              (low-level hook, push-to-talk, race-safe)
├── sounddevice                (16 kHz mono float32 input stream)
├── asr.py + onnx-asr + onnxruntime-dml (GigaAM v3, int8→fp32, switchable)
├── pyperclip + simulated Ctrl+V (paste into the focused window)
└── pystray + Pillow           (tray icon with state-driven animation)
```

### Notable engineering details

- **Locale-safe startup.** Python on Russian Windows opens text files in cp1251 by default, which causes `onnx-asr` to fail when reading the model vocabulary. The script detects `sys.flags.utf8_mode == 0` and re-execs the interpreter with `-X utf8` before any I/O.
- **Race-safe combo release.** When the user releases `Ctrl+Win`, the keyboard hook fires two `keyup` events in quick succession (one per key). A naive implementation triggers recognition twice and crashes downstream. The fix flips the `recording` flag synchronously under a lock, then hands the audio buffer to a worker thread as arguments rather than via shared state, eliminating the race.
- **Modifier-clean paste.** Before sending the simulated `Ctrl+V`, every Ctrl/Win key variant is explicitly released via `keyboard.release(...)`. Otherwise, residual modifier state from the hotkey corrupts the paste.
- **DirectML provider with fallback.** The provider list is `[DmlExecutionProvider, CPUExecutionProvider]`. If session creation fails on DML (rare, but possible on very weak iGPUs), the script falls back to CPU-only without user intervention.

## Troubleshooting

| Symptom | Resolution |
|---|---|
| Hotkey is not detected | Run `start.bat` as administrator. Some applications running with elevated privileges intercept input from non-elevated processes. |
| Wrong microphone is used | Set the desired input device as the default in Windows Sound settings. The script uses the system default. |
| Application exits silently | Run `start.bat` instead of `start_silent.vbs` to see tracebacks; consult `voice_typer.log` (UTF-8). |
| `Окружение не найдено` after copying the folder from another PC | Run `setup.bat` again. It detects a `.venv` whose base interpreter does not exist on the local machine and recreates it. |
| Setup fails because `winget` is unavailable | Install Python 3.12 manually from https://www.python.org/downloads/, ensuring **Add Python to PATH** is checked, then re-run `setup.bat`. |

## Distributing to other machines

Do not copy the `.venv` directory between machines — it embeds an absolute path to the Python interpreter that produced it.

The clean way:
1. On the source machine, run `pack_for_share.bat`. This produces a `~15 KB` ZIP without `.venv`, logs, or caches.
2. On the target machine, extract the ZIP and run `setup.bat`.

If `.venv` is accidentally copied, `setup.bat` detects the broken environment via a `python.exe --version` probe and recreates it automatically.

## Project structure

```
gigaam-voice-typer/
├── voice_typer.py          # main script (recognition + tray + hotkey)
├── asr.py                  # shared model list + loader (int8→fp32, DML→CPU)
├── warmup.py               # download + warm up all configured models
├── setup.bat / setup.ps1   # installer
├── update.bat / update.ps1 # in-place updater for existing installs
├── start.bat               # foreground launcher
├── start_silent.vbs        # background launcher (pythonw)
├── stop.bat                # terminate background process
├── add_autostart.bat       # add Startup-folder shortcut
├── remove_autostart.bat    # remove Startup-folder shortcut
├── uninstall.bat           # remove venv (and optionally model cache)
├── pack_for_share.bat      # create clean ZIP for redistribution
├── README.md               # this file
├── README.txt              # end-user instructions in Russian
└── LICENSE                 # MIT
```

## Acknowledgements

- [GigaAM](https://github.com/salute-developers/GigaAM) by Sber — the speech recognition model
- [onnx-asr](https://github.com/istupakov/onnx-asr) by [@istupakov](https://github.com/istupakov) — the ONNX inference wrapper
- [istupakov/gigaam-v3-onnx](https://huggingface.co/istupakov/gigaam-v3-onnx) — the ONNX-converted weights used at runtime
- [ONNX Runtime](https://github.com/microsoft/onnxruntime) and DirectML by Microsoft

## License

Released under the [MIT License](LICENSE). Bundled third-party components retain their original licenses; see `LICENSE` for details.
