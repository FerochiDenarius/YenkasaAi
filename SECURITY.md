# Security policy

## Reporting a vulnerability

Please do not open a public issue for a suspected security vulnerability.
Contact the repository maintainers privately with the affected component,
reproduction steps, and potential impact.

## Security expectations

- Never commit API keys, service-account files, passwords, signing keys, or
  access/refresh tokens.
- Production builds must use `YENKASA_ENV=production` and a managed HTTPS API.
- The insecure `SharedPreferences` auth fallback is disabled by default. Only
  enable `YENKASA_ALLOW_INSECURE_AUTH_FALLBACK=true` for local troubleshooting.
- Rotate any credential that has been exposed in logs, source, or build output.
