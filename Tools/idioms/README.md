# Идиомы встроенного словаря

Список английских идиом (`candidates.txt`) и их значения берутся из открытых источников:

- английский Викисловарь через kaikki.org (определения, примеры, переводы) — CC BY-SA;
- русский Викисловарь через kaikki.org/ruwiktionary (русские толкования) — CC BY-SA.

Ручные переводы, где автоматические были неудачными, лежат в `overrides.json`.

Порядок пересборки:

```bash
cd Tools/idioms
python3 fetch_en.py        # кэш ./cache
python3 fetch_ru.py        # кэш ./ru
python3 build_idioms.py    # создаёт idioms_final.json
python3 merge_into_seed.py ../../Mnemis/Resources/SeedData/words-en-ru.json ../../Mnemis/Resources/SeedData/seed-manifest.json
```

`build_idioms.py` читает `candidates.txt` и папки `cache` и `ru` относительно текущей папки.
