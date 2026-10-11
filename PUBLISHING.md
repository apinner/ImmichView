# Publishing ImmichView to the Roku Channel Store

Checklist for taking ImmichView from a sideloaded dev channel to a public channel.

There are **two store apps**: ImmichView and **ImmichView Screensaver**. Roku only allows screensavers as standalone apps; an app with `screensaver_title` in its manifest is blocked from publishing (the bundled screensaver was split out on 2026-10-11). Both are built from this repo and must be signed with the same key so the screensaver can read ImmichView's users (apps packaged under one developer ID share a registry).
Owner: **code** = in this repo, **Alex** = needs your accounts, decisions or details.

## 1. Certification requirements in the app (code)

- [x] **Release vs dev builds.** Release builds turn off debug logging and the dev-only launch
      parameters (`serverUrl`/`apiKey`, and the screensaver's dev `Main`), which would let anyone on the
      network reconfigure the channel. Controlled by `bs_const=DEV` in the manifest; `deploy.ps1`
      builds dev by default.
- [x] **Launch beacons.** `AppLaunchComplete` when Home has rendered (or deep-linked playback
      starts); `AppDialogInitiate`/`AppDialogComplete` around the sign-in screen shown at launch.
- [x] **Deep linking.** `supports_input_launch=1`; handle `contentId` (an Immich asset ID) and
      `mediaType` at launch and through `roInput` while running. Videos play straight away,
      photos open in the viewer, invalid links land on Home without errors.
- [x] **Signed package script.** `tools/package.ps1` installs the release build, has the Roku sign it, and saves `out/packages/ImmichView-<version>.pkg`; `-Screensaver` does the same for `ImmichViewScreensaver-<version>.pkg`.
- [x] **Screensaver as its own app** (`manifest.screensaver`; no user input, deep links or `Main` in release builds).
- [ ] Check on a Roku that the published screensaver reads ImmichView's users (shared registry). Sideloading can't show this, since a Roku holds one sideloaded app.
- [ ] **Static Analysis.** Run Roku's analyzer (in the Developer Dashboard upload, or the CLI
      tool) and fix anything it reports. First run (ImmichView 1.0.2, 2026-10-11), fixed in 1.0.3:
      - Memory monitoring (required from 1 Oct 2026): `source/common/Memory.brs` uses roAppMemoryMonitor
        (with the low general memory event as fallback); warnings reach MainScene, which tells screens to free caches.
      - `rsg_version=1.3` in both manifests (required from 1 Oct 2026); in the Dashboard set the
        **minimum firmware to 15.1**.
      - getUserData / Customer Account errors: ImmichView has no accounts of its own (users enter their own
        server and API key), so in the Dashboard set **Customer Account Requirement to No**; no RFI needed.
      - Screensaver 1.0.2 got two Req 4.5 "in-channel screensaver" errors because its manifest had `title=`
        (marks a package as an app). 1.0.3 has only `screensaver_title`, no `Main` in release builds, and splash screens.
- [x] Pre-certification test pass on the test Roku: launch about 2 s to AppLaunchComplete (limit 15 s),
      Back on Home exits, unreachable server and rejected key show clear messages with a path to
      Settings, add/remove user, screensaver, stress-tested grids and viewer.

## 2. Accounts and signing (Alex)

- [ ] Roku developer account (developer.roku.com), enrolled to publish channels.
- [x] Generate the signing key on one Roku (`genkey` over telnet port 8080). Keep the
      **DevID and password** safe (they go in `.env`, never in git) and keep the first signed
      package: it's the only way to restore the key onto another Roku (`rekey`).

## 3. Listing in the Developer Dashboard (Alex, with help)

- [ ] Channel name: **ImmichView** (decided). Before publishing, email the Immich team (address in the
      Commercial Guidelines section of docs.immich.app/FAQ) as notification; the app and listing say
      it's unofficial and not affiliated with or endorsed by Immich or FUTO.
- [ ] Description, category, keywords, rating questionnaire, for both apps. The screensaver's listing should say it needs ImmichView set up first.
- [ ] Screenshots (taken from the app with `tools/screenshot.ps1`).
- [x] Privacy policy and support pages (source in `docs/`), live on GitHub Pages from the public repo
      apinner/ImmichView: https://apinner.github.io/ImmichView/privacy.html and
      https://apinner.github.io/ImmichView/ (support).
- [x] Terms of use page (Roku requires one): https://apinner.github.io/ImmichView/terms.html, covering both apps.
- [ ] Support contact (URL, email, phone) and admin/technical contacts.
- [ ] **Reviewer access.** Roku's testers need a working Immich server URL and API key with
      sample photos and videos (a demo account, not your personal library).
- [ ] Deep-link test IDs for the dashboard (asset IDs from the demo account: one photo,
      one video).

## 4. Submit

- [ ] Upload both signed packages, pass Static Analysis, submit for review, answer any feedback. Publish ImmichView first (or together): the screensaver is useless without it.
