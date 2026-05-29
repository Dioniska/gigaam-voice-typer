"""Общий конфиг моделей и загрузчик для GigaAM Voice Typer.

Используется и рантаймом (voice_typer.py), и прогревом (warmup.py),
чтобы список моделей и логика загрузки не разъезжались.
"""

import os

# === Модели для переключателя в трее ===
# (подпись в меню, имя модели для onnx-asr)
# Порядок = порядок в меню. Первая — модель по умолчанию.
MODELS = [
    ("v3 · пунктуация (e2e-rnnt)", "gigaam-v3-e2e-rnnt"),
    ("v3 · rnnt",                  "gigaam-v3-rnnt"),
    ("v3 · ctc (быстрая)",         "gigaam-v3-ctc"),
    ("v2 · rnnt (старая)",         "gigaam-v2-rnnt"),
]
DEFAULT_MODEL = MODELS[0][1]

# Провайдер инференса. DirectML (iGPU) с откатом на CPU.
USE_DIRECTML = True

_CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model_config.txt")


def model_names():
    return [name for _, name in MODELS]


def label_for(name):
    for label, n in MODELS:
        if n == name:
            return label
    return name


def build_providers():
    if USE_DIRECTML:
        return ["DmlExecutionProvider", "CPUExecutionProvider"]
    return ["CPUExecutionProvider"]


def load_asr(model_name, log=print):
    """Грузит модель, перебирая квантизацию int8->fp32 и провайдер DML->CPU.

    Возвращает (model, info) где info — строка вида 'int8/DML' для лога.
    Бросает RuntimeError, если ни один вариант не сработал.
    """
    import onnx_asr

    providers = build_providers()
    cpu_only = ["CPUExecutionProvider"]
    # int8 предпочтительнее (меньше/быстрее); fp32 — запасной для моделей без int8.
    attempts = [
        ("int8/DML", dict(quantization="int8", providers=providers)),
        ("int8/CPU", dict(quantization="int8", providers=cpu_only)),
        ("fp32/DML", dict(providers=providers)),
        ("fp32/CPU", dict(providers=cpu_only)),
    ]
    last_err = None
    for tag, kwargs in attempts:
        try:
            model = onnx_asr.load_model(model_name, **kwargs)
            return model, tag
        except Exception as e:  # noqa: BLE001 - перебираем все варианты
            last_err = e
            log(f"  [{model_name}] вариант {tag} не подошёл: {e}")
    raise RuntimeError(f"не удалось загрузить модель {model_name}: {last_err}")


def save_choice(name):
    """Запоминает выбранную модель, чтобы пережить перезапуск."""
    try:
        with open(_CONFIG_PATH, "w", encoding="utf-8") as f:
            f.write(name.strip() + "\n")
    except Exception:
        pass


def load_choice():
    """Читает запомненную модель; если её нет в списке — модель по умолчанию."""
    try:
        with open(_CONFIG_PATH, encoding="utf-8") as f:
            name = f.read().strip()
        if name in model_names():
            return name
    except Exception:
        pass
    return DEFAULT_MODEL
