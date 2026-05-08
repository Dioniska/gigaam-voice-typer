# GigaAM Voice Typer

Offline Russian voice dictation for Windows. Hold a hotkey, speak, release — recognized text is pasted at the cursor in any application: browser, IDE, Word, Telegram, anywhere.

Speech recognition runs locally via the [GigaAM v2](https://github.com/salute-developers/GigaAM) RNNT model (int8-quantized ONNX) on ONNX Runtime with DirectML acceleration. Works on AMD/Intel integrated graphics and falls back to CPU automatically. No cloud, no telemetry, no internet required after the initial setup.

> Distributed as a portable folder with a one-click installer that handles Python, dependencies, and model download.

## Features

- Push-to-talk hotkey (`Ctrl+Win` by default), with race-safe combo handling
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
- ~3 GB free disk space (Python runtime + dependencies + model cache)
- A working microphone
- Internet connection during initial setup only (~700 MB total downloads)

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
| `setup.bat` / `setup.ps1` | First-time installation: provisions Python, creates a virtualenv, installs packages, downloads the model, performs a warm-up inference |
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
| `MAX_SECONDS` | `60` | Maximum recording length; longer audio is truncated |
| `MIN_SECONDS` | `0.3` | Minimum audio length to trigger recognition |
| `MIN_HOLD_MS` | `150` | Minimum hotkey hold duration; shorter holds are ignored |
| `USE_DIRECTML` | `True` | Enable DirectML provider (with CPU fallback) |
| `ADD_SPACE_BEFORE` | `True` | Prepend a space to pasted text — useful when appending mid-sentence |

The hotkey is currently hardcoded to `Ctrl+Win`. To change it, edit the `CTRL_KEYS` and `WIN_KEYS` sets and the `both_down()` predicate in `voice_typer.py`.

## How it works

```
voice_typer.py
├── UTF-8 self-respawn         (-X utf8 to avoid cp1251 on non-English Windows)
├── keyboard.hook              (low-level hook, push-to-talk, race-safe)
├── sounddevice                (16 kHz mono float32 input stream)
├── onnx-asr + onnxruntime-dml (GigaAM v2 RNNT int8)
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
├── setup.bat / setup.ps1   # installer
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
- [istupakov/gigaam-v2-onnx](https://huggingface.co/istupakov/gigaam-v2-onnx) — the ONNX-converted weights used at runtime
- [ONNX Runtime](https://github.com/microsoft/onnxruntime) and DirectML by Microsoft

## License

Released under the [MIT License](LICENSE). Bundled third-party components retain their original licenses; see `LICENSE` for details.
