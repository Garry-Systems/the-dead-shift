# Play Console Data Safety — pre-filled answers

Reference for filling out the Google Play Console "Data safety" form for **The Dead
Shift**. Re-verify against the live Play Console form when submitting, since Google
periodically changes the question wording/options — this is a drafting aid, not a
guarantee the form hasn't changed shape since it was written.

## Does your app collect or share any of the required user data types?

**No.**

The app collects no data at all — no location, personal info, financial info, health,
messages, photos/videos, audio, files, app activity, app info/performance, or device IDs.
There are no third-party SDKs (no analytics, no ads, no crash reporting) that would collect
data on the app's behalf either.

If the form forces a walk-through of every category, the answer for every single data
type is: **"Data is not collected."**

## Data encryption in transit

Not applicable — select **"App doesn't collect any user data"** if offered as a top-level
option; if the form still asks the in-transit encryption sub-question, the honest answer
is "N/A — no data is transmitted anywhere," since the game makes no network requests.

## Data deletion

Not applicable — no data is collected, so there is nothing to request deletion of, and no
account/login system exists for a deletion request to even attach to. If the form requires
an account-deletion URL, note in that field that the app has no user accounts.

## Independent security review

No — not applicable given no data is collected; skip/mark "no" if asked whether the app
has undergone an independent security review.

## Ads

No ads (no ad SDK is integrated).

## Summary to paste into the top-level Play Console declaration

> The Dead Shift does not collect or share any user data. It is a fully offline,
> single-player game with no analytics, no advertising, no third-party SDKs, and no
> network requests of any kind. All progress is stored locally on-device only and is
> removed when the app is uninstalled.

## Contact for data safety questions

**garry.system.dev@gmail.com**
