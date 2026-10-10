import json, re, pathlib
STRESS = "̀́"
CYR = re.compile(r"^[а-яё][а-яё \-]*$", re.I)
def clean(t): return "".join(c for c in t if c not in STRESS).strip()
def good(t): return bool(CYR.match(t)) and len(t.split()) <= 3 and not t.startswith("у ")
items, skipped = [], []
for line in open("candidates.txt"):
    phrase = line.strip()
    if not phrase: continue
    f = pathlib.Path("cache") / (phrase.replace(" ", "_").replace("'", "") + ".jsonl")
    entries = []
    if f.exists():
        for l in f.read_text(encoding="utf-8").splitlines():
            if not l.strip(): continue
            e = json.loads(l)
            if e.get("word", "").lower() == phrase.lower(): entries.append(e)
    if not entries:
        skipped.append((phrase, "no page")); continue
    definition, example = None, None
    for e in entries:
        for s in e.get("senses", []):
            gl = (s.get("glosses") or [""])[0].strip().rstrip(".")
            if not gl or gl.startswith("Used other than") or len(gl) < 15 or gl.startswith(("Alternative", "Synonym of", "Obsolete")):
                continue
            if definition is None: definition = gl
            for ex in s.get("examples", []):
                text = (ex.get("text") or "").split("\n")[0].strip()
                if phrase.lower() in text.lower() and 20 <= len(text) <= 140 and "ſ" not in text:
                    example = text; break
            if definition and example: break
        if definition and example: break
    ru = []
    for e in entries:
        for t in e.get("translations", []):
            if t.get("lang_code") == "ru" and t.get("word"):
                w = clean(t["word"])
                if good(w) and w not in ru: ru.append(w)
    # Русский Викисловарь: глосса уже на русском, это надёжнее таблицы переводов.
    rf = pathlib.Path("ru") / (phrase.replace(" ", "_").replace("'", "") + ".jsonl")
    ru_gloss = []
    if rf.exists():
        for l in rf.read_text(encoding="utf-8").splitlines():
            if not l.strip(): continue
            e = json.loads(l)
            if e.get("word", "").lower() != phrase.lower(): continue
            for sense in e.get("senses", []):
                for gl in sense.get("glosses") or []:
                    gl = re.sub(r"\([^)]*\)", "", gl)
                    for part in re.split(r"[;,]", gl):
                        part = part.strip(" .")
                        if part and good(part) and part not in ru_gloss: ru_gloss.append(part)
    if ru_gloss:
        ru = ru_gloss + [w for w in ru if w not in ru_gloss]
    if not definition or not ru:
        skipped.append((phrase, f"def={bool(definition)} ru={len(ru)}")); continue
    item = {"lemma": phrase, "translation": ", ".join(ru[:3]), "partOfSpeech": "idiom",
            "definition": definition[:200], "level": "B1"}
    if example: item["examples"] = [example]
    items.append(item)
json.dump(items, open("idioms.json", "w"), ensure_ascii=False, indent=1)
# Ручные переводы поверх автоматических
ov = json.load(open("overrides.json", encoding="utf-8"))
for it in items:
    if it["lemma"] in ov: it["translation"] = ov[it["lemma"]]
json.dump(items, open("idioms_final.json", "w"), ensure_ascii=False, indent=1)
print("kept", len(items))
for p, why in skipped: print("skip", p, why)
