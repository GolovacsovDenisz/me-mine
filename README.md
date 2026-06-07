# Me Mine

Personal journal app with mood tracking, calendar, attachments (photos, files, location), and **AI period summaries** powered by Gemini on Firebase Cloud Functions (API key never ships in the mobile client).

## Stack

- **Flutter** (Dart 3.10+), **Riverpod**, **GoRouter**
- **Firebase** — Auth, Firestore, Storage, Callable Functions (europe-west1)
- **Gemini** — server-side period analysis with warm, human-toned prompts
- **geolocator** / **geocoding**, local notifications, optional app passcode

## Features

- Daily entry: text, 1–5 stars, multiple photos, files, place label
- Calendar month view with entry highlights and swipe between months
- Analytics charts (day / week / month) + saved AI summaries per period
- Settings: theme, reminders, AI tone instructions, account (email / password)

## Demo

[Watch demo on YouTube](https://www.youtube.com/watch?v=REPLACE_WITH_YOUR_VIDEO_ID)

## Screenshots

| Home | Calendar |
|:---:|:---:|
| ![Home](docs/screenshots/home.jpg) | ![Calendar](docs/screenshots/calendar.jpg) |

| Analytics | AI summary |
|:---:|:---:|
| ![Analytics](docs/screenshots/analytics.jpg) | ![AI summary](docs/screenshots/AI.jpg) |

## Getting started (developers)

1. Install [Flutter](https://docs.flutter.dev/get-started) and Firebase CLI.
2. Clone the repo and run `flutter pub get`.
3. Use your own Firebase project or the bundled client config files (`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`).
4. Deploy Cloud Functions and set secret `GEMINI_API_KEY`:

   ```bash
   cd functions && npm install
   firebase functions:secrets:set GEMINI_API_KEY
   firebase deploy --only functions:analyzePeriod
   ```

5. Run the app: `flutter run`.

## Security note

Firebase **client** API keys in this repo are expected for mobile apps. Restrict them in Google Cloud (package name / bundle ID). **Do not** commit `.env` or Gemini keys; production AI runs only in Cloud Functions.

## License

Private / portfolio — add a license if you open-source (e.g. MIT).
