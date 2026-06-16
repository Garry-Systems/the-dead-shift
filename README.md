# THE DEAD SHIFT

*"Your shift just got a lot longer."*

A one-thumb, endless top-down survivor shooter. You're **Ryan Ace**, the gas-station clerk who got
caught on shift the night the dead rose — survive escalating waves, fight bosses, and chase better guns
from crates. Built in **Godot 4 + GDScript**.

---

## 📱 Download for Android

### → **[Get the latest APK](https://github.com/Garry-Systems/the-dead-shift/releases/tag/android-latest)**

1. Open that link **on your phone** (sign in to GitHub — this repo is private).
2. Download **`the-dead-shift.apk`**.
3. Tap it → allow **"install from this source"** when asked → **Install** → play.

> This is a **debug build**, not a Play Store release, so it won't auto-update. Whenever you want the
> newest version, just grab the APK from that page again and reinstall.

---

## 🔄 How updates work

Every push to `master` kicks off a **GitHub Actions** build (~1.5 min) that re-exports the APK and
replaces it on the **[android-latest release](https://github.com/Garry-Systems/the-dead-shift/releases/tag/android-latest)**.
Update your phone by redownloading + reinstalling from that page. No local Android SDK needed — the
cloud builds it.

---

## 🛠 Dev notes

- Engine: **Godot 4.6.3** — use the **standard** build (the project is pure GDScript; the .NET/mono build
  only complicates Android export).
- Vision: simple **endless** survivor — escalating waves, a boss every few waves, and a deep gun-loot
  chase (rarities, random rolls, crates). Keep it simple everywhere except the guns.
- CI: `.github/workflows/android.yml` (uses the `barichello/godot-ci` image). Android export requires
  `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot` (already set).
