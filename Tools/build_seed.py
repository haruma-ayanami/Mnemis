#!/usr/bin/env python3
"""Собирает Mnemis/Resources/SeedData/words-en-ru.json.

Источники (см. seed-manifest.json):
  - список слов и ранг: NGSL-GR 1.0 (CC BY-SA 4.0), https://www.newgeneralservicelist.com
  - определения, IPA, примеры, русские переводы: Wiktionary через kaikki.org (CC BY-SA)

Использование:
  python3 Tools/build_seed.py <ngsl.csv> <cache_dir> <out.json> [limit]
Страницы kaikki кэшируются в <cache_dir>, повторный запуск ничего не скачивает заново.
"""
import csv, json, re, sys, time, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

csv_path, cache_dir, out_path = sys.argv[1], Path(sys.argv[2]), sys.argv[3]
limit = int(sys.argv[4]) if len(sys.argv) > 4 else 5050
cache_dir.mkdir(parents=True, exist_ok=True)

ACCENTS = re.compile("[̀́]")  # ударения в русских словах Wiktionary
POS_ORDER = {"noun": 0, "verb": 1, "adj": 2, "adv": 3}


def fetch(word):
    cache = cache_dir / f"{word}.jsonl"
    if cache.exists():
        return cache.read_text(encoding="utf-8")
    first = word[0]
    url = f"https://kaikki.org/dictionary/English/meaning/{first}/{word[:2]}/{word}.jsonl"
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                text = r.read().decode("utf-8")
            cache.write_text(text, encoding="utf-8")
            return text
        except urllib.error.HTTPError as e:
            if e.code == 404:
                cache.write_text("", encoding="utf-8")
                return ""
            time.sleep(1 + attempt)
        except Exception:
            time.sleep(1 + attempt)
    return ""


def clean(text):
    return ACCENTS.sub("", text).strip()


NUMBERS = set("august zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand million billion".split())
# Служебные слова не нужны в словаре для запоминания: местоимения, предлоги, союзы, вспомогательные глаголы.
FUNCTION_WORDS = set("""noun verb adjective adverb pronoun preposition conjunction article tense plural singular grammar you he she it we they me him her us them my your his its our their not that this these those will would can could shall should may might must the and but if of to in on at by for with from as is are was were be been being am do does did done there when what who whom whose which where why how than then have has had also very just only too out off up""".split())
RARE_TAGS = {"obsolete", "archaic", "rare", "dated", "slang", "vulgar", "offensive", "dialectal", "historical", "poetic", "informal"}
META = ("Alternative", "Ellipsis", "Abbreviation", "Initialism", "Acronym", "Misspelling", "Synonym of", "Obsolete", "Eye dialect", "Clipping", "Contraction")


def good_gloss(gloss):
    text = gloss.strip().rstrip(".")
    return len(text) >= 15 and not text.startswith(META) and "form of" not in text and "(“" not in text


def build(rank, word):
    if word in NUMBERS or word in FUNCTION_WORDS:
        return None
    entries = [json.loads(l) for l in fetch(word).splitlines() if l.strip()]
    entries = [e for e in entries if e.get("word", "").lower() == word.lower() and e.get("pos") in POS_ORDER]
    if not entries:
        return None

    # Берём первое подходящее значение в порядке страницы Wiktionary: оно обычно самое частотное.
    main = definition = example = None
    for e in entries:
        for s in e.get("senses", []):
            glosses = s.get("glosses") or []
            tags = set(s.get("tags", []))
            if glosses and not tags & RARE_TAGS and good_gloss(glosses[0]):
                main, definition = e, glosses[0].strip().rstrip(".")
                for ex in s.get("examples", []):
                    text = ex.get("text", "").strip().split("\n")[0].strip()
                    if 15 <= len(text) <= 120 and " — " not in text and word.lower() in text.lower():
                        example = text
                        break
                break
        if main:
            break
    if not main:
        return None

    # Переводы только для той же части речи, что и определение.
    translations = []
    for e in entries:
        if e["pos"] != main["pos"]:
            continue
        for t in e.get("translations", []):
            if t.get("lang_code") == "ru" and t.get("word"):
                w = clean(t["word"])
                if w and w not in translations and len(w.split()) <= 2 and not w.startswith('у '):
                    translations.append(w)
    if not translations:
        return None

    ipa = next((s["ipa"] for s in main.get("sounds", []) if s.get("ipa")), None)
    pos = {"adj": "adjective", "adv": "adverb"}.get(main["pos"], main["pos"])
    level = "A2" if rank <= 1500 else "B1" if rank <= 3000 else "B2"
    item = {
        "lemma": word,
        "translation": ", ".join(translations[:3]),
        "partOfSpeech": pos,
        "definition": definition,
        "level": level,
        "frequencyRank": rank,
    }
    if ipa:
        item["ipa"] = ipa
    if example:
        item["examples"] = [example]
    return item


words = []
with open(csv_path, encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        w = row["Word"].strip()
        # Только обычные строчные слова: без дней недели, месяцев и имён собственных.
        if w.isalpha() and w.islower() and w.isascii() and len(w) > 2:
            words.append((int(row["WordID"]), w))
words = words[:limit]

with ThreadPoolExecutor(max_workers=6) as pool:
    results = list(pool.map(lambda rw: build(*rw), words))

items = [r for r in results if r]
lines = ",\n".join(" " + json.dumps(item, ensure_ascii=False) for item in items)
Path(out_path).write_text(
    '{"sourceID": "ngsl-wiktionary", "words": [\n' + lines + "\n]}\n",
    encoding="utf-8",
)
print(f"{len(items)} words of {len(words)} candidates")
