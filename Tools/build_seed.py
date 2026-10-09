#!/usr/bin/env python3
"""Собирает Mnemis/Resources/SeedData/words-en-ru.json (версия 2: значения по частям речи).

Источники (см. seed-manifest.json):
  - список слов и ранг: NGSL-GR 1.0 (CC BY-SA 4.0), https://www.newgeneralservicelist.com
  - определения, IPA, примеры и таблицы переводов: английский Викисловарь через kaikki.org (CC BY-SA)
  - русские толкования английских слов: русский Викисловарь через kaikki.org/ruwiktionary (CC BY-SA),
    если для слова есть кэш в <ru_cache_dir>. Они точнее таблиц переводов и уже разбиты по частям речи.

Использование:
  python3 Tools/build_seed.py <ngsl.csv> <en_cache_dir> <out.json> [limit] [ru_cache_dir] [--fetch-ru]
Страницы kaikki кэшируются, повторный запуск ничего не скачивает заново.
Без --fetch-ru русский Викисловарь читается только из кэша.
"""
import csv, json, re, sys, time, urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

args = [a for a in sys.argv[1:] if not a.startswith("--")]
FETCH_RU = "--fetch-ru" in sys.argv
csv_path, cache_dir, out_path = args[0], Path(args[1]), args[2]
limit = int(args[3]) if len(args) > 3 else 5050
ru_cache_dir = Path(args[4]) if len(args) > 4 else None
cache_dir.mkdir(parents=True, exist_ok=True)
if ru_cache_dir:
    ru_cache_dir.mkdir(parents=True, exist_ok=True)

SEED_VERSION = 3
ACCENTS = re.compile("[̀́]")  # ударения в русских словах Викисловаря
POS_NAMES = {"noun": "noun", "verb": "verb", "adj": "adjective", "adv": "adverb", "prep": "preposition"}
MAX_POS = 3
MAX_PER_POS = 4


def fetch(url, cache):
    if cache.exists():
        return cache.read_text(encoding="utf-8")
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


def fetch_en(word):
    url = f"https://kaikki.org/dictionary/English/meaning/{word[0]}/{word[:2]}/{word}.jsonl"
    return fetch(url, cache_dir / f"{word}.jsonl")


def fetch_ru(word):
    if not ru_cache_dir:
        return ""
    cache = ru_cache_dir / f"{word}.jsonl"
    if not cache.exists() and not FETCH_RU:
        return ""
    lang = urllib.parse.quote("Английский")
    url = f"https://kaikki.org/ruwiktionary/{lang}/meaning/{word[0]}/{word[:2]}/{word}.jsonl"
    return fetch(url, cache)


def clean(text):
    return ACCENTS.sub("", text).strip()


def lines(text):
    out = []
    for line in text.splitlines():
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return out


NUMBERS = set("august zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty thirty forty fifty sixty seventy eighty ninety hundred thousand million billion".split())
# Служебные слова не нужны в словаре для запоминания: местоимения, кванторы, союзы, вспомогательные глаголы.
FUNCTION_WORDS = set("""noun verb adjective adverb pronoun preposition conjunction article tense plural singular grammar
you he she it we they me him her us them my your his its our their not that this these those will would can could shall
should may might must the and but if of to in on at by for with from as is are was were be been being am do does did done
there when what who whom whose which where why how than then have has had also very just only too out off up
all any some each every both either neither such many much few several own other another more most less least
none no yes nor yet ever never else whether""".split())
RARE_TAGS = {"obsolete", "archaic", "rare", "dated", "slang", "vulgar", "offensive", "dialectal", "historical", "poetic",
             "informal", "colloquial", "nonstandard", "derogatory"}
META = ("Alternative", "Ellipsis", "Abbreviation", "Initialism", "Acronym", "Misspelling", "Synonym of", "Obsolete",
        "Eye dialect", "Clipping", "Contraction")
