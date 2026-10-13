# Pisacoma iOS app — design

**Date:** 2026-10-13 · **Repo:** `crispinekkovendas-blip/pisacoma-ios` (public) · **Builds:** GitHub Actions macOS runners only; this PC runs git and Node. **Reference implementation:** the Android app `crispinekkovendas-blip/pisacoma-android` (`E:\pisacoma-android`), itself a mirror of the Qwik site https://quiz-qwik.vercel.app.

## What the user asked

> Can you make a swift native ios app, that I can install directly to Iphone without app store

Install path chosen by the user: **Apple Developer Program ($99/year, bought by the user)** → ad-hoc signed IPA for registered iPhones, installed from a link. Until the certificate and profile are in the repo secrets, CI produces an unsigned IPA so the build never waits on the purchase.

## Decisions

1. **SwiftUI, iOS 16+**, one app target `Pisacoma`, bundle id `pe.pisacoma.iglesia`. Project generated on the runner by **XcodeGen** from `project.yml` (no `.xcodeproj` in git). Dependencies via Swift Package Manager: `lottie-ios` (the home scenes). Everything else is the platform: `AVPlayer` (hymn audio, background audio mode, now-playing info), `WKWebView` (YouTube IFrame player, OpenStreetMap), `URLSession`, `UserDefaults`, `Codable`.
2. **Parity with the Android app, screen for screen** — same routes, copy, tokens (`Tokens.swift` carries the site's CSS values under the same names), fonts (Fraunces, Inter, DM Sans, Playfair, the `.ttf` files already converted for Android), user-state keys (`biblia:bk<b>:ch<c>:notes`, `egw:<slug>:ch<n>:done`, `quiz.<slug>.v1`, `inicio.videos.pausa`, `contenido.modo`, …) in `UserDefaults` suite `pisacoma`, and the same pure logic (Zmanim, Bible refs, lesson markdown, search ranking, quiz state machine, video catalogue, announcements CSV, Wiktionary) with the same unit tests ported to XCTest.
3. **Content** is shared with Android: the iOS app downloads from the same origin, `https://raw.githubusercontent.com/crispinekkovendas-blip/pisacoma-android/main/content/`, using the same `manifest.json`. The bundled resources (home posters + Lottie + Lottie images, EGW covers, the small indices, the manifest) are copied from the Android repo's `app/src/main/assets/` by `tools/sync-content.mjs` into `Pisacoma/Content/` (a folder reference, so paths like `data/biblia/43.json` stay the same). Fonts are copied from `app/src/main/res/font/`.
4. **Descargas works exactly as on Android:** first open → `/descargas` only; four modes `todo` / `esencial` / `uso` / `en-linea`; `ContentStore` (bundled → `Application Support/content/<path>` → network, size-verified, atomic writes, nothing written in `en-linea`); `ContentDownloader` (sequential, three attempts, resume on next open via `contenido.pendiente`); one «Sin conexión» notice over any screen when a file is neither stored nor reachable.
5. **Navigation:** `Route` enum mirroring the site paths (`parse(_ href:)` for search results and universal links `https://quiz-qwik.vercel.app/<path>?query`), `NavigationStack` with a path of routes, `SiteScaffold` (top bar, full-screen menu, footer) around every screen, `Skin` per route (Pastel / Dark / Home).
6. **Screens** (same files as Android, one SwiftUI view per screen): Home (eleven Lottie scenes, pause button, actions), Visítanos, Himnario index / hymn / projector, Videos catalogue / player, Escuela Sabática overview / lesson (markdown blocks, Bible reference sheet, notes, done marks), Biblia (book/chapter picker, verse list, notes, bookmarks, share), Diccionario (Wiktionary), EGW catalogue (rails, covers, continue) / book reader, Quiz index / quiz, ¿Quién? (wheel + Apuntador), Buscar, Descargas.
7. **CI** (`.github/workflows/ios.yml`, `macos-15` runner):
   - `build` on every push: `brew install xcodegen`, `xcodegen generate`, unit tests on an iPhone simulator (`xcodebuild test`), then an unsigned Release build (`CODE_SIGNING_ALLOWED=NO`) packaged as `Pisacoma-unsigned-<run>.ipa` artifact (zip of `Payload/Pisacoma.app`).
   - `ui` on `workflow_dispatch`: XCUITest on the simulator with screenshots exported as artifact `ui-<run>`.
   - `release` on `v*` tags: when the secrets `IOS_CERT_P12` (base64), `IOS_CERT_PASSWORD`, `IOS_PROFILE` (base64 `.mobileprovision`, ad-hoc, with the registered iPhones) and `IOS_TEAM_ID` exist, import them into a temporary keychain, archive with manual signing, `exportArchive` with `method: ad-hoc`, attach `Pisacoma-<tag>.ipa` to the GitHub Release, and publish `manifest.plist` + `index.html` + the IPA to the `gh-pages` branch so the phone installs it from `https://crispinekkovendas-blip.github.io/pisacoma-ios/` (an `itms-services://` link). Without the secrets, the release carries the unsigned IPA and a note.
8. **Tests.** XCTest unit tests for every ported pure module (same cases as the Kotlin tests), the models against the real bundled/content files, `ContentStore` / `ContentDownloader` / `Manifest`, `Route.parse`, `QuizState`. XCUITest for the chrome, Descargas first run, hymnal, lesson, Bible, EGW, quiz, wheel, home, with screenshots reviewed against the Android ones.
9. **Not done by the assistant:** enrolling in the Developer Program, creating the certificate and the ad-hoc profile, registering the iPhone's UDID, adding the secrets. The README's «Firmar» section walks through it.

## Out of scope

Push notifications, iPad layouts, App Store submission, Siri/Widgets, offline video.
