# YenkasaAI

YenkasaAI is a Flutter control-plane application for chat, knowledge
ingestion, analytics, moderation, session management, and AI operations.

## Requirements

- Flutter/Dart compatible with the SDK constraint in `pubspec.yaml`
- A running YenkasaAI-compatible backend for authenticated and networked flows
- Android Studio/Xcode when building mobile targets

## Run locally

```bash
flutter pub get
flutter run \
  --dart-define=YENKASA_ENV=development \
  --dart-define=YENKASA_AI_API_BASE_URL=http://127.0.0.1:8008 \
  --dart-define=YENKASA_AUTH_API_BASE_URL=http://127.0.0.1:8008 \
  --dart-define=YENKASA_PUBLIC_AI_ENGINE_BASE_URL=http://127.0.0.1:8008
```

The development defaults point to `127.0.0.1:8008`. Android emulators usually
need `10.0.2.2:8008` instead. Use the `--dart-define` values above to select
the correct host for the target device.

## Production builds

Production API URLs are selected explicitly with `YENKASA_ENV=production`.
Android release builds also require an ignored `android/key.properties` file;
the Gradle configuration refuses to produce a release artifact without real
signing credentials.

```bash
flutter build web --release --dart-define=YENKASA_ENV=production
flutter build apk --release --dart-define=YENKASA_ENV=production
```

Do not enable `YENKASA_ALLOW_INSECURE_AUTH_FALLBACK` in production. It exists
only for local troubleshooting when secure storage is unavailable.

## Development checks

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
```

GitHub Actions runs these Flutter checks, builds the production web bundle, and
runs the backend pytest suite on pushes and pull requests.

## Project structure

- `lib/core`: routing, configuration, storage, networking, and shared widgets
- `lib/features`: feature-specific presentation, domain, and data code
- `test`: Flutter unit and widget tests
- `.backend_work/backend`: bundled backend implementation and its tests
- `.yme_work` and `.external_staging`: integration/staging source snapshots;
  keep them documented and do not add credentials to them
- `docs`: backend wiring and deployment references

The backend and staging directories are tracked intentionally for the current
monorepo workflow. If they become independently deployed services, split them
into separate repositories or clearly named top-level packages in a follow-up.

## Security

See [SECURITY.md](SECURITY.md) for credential and vulnerability-reporting
guidance. Never commit `.env` files, service-account keys, Android signing
files, or authentication tokens.
