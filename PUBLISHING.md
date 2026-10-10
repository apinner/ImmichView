# Publishing ImmichView to the Roku Channel Store

Checklist for taking ImmichView from a sideloaded dev channel to a public channel.
Owner: **code** = in this repo, **Alex** = needs your accounts, decisions or details.

## 1. Certification requirements in the app (code)

- [x] **Release vs dev builds.** Release builds turn off debug logging and the dev-only launch
      parameters (`serverUrl`/`apiKey`/`screensaver=preview`), which would let anyone on the
      network reconfigure the channel. Controlled by `bs_const=DEV` in the manifest; `deploy.ps1`
      builds dev by default.
- [x] **Launch beacons.** `AppLaunchComplete` when Home has rendered (or deep-linked playback
      starts); `AppDialogInitiate`/`AppDialogComplete` around the sign-in screen shown at launch.
- [x] **Deep linking.** `supports_input_launch=1`; handle `contentId` (an Immich asset ID) and
      `mediaType` at launch and through `roInput` while running. Videos play straight away,
      photos open in the viewer, invalid links land on Home without errors.
- [x] **Signed package script.** `tools/package.ps1` installs the release build, has the Roku sign it, and saves `out/packages/ImmichView-<version>.pkg`.
- [ ] **Static Analysis.** Run Roku's analyzer (in the Developer Dashboard upload, or the CLI
      tool) and fix anything it reports.
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
- [ ] Description, category, keywords, rating questionnaire.
- [ ] Screenshots (taken from the app with `tools/screenshot.ps1`).
- [x] Privacy policy and support pages (source in `docs/`), live on GitHub Pages from the public repo
      apinner/ImmichView: https://apinner.github.io/ImmichView/privacy.html and
      https://apinner.github.io/ImmichView/ (support).
- [ ] Support contact (URL, email, phone) and admin/technical contacts.
- [ ] **Reviewer access.** Roku's testers need a working Immich server URL and API key with
      sample photos and videos (a demo account, not your personal library).
- [ ] Deep-link test IDs for the dashboard (asset IDs from the demo account: one photo,
      one video).

## 4. Submit

- [ ] Upload the signed package, pass Static Analysis, submit for review, answer any feedback.
