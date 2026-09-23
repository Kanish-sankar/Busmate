# BusMate Dev/Prod Setup Runbook (Completed)

## Status

This setup is completed end-to-end.

- Dev Firebase project: ready (`busmate-dev`)
- Prod Firebase project: ready (`busmate-b80e8`)
- Functions CI/CD guard: working
- APNs key setup: configured in both Firebase projects
- Secrets and IAM permissions: configured for GitHub Actions deploy

## What Was Implemented

### 1) App update system + adoption analytics
- Version check service and soft/hard update decision flow
- Adoption tracking in Firestore
- Admin adoption dashboard
- Write-throttling optimization

### 2) Safe dev/prod environment separation
- Environment resolver and entrypoints:
  - `main_dev.dart` -> dev
  - `main.dart` / `main_prod.dart` -> prod
- Background location handling made environment-aware
- Firebase aliases configured in `.firebaserc`

### 3) Function deployment automation
- GitHub Actions workflow: `.github/workflows/functions-deploy-guard.yml`
- Branch behavior:
  - `develop` -> deploy functions to `busmate-dev`
  - `main` -> deploy functions to `busmate-b80e8`
- Manual dispatch target supported: `dev` or `prod`

### 4) Local dev automation
- Dev dart-define setup script: `busmate_app/scripts/setup-dev-defines.ps1`
- Dev run script support and launch configs added

### 5) iOS push configuration
- APNs authentication key configured in both Firebase projects
- `busmate-dev`: Development + Production APNs auth key present
- `busmate-b80e8`: Development + Production APNs auth key present

## Current CI/CD Behavior

### Push to develop
- Workflow runs `deploy-dev`
- Functions deploy target: `busmate-dev`
- Prod remains untouched

### Push to main
- Workflow runs `deploy-prod`
- Functions deploy target: `busmate-b80e8`
- Dev remains untouched

### Manual run
- Actions -> Functions Deploy Guard -> Run workflow
- Select target: `dev` or `prod`

## Daily Development Workflow

1. Create feature/fix on `develop`
2. Test with dev app build
3. Push `develop` to deploy dev functions
4. Validate in dev environment
5. Merge to `main` only after validation
6. Push `main` to deploy prod functions
7. Release store binaries (Play Store/App Store) from prod build pipeline

## How To Run The App

### Dev app (connected to dev Firebase)
Run from `busmate_app` using dev entrypoint and dev defines:

`flutter run -t lib/main_dev.dart --dart-define-from-file=.dart_define.dev.json`

### Prod app (connected to prod Firebase)
Run normal prod entrypoint for production behavior:

`flutter run -t lib/main.dart`

## Important Notes

- Dev and prod are isolated by branch + Firebase project + service account.
- CI/CD here deploys Cloud Functions. App store publishing is a separate release step.
- Do not commit secret files or service-account keys.
- If APNs key is rotated in Apple, update it in both Firebase projects.

## Pending Optional Validation

- Real iPhone end-to-end push receive test (dev and prod) is pending only if no iPhone was available during setup.
- This is verification, not a setup blocker.

## Quick Recovery Checklist (if deploy fails later)

1. Confirm correct branch (`develop` vs `main`)
2. Confirm GitHub secret exists for target environment
3. Confirm target service account IAM roles in target project
4. Confirm Secret Manager access to required secrets
5. Confirm required Google APIs enabled in target project
6. Re-run workflow and inspect first `Error:` line
