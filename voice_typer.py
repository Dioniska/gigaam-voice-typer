"""GigaAM v2 Voice Typer для Windows — push-to-talk + tray icon.

Зажми Ctrl+Win  -> запись с микрофона
Отпусти          -> распознавание + вставка в активное поле

Распознавание: GigaAM v2 RNNT int8 (ONNX) с DirectML на iGPU/CPU.
"""

import os
import sys

# Принудительно запускаем интерпретатор в UTF-8 режиме - иначе onnx-asr падает
# на cp1251 при чтении словаря модели на Windows с не-английской локалью.
if not sys.flags.utf8_mode:
    os.environ["PYTHONUTF8"] = "1"
    os.execv(sys.executable, [sys.executable, "-X", "utf8", *sys.argv])

os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

import time
import math
import threading
import traceback
import winsound
import numpy as np
import sounddevice as sd
import keyboard
import pyperclip
import onnx_asr
import pystray
from PIL import Image, ImageDraw, ImageFont

# === Лог в файл ===
LOG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "voice_typer.log")
_log_lock = threading.Lock()

def log(msg):
    line = time.strftime("[%Y-%m-%d %H:%M:%S] ") + str(msg)
    with _log_lock:
        try:
            print(line, flush=True)
        except Exception:
            pass
        try:
            with open(LOG_PATH, "a", encoding="utf-8") as f:
                f.write(line + "\n")
        except Exception:
            pass

def _excepthook(exc_type, exc, tb):
    log("UNCAUGHT EXCEPTION:\n" + "".join(traceback.format_exception(exc_type, exc, tb)))

sys.excepthook = _excepthook

# === НАСТРОЙКИ ===
SAMPLE_RATE      = 16000
MAX_SECONDS      = 60
MIN_SECONDS      = 0.3
MIN_HOLD_MS      = 150
USE_DIRECTML     = True
ADD_SPACE_BEFORE = True
# ==================

CTRL_KEYS = {"ctrl", "left ctrl", "right ctrl"}
WIN_KEYS  = {"windows", "left windows", "right windows"}

log("Загружаю GigaAM v2 RNNT int8...")
providers = ["DmlExecutionProvider", "CPUExecutionProvider"] if USE_DIRECTML else ["CPUExecutionProvider"]
try:
    model = onnx_asr.load_model("gigaam-v2-rnnt", quantization="int8", providers=providers)
    log(f"провайдер: {providers[0]}")
except Exception as e:
    log(f"DirectML не сработал ({e}); откатываюсь на CPU")
    model = onnx_asr.load_model("gigaam-v2-rnnt", quantization="int8", providers=["CPUExecutionProvider"])

log("Прогрев модели...")
_ = model.recognize(np.zeros(SAMPLE_RATE, dtype=np.float32))
log("Готов. Зажми Ctrl+Win, говори, отпусти. Выход — через меню в трее.")

# === Иконки трея ===
ICON_SIZE = 64

