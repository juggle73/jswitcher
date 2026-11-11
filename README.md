# jswitcher

**English** · [Русский](README.ru.md)

A tiny macOS menu-bar app that fixes text typed in the wrong keyboard layout (Russian ↔ English) — an open-source alternative to Punto Switcher that you can actually audit.

- Type `ghbdtn` and press Space → it becomes «привет », and the layout switches to Russian.
- **Tap the left Control key** to convert the last word to the other layout (and switch the layout). Tap again to undo.
- **Tap Control right after an auto-correction** to revert it.
- **Select text and tap Control** to convert the whole selection.

## Privacy and security

A layout switcher sees every key you press, so trust is the main feature:

- **No network.** There is no networking code. `scripts/build.sh` fails if the binary links `Network`/`CFNetwork` or references `URLSession`, sockets, etc.
- **No clipboard.** Selected text is read via Accessibility only when you tap Control, replaced in place and forgotten.
- **Nothing typed is stored.** Not on disk, not in logs, not in the clipboard. Only the key codes of the current and previous word are kept in memory. Release builds have no logging at all.
- **No third-party dependencies, no entitlements.**
- **Password fields are never touched** (Secure Input).
- One permission only: **Accessibility**. Input Monitoring is not needed.

## Requirements

macOS 13 Ventura or later, Apple Silicon or Intel (universal binary).

Tested on macOS 14 (Apple Silicon). macOS 13 and Intel Macs should work but haven't been tested yet — please report any problems.

## Install

