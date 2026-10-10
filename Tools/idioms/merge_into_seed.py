#!/usr/bin/env python3
"""Добавляет идиомы из idioms_final.json в Mnemis/Resources/SeedData/words-en-ru.json (версия словаря +1).

Запуск из папки Tools/idioms после build_idioms.py:
    python3 merge_into_seed.py <путь к words-en-ru.json> <путь к seed-manifest.json>
Ручные переводы берутся из overrides.json (уже применяются в build_idioms.py через idioms_final.json).
"""
import json, sys
from pathlib import Path

seed_path, manifest_path = Path(sys.argv[1]), Path(sys.argv[2])
seed = json.loads(seed_path.read_text(encoding="utf-8"))
existing = {w["lemma"].lower() for w in seed["words"]}
idioms = json.loads(Path("idioms_final.json").read_text(encoding="utf-8"))
added = [i for i in idioms if i["lemma"].lower() not in existing]
seed["words"] += added
seed["version"] = seed.get("version", 1) + 1
seed_path.write_text(json.dumps(seed, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest["seedVersion"] = seed["version"]
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("added", len(added), "version", seed["version"])
