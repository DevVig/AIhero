# Releasing AIhero

## Versioning

The shipped bundle version lives in [`Scripts/make_app.sh`](../../Scripts/make_app.sh)
(`CFBundleShortVersionString` / `CFBundleVersion`, currently `0.1.0`).

The running binary reports that string via `AIhero --version`. A bare
`swift run` build falls back to `0.1-dev` when no Info.plist is present.

## Open-source tag (no Apple cert required)

1. Confirm green CI and local proof:

   ```bash
   swift build && swift test
   Scripts/make_app.sh release
   dist/AIhero.app/Contents/MacOS/AIhero --version   # expect 0.1.0
   ```

2. Bump the version strings in `Scripts/make_app.sh` if needed.
3. Commit, tag, push:

   ```bash
   git tag -a v0.1.0 -m "AIhero v0.1.0"
   git push origin HEAD --tags
   ```

4. Optional: attach an unsigned `dist/AIhero.app` zip to the GitHub Release for
   curious builders. Prefer pointing people at `swift run` / `make_app.sh`.

## Signed + notarized DMG (cert-gated)

Requires:

- Apple **Developer ID Application** certificate installed in the keychain
- One-time Notary credentials:

  ```bash
  xcrun notarytool store-credentials AIhero \
    --apple-id "you@example.com" \
    --team-id TEAMID \
    --password "app-specific-password"
  ```

- A square app icon PNG (e.g. from MagicPath), **or** an existing
  `Scripts/AppIcon.icns`

Then:

```bash
# Icon PNG → .icns is handled inside release.sh when you pass a PNG path
DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)" \
  Scripts/release.sh path/to/icon.png
```

`Scripts/release.sh` orchestrates icon → `make_app.sh release` →
`sign_app.sh` (hardened runtime, notarize, staple, DMG).

Attach the resulting DMG to the GitHub Release. Do **not** commit secrets,
`.p12` files, or notary passwords to the repo.

## Privacy reminder

Shipping a binary does not change the threat model: no uploads, no API keys in
the app, read-only consent-gated activity. See [SECURITY.md](../../SECURITY.md).