1. Download `jswitcher-<version>.zip` from [Releases](https://github.com/juggle73/jswitcher/releases). Builds are signed with a Developer ID and notarized by Apple. Optionally check the SHA-256 from the release notes:
   ```sh
   shasum -a 256 jswitcher-<version>.zip
   ```
2. Unzip, move `jswitcher.app` to `/Applications`, open it.
3. macOS will ask for **Accessibility** access: enable jswitcher in System Settings → Privacy & Security → Accessibility.

While the permission is missing the menu-bar icon shows `⚠︎`; the menu has items to open the settings and to relaunch the app. Usually the app starts working within 2 seconds after the permission is granted.

**Launch at login.** On first launch jswitcher adds itself to Login Items. To disable: System Settings → General → Login Items (it won't re-add itself). To turn jswitcher off completely, choose «Выход» (Quit) in its menu.

> The app's menus are in Russian.

## Usage

| Action | Result |
|---|---|
| Word + Space / Enter / Tab | If the word was typed in the wrong layout, it is corrected and the layout is switched |
| Left Control (single tap) | Converts the current word. If the word is already followed by a space, converts the previous one. Otherwise just switches the layout |
| Left Control right after an auto-correction | Reverts it |
| Select text + left Control | Converts the whole selection: every character is replaced with the one on the same key in the other layout (comma ↔ «б», etc.; whitespace is kept). The layout is switched |
| Control+Option together (press and release, no other keys), or menu «Пауза» | Pause: no auto-correction, left Control still works. Apps in the exclusion list are always paused |

After Enter or Tab the previous word is not converted (the message was probably sent, or focus moved) — Control only switches the layout.

Menu-bar icon:
- `EN` / `RU` — active;
- grey struck-through E̶N̶ / R̶U̶ — paused (manually, or in an excluded app);
- `—` — another layout is active (e.g. Hebrew); the app does nothing;
- `⚠︎` — no permission.

Supported layouts: ABC (or U.S.) and Russian (or Russian – PC).

### Exclusions

In an excluded app jswitcher is paused: no auto-correction, the left Control works as usual. Edit the list via the menu → «Исключения…»: add an app from disk or from running apps, or remove selected ones. By default only Terminal is excluded. The list is stored in `~/Library/Preferences/io.github.juggle73.jswitcher.plist`.

## How it decides

When a word ends, both readings of the typed keys are checked — e.g. `ghbdtn` / «привет»:

1. Words with digits, `@`, `_`, `://` are never touched.
2. Short words (1–2 letters) are converted only by lists of frequent short words (`b` → «и», `шз` → `ip`).
3. All-caps (3–4 letters) and mixed-case words are converted only if the other reading is a frequent word: «ЫУЕ» → `SET`, but `API`, «НДС», `getUser` stay.
4. A word known in the typed layout stays, unless it's rare there and frequent in the other one (`dct` → «все»).
5. A word known in the other layout is converted. English contractions are recognised (`don't`).
6. If neither dictionary knows either reading (4+ letters), letter-trigram statistics decide (`gthtcj,hfk` → «пересобрал»).

## Building from source

Requires Xcode 16 (Swift 6).

```sh
scripts/build.sh                 # tests, universal release build, signing, audits → build/jswitcher.app
cp -R build/jswitcher.app /Applications/
```

`scripts/build.sh`:
1. runs the tests;
2. builds a universal (arm64 + x86_64) release binary;
3. assembles `build/jswitcher.app` and signs it with hardened runtime — with the first «Developer ID Application» certificate in your keychain (or `$JSWITCHER_SIGN_IDENTITY`), otherwise ad-hoc;
4. verifies that the binary has no network symbols and no entitlements.

The app icon (`Resources/AppIcon.icns`) is drawn by code: edit `scripts/make-icon.swift` and run `scripts/make-icon.sh`.

With an ad-hoc signature macOS forgets the Accessibility permission on every rebuild: remove jswitcher from the list with «−» and grant it again.

### Releases

```sh
# one time: store notarization credentials in the keychain
xcrun notarytool store-credentials jswitcher-notary --apple-id <apple-id> --team-id <team-id>

scripts/release.sh
```

`scripts/release.sh` signs with a secure timestamp, notarizes, staples and writes `build/jswitcher-<version>.zip` plus its SHA-256. The network is used only by these build tools (Apple's timestamp and notary services), never by the app.

## Word data

| File | Content | Source |
|---|---|---|
| `dict_en.bin`, `dict_ru.bin` | 200,000 most frequent words | [Hermit Dave FrequencyWords](https://github.com/hermitdave/FrequencyWords) (`en_full`, `ru_full`, 2018) |
| `dict_en_top.bin`, `dict_ru_top.bin` | 20,000 most frequent words | same |
| `ngram_en.bin`, `ngram_ru.bin` | letter trigram models trained on the 200,000 words | same |
| `dict_tech.bin` | tech terms (docx, json, golang, kubectl, nginx…) | [cspell-dicts](https://github.com/streetsidesoftware/cspell-dicts), commit `db01cf7` |

Format: an LZFSE-compressed sorted word list; the trigram models are LZFSE-compressed tables of log-probabilities.

To rebuild, put `en_full.txt` and `ru_full.txt` from FrequencyWords into `data/raw/` (git-ignored) and run:

```sh
swift run -c release build-dicts data/raw/en_full.txt en 200000 Resources/dict_en.bin
swift run -c release build-dicts data/raw/ru_full.txt ru 200000 Resources/dict_ru.bin
swift run -c release build-dicts data/raw/en_full.txt en 20000 Resources/dict_en_top.bin
swift run -c release build-dicts data/raw/ru_full.txt ru 20000 Resources/dict_ru_top.bin
swift run -c release build-dicts data/raw/en_full.txt en 200000 Resources/ngram_en.bin --ngram
swift run -c release build-dicts data/raw/ru_full.txt ru 200000 Resources/ngram_ru.bin --ngram

SHA=db01cf70052ad247fa7d8ea94a9d8e87af6e358a
for p in filetypes/src/filetypes software-terms/src/software-terms software-terms/src/software-tools \
         software-terms/src/software-services software-terms/src/coding-terms fullstack/src/fullstack; do
  curl -fsSL "https://raw.githubusercontent.com/streetsidesoftware/cspell-dicts/$SHA/dictionaries/$p.txt"
done > data/raw/tech.txt
swift run -c release build-dicts data/raw/tech.txt en 100000 Resources/dict_tech.bin
```

## License

The code is [MIT](LICENSE). Word data is third-party: the FrequencyWords-derived files are CC BY-SA 4.0, the cspell-dicts-derived file is MIT. See [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt) (also bundled inside the app).

## Manual test checklist

- [ ] TextEdit: `ghbdtn ` → «привет », layout RU; `руддщ ` → `hello `, layout EN
- [ ] `ghbdtn` + left Control → «привет»; Control again → `ghbdtn`
- [ ] `ghbdtn ` → «привет », then Control → `ghbdtn `, layout EN
- [ ] `hello` + Enter + Control → only the layout switches, nothing is erased
- [ ] Ctrl+C, Ctrl+click, right Control — no conversion
- [ ] Notes, Safari, Chrome, Slack — auto-correction works
- [ ] Telegram: `ghbdtn` + Enter sends «привет»; `ghbdtn` + Shift+Enter gives «привет» and a new line
- [ ] Terminal (excluded by default) — no auto-correction; `ghbdtn` + left Control → «привет»
- [ ] «Исключения…»: add an app from running apps → no auto-correction there; remove → works again
- [ ] Password field in Safari — `ghbdtn ` is not corrected
- [ ] Fast typing `ghbdtn vbh ghbdtn ` — character order is preserved
- [ ] Holding `x` for 3 seconds, then Space — no correction
- [ ] Control+Option → grey struck-through icon, `ghbdtn ` not corrected, `ghbdtn` + Control → «привет»; Control+Option again → auto-correction works; Control+Option+arrow does not toggle pause
- [ ] Hebrew layout → `—`, the app does nothing
- [ ] No permission → `⚠︎`, the menu item opens settings; after granting Accessibility → EN/RU (relaunch if needed), `ghbdtn ` is corrected
- [ ] `git`, `npm`, `ls`, `cd`, `API`, «НДС», «и», «в» stay; «ЫУЕ » → `SET `, «ыуЕ » → `seT `; `getUser` stays
- [ ] `gthtcj,hfk ` → «пересобрал », `pfltgkjbk ` → «задеплоил »; `stdout`, `webpack`, `localhost` stay
- [ ] «вщтэе » → `don't `, «руддщю » → `hello. `; «бешу » stays
- [ ] «вщсч » → `docx `, «пщдфтп » → `golang `; `docx` typed in EN stays
- [ ] Switching layout via Ctrl+Space, Fn/🌐, Caps Lock and the macOS menu mid-word and between words — the icon updates immediately, `ghbdtn ` is corrected correctly afterwards
- [ ] Holding `е` → «ё» popup → choose → Control — nothing extra is erased
- [ ] Telegram: select `ghbdtn vbh` in the input + Control → «привет мир»
- [ ] Selected text on a web page (not an input) + Control → only the layout switches, nothing is typed
- [ ] Safari and Chrome address bar (with autocomplete) — nothing extra is erased
