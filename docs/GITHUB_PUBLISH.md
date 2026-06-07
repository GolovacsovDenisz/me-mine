# Publishing Me Mine to GitHub (portfolio)

## Your setup today

This folder is already linked to GitHub:

```text
origin → https://github.com/GolovacsovDenisz/me-mine-.git
branch → main
```

If your friend uses **GitLab (private)** for releases, keep both remotes:

```bash
git remote add gitlab git@gitlab.com:YOUR_GROUP/me_mine.git   # once
git push gitlab main                                          # friend’s copy
git push origin main                                          # your portfolio copy
```

You do **not** need a second GitHub repo unless you want a cleaner name (e.g. `me-mine` without the trailing `-`).

---

## Push latest code to GitHub

```bash
cd /path/to/me_mine

git status
git add -A
git commit -m "Portfolio-ready: journal UI, AI analysis, attachments"

git push origin main
```

If GitHub asks for login, use a [Personal Access Token](https://github.com/settings/tokens) or SSH.

---

## Make the repo public (for employers)

1. Open https://github.com/GolovacsovDenisz/me-mine-
2. **Settings → General → Danger Zone → Change visibility → Public**

Optional: rename repo to `me-mine` in **Settings → General → Repository name** (update `git remote set-url origin …` after rename).

---

## Security check before going public

| Item | In git? | Risk | Action |
|------|---------|------|--------|
| **GEMINI_API_KEY** | No (Firebase Secret only) | Low | Keep only in Firebase Console → Functions secrets |
| **`.env` files** | No | — | Never commit; already in `.gitignore` |
| **`firebase_options.dart`** | Yes | Normal for Flutter | Restrict API key in [Google Cloud Console](https://console.cloud.google.com/) (Android/iOS app limits) |
| **`google-services.json`** | Yes | Normal for Flutter | Same as above |
| **`GoogleService-Info.plist`** | Yes | Normal for Flutter | Same as above |
| **`.firebaserc`** | Yes | Low (project id `me-mine-99e66`) | OK |
| **`.vscode/launch.json`** | Yes | Low (uses `env:GEMINI_API_KEY`, no key value) | OK |
| **Firestore / Storage rules** | Not in this repo | — | Ensure rules require `request.auth != null` in Firebase Console |

**Not a secret but optional to remove from public repo:** `.cursor/plans/`, `Me_Mine_Plan.html` (internal notes only).

**Critical:** Gemini must stay server-side (`functions/index.js` + `defineSecret`). Do not add `--dart-define=GEMINI_API_KEY=...` with a real key in committed files.

---

## After push

- Add a short **README** (stack, screenshots, “clone & run”).
- Pin the repo on your GitHub profile.
- Link the repo + demo video in CV / Kwork.

Your friend can keep using **private GitLab** for store builds; you push the same `main` branch to both remotes when you agree on updates.
