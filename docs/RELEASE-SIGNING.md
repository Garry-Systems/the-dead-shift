# Release signing (Android upload keystore)

Status as of this writing: **BLOCKED on Larry** — the machine that generated this pack has
no `keytool`/JDK installed, so the upload keystore could not be generated or uploaded to
GitHub secrets here. `.github/workflows/android-release.yml` and this doc are written and
ready; the only remaining step is running the commands below once, on a machine with a JDK.

## What this is

Google Play requires every release build to be signed with a private key ("upload key").
Losing the key means you can never update the app under the same package ID again, so:

- The keystore file is generated **once**, kept **only** as a base64 GitHub secret
  (`ANDROID_KEYSTORE_B64`), and is **never committed to either repo**.
- `.gitignore` already blocks `*.jks` / `*.keystore` as a safety net.
- Keep an offline backup of the raw `upload-keystore.jks` file somewhere safe (e.g. a
  password manager attachment or an encrypted drive) — GitHub secrets cannot be read back
  once set, only replaced.

## One-time setup (run these on a machine with a JDK — `keytool` ships with any JDK)

1. Generate the upload keystore. Pick a strong password and remember it — you'll need it
   for step 2 and you should also save it somewhere safe (password manager) as a backup.

   ```bash
   keytool -genkeypair -v \
     -keystore upload-keystore.jks \
     -alias upload \
     -keyalg RSA -keysize 2048 \
     -validity 10000 \
     -storepass "REPLACE_WITH_A_STRONG_PASSWORD" \
     -keypass "REPLACE_WITH_A_STRONG_PASSWORD" \
     -dname "CN=Garry Systems"
   ```

   (`-storepass` and `-keypass` are intentionally the same value — the release workflow
   only wires up one password env var, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`, matching
   the pattern `android.yml` already uses for the debug keystore.)

2. Push the keystore (base64-encoded) and the password to the repo's secrets. Run from
   the same machine, in the same directory as `upload-keystore.jks`:

   ```bash
   gh secret set ANDROID_KEYSTORE_B64 --repo Garry-Systems/the-dead-shift \
     < <(base64 -w0 upload-keystore.jks)

   gh secret set ANDROID_KEYSTORE_PASS --repo Garry-Systems/the-dead-shift \
     --body "REPLACE_WITH_THE_SAME_STRONG_PASSWORD"
   ```

3. Verify both secrets are set (this only shows names, never values):

   ```bash
   gh secret list --repo Garry-Systems/the-dead-shift
   ```

4. Delete `upload-keystore.jks` from the machine you generated it on once you've stored a
   backup copy somewhere safe — don't leave it sitting in a Downloads folder.

## Known prerequisite: the Android Gradle build template

App Bundles (`.aab`) can only be exported through Godot's **Gradle-based** Android build
(`gradle_build/use_gradle_build=true`, wired up in the new `[preset.1]` "Android Release"
preset in `export_presets.cfg`), not the quick built-in APK packaging that `android.yml`
uses for the debug build. That requires a `res://android/build` template
(Project → Install Android Build Template… in the Godot editor, or the equivalent
`--install-android-build-template` CLI step) to exist in the exported project. This repo
does not have that folder yet (`android/` is `.gitignore`d — Godot generates it locally).

If `android-release.yml`'s export step fails with something like "Android build template
not installed" or a missing `res://android/build` error, the fix is either:
- Run **Project → Install Android Build Template…** once in the Godot editor, commit the
  generated `android/build/` folder (un-ignore it, or vendor just that subfolder), so CI
  has it checked out; or
- Add an explicit `godot --headless --install-android-build-template` (or equivalent
  current-version flag — check `godot --help` on the godot-ci image) step before the
  export step in the workflow.

This wasn't resolved here because it needs a real Godot editor run to produce the
template files — flagging it rather than guessing at generated Gradle project contents.

## How the workflow uses the secrets

`.github/workflows/android-release.yml` triggers on pushing a tag matching `v*` (e.g.
`v1.0.0`). It:
1. Decodes `ANDROID_KEYSTORE_B64` back into a `.keystore` file inside the ephemeral
   container (never written to the repo).
2. Exports the "Android Release" preset as a `.aab`, using
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` (`upload`, hardcoded — not secret) /
   `_PASSWORD` (from `ANDROID_KEYSTORE_PASS`) — the same env-var pattern `android.yml`
   already uses for the debug keystore (`GODOT_ANDROID_KEYSTORE_DEBUG_*`).
3. Attaches the resulting `.aab` to the GitHub Release for that tag via
   `softprops/action-gh-release@v2` (same action `android.yml` uses for the rolling debug
   release), creating the release if the tag doesn't have one yet.

To cut a release: `git tag v1.0.0 && git push origin v1.0.0`.

## Rotating the key

You should only ever need to do this if the key is lost or compromised — Play Console
supports upload-key rotation via Play App Signing (Google holds the *app signing* key;
your upload key just needs to be replaced and re-registered with Google). Steps:
1. Generate a new keystore (step 1 above, new file name).
2. Follow Google's "Request upload key reset" flow in Play Console for this app.
3. Re-run step 2 above with `gh secret set` — this **overwrites** the existing secrets
   (no separate delete step needed).
4. Update the local/backup copy of the keystore and destroy the old one once Google
   confirms the new upload key is registered.

## Version codes on release tags

`android-release.yml` derives the AAB's `versionCode` from the tag itself: `vMAJOR.MINOR.PATCH` → `MAJOR*10000 + MINOR*100 + PATCH` (e.g. `v1.2.3` → 10203), and `versionName` = the tag without the `v`. Play requires every upload's versionCode to be strictly greater than all previous ones, so always cut release tags in ascending semver order. The dev pipeline's `0.1.<run>` debug codes are unrelated (different package would collide otherwise — they share the id, so avoid uploading debug builds to Play at all).
