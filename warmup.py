"""Скачивает и прогревает ВСЕ модели из asr.MODELS.

Запускается установщиком (setup.ps1) и апдейтером (update.ps1) с флагом
-X utf8. Первый запуск скачивает веса; дальше работает офлайн.
"""

import os
import sys

os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")

import numpy as np

import asr


def main():
    names = asr.model_names()
    print(f"Прогрев {len(names)} модел(и). Первый раз скачает веса из интернета.", flush=True)

    ok = 0
    for name in names:
        print(f"--- {name} ({asr.label_for(name)}) ---", flush=True)
        try:
            model, tag = asr.load_asr(name, log=print)
            _ = model.recognize(np.zeros(16000, dtype=np.float32))
            print(f"    готово [{tag}]", flush=True)
            ok += 1
        except Exception as e:  # noqa: BLE001
            print(f"    ПРОПУСК: {e}", flush=True)

    print(f"Итого: {ok}/{len(names)} моделей готовы.", flush=True)
    # Успех, если хотя бы модель по умолчанию загрузилась.
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
