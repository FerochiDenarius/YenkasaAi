# Contributing to YenkasaAI

## Local setup

1. Install the Flutter SDK version compatible with `pubspec.yaml`.
2. Run `flutter pub get`.
3. Start the backend locally, or provide an API endpoint with
   `--dart-define=YENKASA_AI_API_BASE_URL=...` and the corresponding auth/public
   endpoint defines.
4. Run `flutter analyze` and `flutter test` before opening a pull request.

## Pull requests

- Keep changes focused and explain user-visible behavior.
- Add or update tests for behavior changes.
- Do not commit credentials, `android/key.properties`, local environment files,
  build output, or generated tool directories.
- Run `dart format lib test tool` before submitting. CI enforces strict
  formatting on Dart files changed by the pull request.

## Release builds

Android release builds require a real `android/key.properties` file. The build
intentionally fails when signing credentials are missing; it never falls back to
the debug signing key.