def _get_font(size):
    for path in (r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()

FONT_BIG   = _get_font(38)
FONT_SMALL = _get_font(28)

def make_static_circle(rgb, size=ICON_SIZE):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 4
    d.ellipse((pad, pad, size - pad, size - pad), fill=rgb + (255,), outline=(30, 30, 30, 255), width=2)
    return img

def render_rec_icon(seconds, pulse_phase, size=ICON_SIZE):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    scale = 0.88 + 0.12 * pulse_phase
    pad = int((1 - scale) * size / 2) + 2
    alpha = int(220 + 35 * pulse_phase)
    d.ellipse(
        (pad, pad, size - pad, size - pad),
        fill=(231, 76, 60, alpha),
        outline=(80, 10, 10, 255),
        width=2,
    )
    secs = max(0, int(seconds))
    text = str(min(secs, 99))
    font = FONT_BIG if len(text) == 1 else FONT_SMALL
    d.text(
        (size / 2, size / 2 + 1),
        text,
        font=font,
        fill=(255, 255, 255, 255),
        anchor="mm",
        stroke_width=2,
        stroke_fill=(60, 0, 0, 255),
    )
    return img

ICON_IDLE = make_static_circle((46, 204, 113))
ICON_PROC = make_static_circle((52, 152, 219))

tray_icon = None
_anim_stop = threading.Event()

def set_state(mode):
    state["mode"] = mode
    if tray_icon is None:
        return
    if mode == "idle":
        try:
            tray_icon.icon = ICON_IDLE
            tray_icon.title = "GigaAM Voice Typer — ожидание"
        except Exception:
            pass
    elif mode == "proc":
        try:
            tray_icon.icon = ICON_PROC
            tray_icon.title = "GigaAM Voice Typer — распознавание..."
        except Exception:
            pass

def animation_loop():
    while not _anim_stop.is_set():
        if state.get("mode") == "rec":
            elapsed = time.time() - state.get("press_t", time.time())
            phase = (math.sin(time.time() * 5.0) + 1.0) / 2.0
            try:
                tray_icon.icon = render_rec_icon(elapsed, phase)
                tray_icon.title = f"Запись... {elapsed:.1f} с"
            except Exception:
                pass
            time.sleep(0.08)
        else:
            time.sleep(0.15)


state = {
    "ctrl_down": False,
    "win_down":  False,
    "recording": False,
    "buffer":    [],
    "stream":    None,
    "press_t":   0.0,
    "mode":      "idle",
    "lock":      threading.Lock(),
}

def beep(freq, dur=70):
    try:
        winsound.Beep(freq, dur)
    except Exception:
        pass

def audio_cb(indata, frames, time_info, status):
    state["buffer"].append(indata[:, 0].copy())

def start_recording():
    state["buffer"] = []
    state["press_t"] = time.time()
    state["stream"] = sd.InputStream(
        samplerate=SAMPLE_RATE, channels=1, dtype="float32",
        callback=audio_cb, blocksize=1600,
    )
    state["stream"].start()
    beep(900, 60)
    set_state("rec")
    log("REC старт")

def process_recording(stream, buffer, press_t):
    duration = time.time() - press_t
    try:
        stream.stop()
        stream.close()
    except Exception:
        pass
    beep(600, 60)

    if duration * 1000 < MIN_HOLD_MS:
        log(f"короткое нажатие ({duration*1000:.0f} ms) - пропуск")
        set_state("idle")
        return
    if duration < MIN_SECONDS or not buffer:
        log(f"слишком коротко ({duration:.2f}s) - пропуск")
        set_state("idle")
        return

    set_state("proc")

    audio = np.concatenate(buffer).astype(np.float32)
    if len(audio) > SAMPLE_RATE * MAX_SECONDS:
        audio = audio[: SAMPLE_RATE * MAX_SECONDS]

    log(f"распознаю {len(audio)/SAMPLE_RATE:.2f}s...")
    t0 = time.time()
    try:
        text = model.recognize(audio)
    except Exception as e:
        log(f"ошибка распознавания: {e}")
        traceback.print_exc()
        beep(300, 200)
        set_state("idle")
        return
    text = (text or "").strip()
    rt = time.time() - t0
    log(f"за {rt:.2f}s -> {text!r}")

    if not text:
        beep(300, 150)
        set_state("idle")
        return

    if ADD_SPACE_BEFORE:
        text = " " + text

    try:
        paste_text(text)
        beep(1200, 50)
    except Exception as e:
        log(f"ошибка вставки: {e}")
        traceback.print_exc()
        beep(300, 200)
    finally:
        set_state("idle")

def paste_text(text):
    try:
        prev = pyperclip.paste()
    except Exception:
        prev = None

    for k in ("ctrl", "left ctrl", "right ctrl", "windows", "left windows", "right windows"):
        try:
            keyboard.release(k)
        except Exception:
            pass
    time.sleep(0.05)

    pyperclip.copy(text)
    time.sleep(0.05)
    keyboard.send("ctrl+v")

    def restore_clipboard():
        time.sleep(1.5)
        if prev is not None:
            try:
                pyperclip.copy(prev)
            except Exception:
                pass
    threading.Thread(target=restore_clipboard, daemon=True).start()

def both_down():
    return state["ctrl_down"] and state["win_down"]

def on_key_event(e):
    try:
        n = (e.name or "").lower()
        is_ctrl = n in CTRL_KEYS
        is_win  = n in WIN_KEYS
        if not (is_ctrl or is_win):
            return

        pressed = (e.event_type == "down")
        if is_ctrl:
            state["ctrl_down"] = pressed
        elif is_win:
            state["win_down"]  = pressed

        with state["lock"]:
            should = both_down()
            if should and not state["recording"]:
                state["recording"] = True
                try:
                    start_recording()
                except Exception as ex:
                    state["recording"] = False
                    log(f"не могу открыть микрофон: {ex}")
                    beep(300, 250)
            elif not should and state["recording"]:
                state["recording"] = False
                stream  = state["stream"]
                buffer  = state["buffer"]
                press_t = state["press_t"]
                state["stream"] = None
                state["buffer"] = []
                threading.Thread(
                    target=process_recording,
                    args=(stream, buffer, press_t),
                    daemon=True,
                ).start()
    except Exception as ex:
        log(f"ошибка в обработчике клавиш: {ex}")
        traceback.print_exc()

keyboard.hook(on_key_event)

# === Системный трей ===
def on_quit(icon, item):
    log("выход через меню трея")
    _anim_stop.set()
    if state["recording"] and state["stream"] is not None:
        try:
            state["stream"].stop()
            state["stream"].close()
        except Exception:
            pass
    icon.stop()

def on_open_log(icon, item):
    try:
        os.startfile(LOG_PATH)
    except Exception as e:
        log(f"не могу открыть лог: {e}")

menu = pystray.Menu(
    pystray.MenuItem("GigaAM Voice Typer", None, enabled=False),
    pystray.MenuItem("Открыть лог", on_open_log),
    pystray.Menu.SEPARATOR,
    pystray.MenuItem("Выход", on_quit),
)

tray_icon = pystray.Icon(
    name="gigaam-voice-typer",
    icon=ICON_IDLE,
    title="GigaAM Voice Typer — ожидание",
    menu=menu,
)

threading.Thread(target=animation_loop, daemon=True).start()

try:
    tray_icon.run()
except KeyboardInterrupt:
    pass
finally:
    if state["recording"] and state["stream"] is not None:
        try:
            state["stream"].stop()
            state["stream"].close()
        except Exception:
            pass
    log("выключен")
