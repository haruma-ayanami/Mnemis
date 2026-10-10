import sys, urllib.parse, urllib.request, urllib.error, time, pathlib
from concurrent.futures import ThreadPoolExecutor
cache = pathlib.Path("cache")
cache.mkdir(exist_ok=True)
phrases = [l.strip() for l in open("candidates.txt") if l.strip()]
phrases = sorted(set(p.replace("'", "’") if False else p for p in phrases))
def fetch(p):
    f = cache / (p.replace(" ", "_").replace("'", "") + ".jsonl")
    if f.exists(): return
    quoted = urllib.parse.quote(p)
    url = f"https://kaikki.org/dictionary/English/meaning/{p[0]}/{p[:2]}/{quoted}.jsonl"
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                f.write_text(r.read().decode("utf-8"), encoding="utf-8"); return
        except urllib.error.HTTPError as e:
            if e.code == 404: f.write_text("", encoding="utf-8"); return
            time.sleep(1 + attempt)
        except Exception:
            time.sleep(1 + attempt)
with ThreadPoolExecutor(max_workers=6) as pool:
    list(pool.map(fetch, phrases))
print("fetched", len(phrases))
