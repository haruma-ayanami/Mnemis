import urllib.parse, urllib.request, urllib.error, time, pathlib
from concurrent.futures import ThreadPoolExecutor
pathlib.Path("ru").mkdir(exist_ok=True)
phrases = sorted({l.strip() for l in open("candidates.txt") if l.strip()})
lang = urllib.parse.quote("Английский")
def fetch(p):
    f = pathlib.Path("ru") / (p.replace(" ", "_").replace("'", "") + ".jsonl")
    if f.exists(): return
    url = f"https://kaikki.org/ruwiktionary/{lang}/meaning/{p[0]}/{p[:2]}/{urllib.parse.quote(p)}.jsonl"
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=30) as r:
                f.write_text(r.read().decode("utf-8"), encoding="utf-8"); return
        except urllib.error.HTTPError as e:
            if e.code == 404: f.write_text("", encoding="utf-8"); return
            time.sleep(1 + attempt)
        except Exception:
            time.sleep(1 + attempt)
with ThreadPoolExecutor(max_workers=6) as pool: list(pool.map(fetch, phrases))
