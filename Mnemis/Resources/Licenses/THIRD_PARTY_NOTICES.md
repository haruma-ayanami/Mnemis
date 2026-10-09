# Third-party notices

Mnemis использует следующие данные. Тексты лицензий и атрибуция также лежат в `SeedData/seed-manifest.json`
и показываются на экране «Data» в Settings.

| Источник | Где используется | Лицензия |
|---|---|---|
| [NGSL-GR 1.0](https://www.newgeneralservicelist.com/ngsl-graded-reader) (Browne, Culligan и др.) | список слов и ранг в `SeedData/words-en-ru.json` | CC BY-SA 4.0 |
| [Wiktionary](https://www.wiktionary.org) через [kaikki.org](https://kaikki.org) (wiktextract) | определения, IPA, примеры и русские переводы | CC BY-SA |
| [Free Dictionary API](https://dictionaryapi.dev) | необязательное дополнение слов по сети | условия данных не опубликованы, проверить перед релизом |

Цитирование wiktextract: Tatu Ylonen, *Wiktextract: Wiktionary as Machine-Readable Structured Data*, LREC 2022, pp. 1317–1325.

Данные NGSL-GR и Wiktionary распространяются под CC BY-SA, поэтому производный словарь `words-en-ru.json`
распространяется на тех же условиях. Скрипт сборки: `Tools/build_seed.py`.
