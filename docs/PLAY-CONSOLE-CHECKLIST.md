# Play Console launch checklist — The Dead Shift

Status 2026-07-20: **the build pipeline side is DONE and proven.** Everything left
is clicking through Play Console, which only the account owner can do. Work top
to bottom; each section says what to enter.

## Already done (no action)

- ✅ Upload keystore generated + backed up (`Desktop\BackUps\TheDeadShift-Keystore\`
  — move the .jks + password into your password manager, then delete
  `KEYSTORE-PASSWORD.txt` from the folder).
- ✅ Repo secrets `ANDROID_KEYSTORE_B64` / `ANDROID_KEYSTORE_PASS` set.
- ✅ Signed-AAB pipeline dry-run PASSED (throwaway tag v0.0.99, since deleted):
  `jar verified.`, package `com.garrysystems.thedeadshift`, versionCode from tag,
  **targetSdk 36** (clears the current 35 requirement AND the Aug 31 2026 API-36
  deadline — no action needed there).
- ✅ 512×512 icon (`icon.png` in repo root), 1024×500 feature graphic
  (`docs/play-listing/feature-graphic-1024x500.png`), privacy policy URL live
  (https://garry-systems.github.io/thedeadshift-privacy/).

## 0. Account check (do this FIRST — it changes the timeline)

Play Console → Settings → Developer account. If it's a **personal** account
(created after Nov 2023), production access requires a **closed test with 12+
testers opted in for 14 continuous days** first — plan ~3 weeks end-to-end.
Organization accounts skip that. Nothing to change either way, just know which
timeline you're on before promising yourself a launch date.

## 1. Create the app

Play Console → Create app:
- App name: `The Dead Shift`
- Default language: `English (United States)`
- App or game: **Game** · Free or paid: **Free**
- Declarations: accept. (Free is PERMANENT for a package id — fine here.)

## 2. Set up your app (the declarations checklist Play walks you through)

- **Privacy policy:** `https://garry-systems.github.io/thedeadshift-privacy/`
- **App access:** All functionality available without special access (no login).
- **Ads:** **No ads.**
- **Content rating (IARC questionnaire):** category = Game. Truthful answers:
  violence against **fantasy/undead creatures**, pixel-art, no gore of humans, no
  sexual content, no profanity, no drugs, **no simulated gambling** (crates are
  bought with in-game coins earned by playing; there are NO real-money purchases
  of any kind, no IAP), no user interaction/chat, no sharing location. Expect
  ~Everyone 10+ / Teen depending on region boards.
- **Target audience:** **13 and over** (do NOT tick younger brackets — keeps you
  out of the Families policy track).
- **News app:** No. · **COVID tracing:** No.
- **Data safety:** **No data collected, no data shared** — verified accurate
  against the code (zero networking; saves are local only). Full prepared
  answers: `docs/play-data-safety.md`. Backup note: the manifest sets
  `user_data_backup=false`, so also answer "no" to data-being-backed-up.
  (Minor: the privacy policy's backup wording is slightly broader than the
  manifest — optional one-line edit in the privacy repo, not a blocker.)
- **Government app:** No. · **Financial features:** None.

## 3. Store listing

Main store listing → fill in:
- **Short description** (max 80 chars, draft — edit freely):
  `Night shift at a haunted gas station. RNG guns, 11 bosses, survive to dawn.`
- **Full description** (max 4000 chars, draft below — edit freely):

```
Clock in at 10PM. Survive to 6AM. Get paid.

THE DEAD SHIFT is a top-down pixel survivor: one thumb to move, your gun aims
itself, and the parking lot fills with the hungry dead until dawn breaks or
you do.

RNG IS KING
Every gun is rolled, not given. 9 rarity tiers up to the molten-gold
ARMAGEDDON, 60 talents, signature affixes, and a fusion system that feeds
duplicates to the weapon you love. No two pulls are ever the same.

MEET THE STAFF
11 bosses walk the lot — the Manager never clocked out, the Karen wants to
speak to him, the Tanker hauls his own funeral pyre. Survive the mystery
shopper. Pet the store cat.

7 EMPLOYEES, 7 ABILITIES
Ryan clears the room. Jimbo's aimbot does the work. Bob simply refuses to
die. Unlock the whole night crew, each with a signature active and their own
way to ruin a zombie's evening.

EVERY SHIFT IS DIFFERENT
Blood moons, fog banks, rush hours. An ice cream truck that sells mid-run
heals. A basement you should not go down into. Three locations, daily seeded
shifts, elite zombies, and a dawn extraction if you're good enough to catch
the chopper.

NO ADS. NO IN-APP PURCHASES. NO INTERNET REQUIRED.
Just you, the pumps, and the dead. Offline forever, saves on your phone.

Benefits package includes: daily streak rewards, employee rank ladder with
unlockable game modes (Horde Night, Overtime, Hardcore), 18 commendations,
challenge board, and a pay stub at the end of every shift.
```

- **Graphics:**
  - App icon 512×512: repo `icon.png` ✅
  - Feature graphic 1024×500: `docs/play-listing/feature-graphic-1024x500.png` ✅
  - **Phone screenshots: STILL NEEDED** — minimum 2, aim for 4–6 portrait
    shots. Take them on the phone (volume-down+power), they'll be 1080×2400 —
    accepted as-is (Play allows 16:9 through ~20:9). Good subjects: mid-horde
    combat with combat text popping, a boss with its named HP bar, the crate
    reel mid-spin, the SHIFT'S OVER pay stub, character select, an ARMAGEDDON
    weapon inspect.

## 4. First release (internal testing FIRST)

1. Ship the next real version the normal way (bump `VERSION`, commit, tag
   `vX.Y.Z` matching it, push tag). The release workflow attaches
   `the-dead-shift.aab` to the GitHub release — download it.
2. Play Console → Testing → **Internal testing** → Create release → upload the
   AAB. When prompted, **enroll in Play App Signing** (accept default: Google
   holds the app signing key, ours becomes the upload key — this is what makes
   the upload key rotatable if ever lost).
3. Add your own Gmail as an internal tester, install via the opt-in link,
   sanity-pass on the phone.
4. Then Closed testing (the 12-tester/14-day track if personal account) →
   Production.

## Rules that keep the pipeline safe (already enforced, don't fight them)

- Releases go out **only via ascending `vX.Y.Z` tags** — the tag mints
  versionCode (MAJOR*10000+MINOR*100+PATCH) and Play requires it to strictly
  increase. Never upload a debug-pipeline APK to Play (same package id,
  colliding run-number codes).
- Tag must match the committed `VERSION` file (the v0.1.56/57 drift lesson).
- The keystore backup folder is the ONLY recoverable copy — GitHub secrets
  can't be read back.