# Узкие значения из таблиц переводов: юридические, спортивные, морские и т. п. В основной перевод их не берём.
NARROW_SENSE = re.compile(
    r"\b(legal|legally|law|nautical|naval|heraldry|cricket|baseball|volleyball|tennis|golf|chess|set theory|"
    r"mathematic|geometry|music|printing|typograph|archaic|obsolete|dialect|slang|vulgar|anatomy|botany|zoology|"
    r"chemistry|physics|military|card games?|poker|sailing|horse|religion|christianity|bible|computing|programming)\b",
    re.I,
)
CYRILLIC = re.compile(r"^[а-яё][а-яё \-]*$", re.I)
DOMAIN_LABEL = re.compile(r"^[a-z][a-z ,]*:")
# Доля переводов, ниже которой значение считается редким: от главного значения той же части речи
# и, для второстепенных частей речи, от главного значения слова.
MIN_SHARE = 0.1
MIN_POS_SHARE = 0.08


def good_gloss(gloss):
    text = gloss.strip().rstrip(".")
    return len(text) >= 15 and not text.startswith(META) and "form of" not in text and "(“" not in text


# Окончания инфинитива. «-ть» есть и у существительных («несдержанность», «власть»), поэтому у глагола
# проверяем инфинитив, а у других частей речи отсекаем только явно глагольные окончания.
INFINITIVE = re.compile(r"(ть|ться|ти|тись|чь|чься)$")
VERB_ONLY = re.compile(r"(ться|тись|чься|овать|евать|ировать|ывать|ивать)$")


def good_translation(word, pos=None):
    """Русское слово без латиницы и пояснений, до трёх слов. У глагола — инфинитив, у остальных — не глагол."""
    if not CYRILLIC.match(word) or len(word.split()) > 3 or word.startswith("у "):
        return False
    head = word.split()[0]
    if pos == "verb":
        return bool(INFINITIVE.search(head))
    if pos is not None:
        return not VERB_ONLY.search(head)
    return True


def en_meanings(entries):
    """Переводы из таблиц английского Викисловаря, по частям речи.

    Вес значения — число его переводов на все языки: чем шире значение переведено, тем оно употребительнее.
    Значения слабее 10 % главного отбрасываются, слово ранжируется по сумме весов значений, где оно встречается.
    Из пары глаголов несовершенного и совершенного вида берём несовершенный.
    Основная часть речи — до четырёх слов, остальные — до двух.
    """
    by_pos = {}
    for e in entries:
        pos = e["pos"]
        groups = by_pos.setdefault(pos, {})
        for t in e.get("translations", []):
            sense = t.get("sense") or ""
            group = groups.setdefault(sense, {"weight": 0, "ru": []})
            group["weight"] += 1
            if t.get("lang_code") != "ru" or not t.get("word"):
                continue
            tags = set(t.get("tags") or [])
            if NARROW_SENSE.search(sense) or tags & RARE_TAGS:
                continue
            group["ru"].append((clean(t["word"]), tags))

    # Значение с пометкой предметной области («finance: …», «geometry: …») понижаем вдвое: оно не главное.
    for groups in by_pos.values():
        for sense, group in groups.items():
            if DOMAIN_LABEL.match(sense):
                group["weight"] /= 2

    meanings = []
    for pos, groups in by_pos.items():
        ranked = sorted((g for g in groups.values() if g["ru"]), key=lambda g: -g["weight"])
        if not ranked:
            continue
        # Редкие значения не берём: «чайка» у beard переведена на 8 языков против 330 у «бороды».
        top = ranked[0]["weight"]
        ranked = [g for g in ranked if g["weight"] >= top * MIN_SHARE]

        # Вес русского слова — сумма весов значений, где оно встречается: «интерес» покрывает три
        # значения interest и обгоняет «процент» из одного финансового. Из одного значения — не больше двух слов.
        score, order, per_group = {}, {}, {}
        for gi, group in enumerate(ranked):
            items = group["ru"]
            has_imperfective = any("imperfective" in tags for _, tags in items)
            words = [w for w, tags in items
                     if good_translation(w, pos) and not (has_imperfective and "perfective" in tags and "imperfective" not in tags)]
            for wi, w in enumerate(dict.fromkeys(words)):
                score[w] = score.get(w, 0) + group["weight"]
                order.setdefault(w, (gi, wi))
                per_group.setdefault(w, gi)
        candidates = sorted(score, key=lambda w: (-score[w], order[w]))
        picked, used = [], {}
        for w in candidates:
            gi = per_group[w]
            if used.get(gi, 0) >= 2:
                continue
            picked.append(w)
            used[gi] = used.get(gi, 0) + 1
            if len(picked) >= MAX_PER_POS:
                break
        if picked:
            meanings.append({"partOfSpeech": POS_NAMES[pos], "translation": picked, "weight": top})
    return meanings


