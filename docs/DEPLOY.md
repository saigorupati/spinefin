# Deploying to TestFlight

Releases are handled by [fastlane](https://fastlane.tools). The `beta` lane
regenerates the Xcode project, signs with **match**-managed certificates, picks
the next build number from TestFlight, archives, and uploads.

```
fastlane beta        # run locally
```

CI runs the same lane on every `v*` tag (see `.github/workflows/testflight.yml`).

---

## One-time setup

### 1. App Store Connect API key
App Store Connect → **Users and Access → Integrations → App Store Connect API** →
create a key with the **App Manager** role. Download the `.p8` once and note the
**Key ID** and **Issuer ID**.

### 2. A private repo for signing assets (match)
Create an **empty private** repo, e.g. `spinefin-certs`. match stores the
encrypted distribution certificate + provisioning profile there.

### 3. Local env
```bash
cp fastlane/.env.example fastlane/.env
# fill in ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT (base64 of the .p8),
# MATCH_GIT_URL, MATCH_PASSWORD
```

Bootstrap the certs (creates + uploads them to the certs repo):
```bash
bundle install
bundle exec fastlane match appstore        # first run; creates the cert/profile
```

### 4. Ship
```bash
bundle exec fastlane beta
```

---

## GitHub Actions

Trigger: push a tag (`git tag v1.0.1 && git push origin v1.0.1`) or run the
**TestFlight** workflow manually from the Actions tab.

Add these under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | API Key ID |
| `ASC_ISSUER_ID` | API Issuer ID |
| `ASC_KEY_CONTENT` | base64 of the `.p8` (`base64 -i AuthKey_XXXX.p8`) |
| `MATCH_GIT_URL` | HTTPS URL of the certs repo |
| `MATCH_PASSWORD` | match encryption passphrase |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 of `user:personal_access_token` for the certs repo |

The runner needs Xcode 26+ (the app targets iOS 26). `macos-15` with
`latest-stable` is used; pin the Xcode version in the workflow if a specific one
is required.

---

## Versioning

- **Build number** is set automatically (latest TestFlight build + 1) — you never
  bump it by hand.
- **Marketing version** (`1.0.0`) lives in `project.yml` (`MARKETING_VERSION`).
  Bump it there for a new user-facing release, then `xcodegen generate`.
