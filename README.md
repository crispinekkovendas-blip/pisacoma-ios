# Pisacoma — iOS

Native iOS app (Swift + SwiftUI) of the Iglesia Adventista del Séptimo Día de Pisacoma site,
https://quiz-qwik.vercel.app, with the same screens, content and design as the Android app
(`crispinekkovendas-blip/pisacoma-android`). The first open asks what to keep on the phone so
the hymnals, Bible, Ellen G. White books and the quarterly read offline.

- Design: `docs/superpowers/specs/2026-10-13-ios-app-design.md`
- Plan: `docs/superpowers/plans/2026-10-13-ios-app.md`

## Builds (nothing runs on a PC)

| trigger | job | output |
|---|---|---|
| every push | `build` | unit tests on a simulator + unsigned `Pisacoma-unsigned-<run>.ipa` artifact |
| Run workflow (by hand) | `ui` | XCUITests on a simulator + screenshots `ui-<run>` |
| tag `v*` | `release` | ad-hoc signed IPA on a GitHub Release + install page on GitHub Pages (needs the secrets below) |

The Xcode project is generated on the runner by XcodeGen from `project.yml`.

## Firmar e instalar (Apple Developer Program)

Apple only installs apps signed with a developer identity. Once, by the account owner:

1. Enrol at https://developer.apple.com/programs/ (US$99/year) and note the **Team ID** (Membership details).
2. On any Mac, or through the developer site: create an **Apple Distribution** certificate, export it
   with its private key as a `.p12` with a password.
3. Register each iPhone's **UDID** (Finder → the phone → click the serial number to reveal it, or
   Settings → General → About with a UDID app) under Certificates, Identifiers & Profiles → Devices.
4. Create an App ID `pe.pisacoma.iglesia` and an **Ad Hoc** provisioning profile for it that
   includes the certificate and the devices; download the `.mobileprovision`.
5. Add four repository secrets (Settings → Secrets and variables → Actions):
   `IOS_CERT_P12` (the .p12, base64), `IOS_CERT_PASSWORD`, `IOS_PROFILE` (the .mobileprovision,
   base64), `IOS_TEAM_ID`.
6. Enable GitHub Pages for the repository from the `gh-pages` branch (Settings → Pages) after the
   first signed release creates it.
7. Push a tag (`git tag v0.1.0 && git push origin v0.1.0`). The release job signs the IPA,
   attaches it to the GitHub Release and publishes the install page:
   **https://crispinekkovendas-blip.github.io/pisacoma-ios/** — open it in Safari on a registered
   iPhone and tap «Instalar Pisacoma».

A new iPhone means: register its UDID, regenerate the profile, update `IOS_PROFILE`, tag again.
Ad-hoc profiles last a year; a new tag before expiry renews the install.

## Content

`Pisacoma/Content/` (bundled) and `PisacomaTests/Content/` (the downloadable files, for the
tests) are copied from the Android checkout by `tools/sync-content.mjs`; `Pisacoma/Fonts/` too.
The phones download from the Android repository's `content/` folder, the same origin as Android.