def ru_meanings(word):
    """Толкования из русского Викисловаря: «способный, талантливый», «мочь, быть в состоянии».

    Из первого значения части речи берём два варианта, из следующих — по одному, без пояснений в скобках.
    """
    meanings = []
    seen_pos = set()
    for e in lines(fetch_ru(word)):
        pos = e.get("pos")
        if e.get("word", "").lower() != word or pos not in POS_NAMES or pos in seen_pos:
            continue
        picked = []
        for index, sense in enumerate(e.get("senses", [])):
            parts = []
            for gloss in sense.get("glosses") or []:
                gloss = re.sub(r"\([^)]*\)", "", clean(gloss))
                parts += [p.strip(" .") for p in re.split(r"[;,]", gloss)]
            parts = [p for p in parts if p and good_translation(p) and p not in picked]
            picked.extend(parts[:2] if index == 0 else parts[:1])
            if len(picked) >= MAX_PER_POS:
                break
        if picked:
            seen_pos.add(pos)
            meanings.append({"partOfSpeech": POS_NAMES[pos], "translation": picked[:MAX_PER_POS], "weight": 10**6})
    return meanings


def merge(primary, secondary, main_pos):
    """Части речи из русского Викисловаря важнее; недостающие добавляем из таблиц переводов.

    Первой идёт часть речи определения, остальные — по употребительности. У второстепенных частей речи два слова.
    """
    result = list(primary)
    have = {m["partOfSpeech"] for m in result}
    result += [m for m in secondary if m["partOfSpeech"] not in have]
    result.sort(key=lambda m: (m["partOfSpeech"] != main_pos, -m["weight"]))
    # Редкая вторая часть речи (beard как глагол «бросать вызов») не показывается.
    if result:
        top = max(m["weight"] for m in result)
        result = [result[0]] + [m for m in result[1:] if m["weight"] >= top * MIN_POS_SHARE]
    out = []
    for index, m in enumerate(result[:MAX_POS]):
        words = m["translation"] if index == 0 else m["translation"][:2]
        out.append({"partOfSpeech": m["partOfSpeech"], "translation": ", ".join(words)})
    return out


def build(rank, word):
    if word in NUMBERS or word in FUNCTION_WORDS:
        return None
    entries = [e for e in lines(fetch_en(word))
               if e.get("word", "").lower() == word.lower() and e.get("pos") in POS_NAMES]
    if not entries:
        return None

    # Определение и пример — из первого подходящего значения в порядке страницы: оно обычно самое частотное.
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

    # Часть речи определения идёт первой: определение и перевод на карточке должны совпадать.
    meanings = merge(ru_meanings(word), en_meanings(entries), POS_NAMES[main["pos"]])
    if not meanings:
        return None

    ipa = next((s["ipa"] for s in main.get("sounds", []) if s.get("ipa")), None)
    level = "A2" if rank <= 1500 else "B1" if rank <= 3000 else "B2"
    item = {
        "lemma": word,
        "translation": meanings[0]["translation"],
        "partOfSpeech": meanings[0]["partOfSpeech"],
        "definition": definition,
        "level": level,
        "frequencyRank": rank,
    }
    if len(meanings) > 1:
        item["meanings"] = meanings
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
body = ",\n".join(" " + json.dumps(item, ensure_ascii=False) for item in items)
Path(out_path).write_text(
    f'{{"sourceID": "ngsl-wiktionary", "version": {SEED_VERSION}, "words": [\n' + body + "\n]}\n",
    encoding="utf-8",
)
multi = sum(1 for i in items if "meanings" in i)
print(f"{len(items)} words of {len(words)} candidates, {multi} with several parts of speech")
