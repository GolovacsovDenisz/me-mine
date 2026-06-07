# Plan: show Me Mine to recruiters (simple)

You only need **GitHub (public)** for LinkedIn and CV. **GitLab** is optional — another hosting site, like GitHub; your friend can use it for private deploys. Recruiters almost always look at **GitHub**.

---

## Step 1 — Clean the repo (done once)

Internal files are removed from git (they can stay on your Mac):

- `.cursor/plans/…`
- `Me_Mine_Plan.html`

Commit that cleanup when you push (see Step 3).

---

## Step 2 — Make GitHub public

1. Open https://github.com/GolovacsovDenisz/me-mine-
2. **Settings** → **General** → bottom **Danger zone**
3. **Change repository visibility** → **Public**

Optional: **Settings → General → Repository name** → rename to `me-mine` (nicer link).

---

## Step 3 — Push your latest code

In Terminal, in the project folder:

```bash
git add -A
git commit -m "Portfolio: README, remove internal plan files"
git push origin main
```

Your link for everyone:

`https://github.com/GolovacsovDenisz/me-mine-`

(Change URL if you rename the repo.)

---

## Step 4 — Make the repo look good (30 min)

On GitHub, in the repo page:

1. **README** — already in the project; after push it shows on the main page.
2. Add **3–5 screenshots** — create folder `docs/screenshots/`, commit PNGs, add them to README.
3. **Topics** (right side on GitHub): `flutter`, `firebase`, `dart`, `mobile-app`, `ai`
4. **Pin** the repo: your GitHub profile → **Customize pins** → select Me Mine.

---

## Step 5 — Demo video (optional but strong)

1. Record 60–90 sec on phone (screen record).
2. Upload to **YouTube** (Unlisted) or **Google Drive** (anyone with link).
3. Add link in README: `## Demo` → `[Watch 90s demo](https://...)`

---

## Step 6 — LinkedIn

**Profile → Featured** (or **About**):

- Add link: GitHub repo URL
- Add link: demo video (if you have one)
- One line: *Flutter journal app with Firebase + server-side Gemini AI*

**Experience / Projects** (if you have a Projects section):

- **Title:** Me Mine — Personal journal (Flutter)
- **Description:** Daily entries, calendar, analytics, AI weekly summaries. Stack: Flutter, Riverpod, Firebase, Cloud Functions, Gemini.
- **Link:** same GitHub URL

---

## Step 7 — CV / Kwork / hh

Same GitHub link everywhere. One stack line:

> Flutter · Firebase · Firestore · Cloud Functions · Gemini API (server-side)

---

## What about GitLab?

| | GitHub (you) | GitLab (friend, optional) |
|---|----------------|---------------------------|
| Who sees it | Everyone (public) | Only invited people |
| For what | Recruiters, LinkedIn | Private builds, store release |
| You must use it? | **Yes** for portfolio | **No** for LinkedIn |

You and your friend can use **the same code**: you `git push` to GitHub; he adds GitLab as second remote and pushes there too. Recruiters only need the **GitHub public** link.

---

## Checklist

- [ ] Repo is **Public** on GitHub
- [ ] Latest code **pushed** (`git push origin main`)
- [ ] README visible on repo home page
- [ ] At least **2 screenshots** in README
- [ ] Repo **pinned** on GitHub profile
- [ ] Link in **LinkedIn** Featured or About
- [ ] Demo video link (optional)

Done — you can paste the GitHub URL in any application.
