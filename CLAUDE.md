# ImmichView (Immich client for Roku)

A Roku channel (BrightScript + SceneGraph) that acts as a client for a self-hosted Immich server, plus a companion screensaver app built from the same repo. Developed by sideloading; being prepared for the Roku Channel Store (see PUBLISHING.md for the checklist).

## Goals

1. Browse albums and the photo timeline
2. Full-screen photo viewing with slideshow
3. Video playback
4. Search (smart/CLIP search, people)
5. Roku system screensaver showing photos from the library

## Setup (answered 2026-10-09)

- Immich server v3.3.1, reached over HTTPS (reverse proxy) and on the LAN.
- Rokus: a mix of HD and 4K models; dev device is a Streaming Stick 4K (3820EU), Roku OS 15.1.4.
- Dev Roku IP/password, test server URL and API key live in the git-ignored `.env` (see `.env.example`).
- ECP "Control by mobile apps" is Permissive, so `tools/drive.ps1` can send remote keys.

## Dev workflow

- `.\deploy.ps1` zips and sideloads (curl.exe, no Node). Sideloading wipes the channel registry.
- `.\tools\relaunch.ps1` relaunches with `serverUrl`/`apiKey` launch params from `.env` (restores the profile) and prints the debug console, which shows compile errors.
- `.\tools\screenshot.ps1`, `.\tools\drive.ps1 -Steps 'Up,Right,Down'` (screenshots per step into `out\drive.png`). Key names: `Info` is the `*` button (opens Settings on Home), `Lit_x` types a character into a keyboard dialog.
- **Two apps:** Roku only allows screensavers as standalone apps (bundling one blocks publishing), so the screensaver is a separate channel, **ImmichView Screensaver** (`manifest.screensaver`: `source/screensaver.brs`, `source/common`, `components/screensaver`, `components/tasks`, ProgressRing, a few images). The app's `manifest` must not have `screensaver_title`. Both are signed with the same key, so they share a registry: the screensaver reads ImmichView's active user and the screensaver options set in ImmichView's Settings.
- `.\deploy.ps1 -Screensaver` / `.\tools\package.ps1 -Screensaver` build the screensaver app. A Roku holds one sideloaded app, so it replaces the dev ImmichView; `.\deploy.ps1` puts the app back. With the screensaver sideloaded, `.\tools\relaunch.ps1 -Screensaver` shows it straight away (a DEV-only `Main` in `screensaver.brs`; release builds have none, as Roku requires).
- Dev vs release: the manifest has `bs_const=DEV=false`; `deploy.ps1` rewrites it to `true` in the zip unless `-Release`. `#if DEV` guards the dev launch params and `logDebug`. Never ship a DEV build.
- `.\tools\deeplink.ps1 -ContentId <asset id> [-MediaType movie] [-Running]` tests deep links at launch (ECP /launch) or while running (ECP /input → roInput).
- **Test only on the Guest Bedroom Roku (10.10.10.163, the default `ROKU_HOST`).** Don't deploy to, drive or screenshot the Living Room Roku (10.10.10.164); it's a household TV. The scripts' `-RokuHost` option exists, but don't point it there unless Alex asks.
- `.\tools\make-images.ps1` regenerates the small UI images (play icon, focus frames, masks, pill, countdown ring, and the title logo cropped from `art/ImmichView-icon.png`). Channel posters and splash screens in `images/` are supplied artwork (from the brand kit); don't regenerate them.
- The focus highlight is a plain white outline (`focus.9.png`, `focus-ring.png`). A soft glow was tried and rejected; keep the outline.
- BrightScript reserves some identifiers that look like ordinary names: `pos`, `tab` caused compile errors.
- Dot-notation (`aa.pinSalt = x`) stores lowercase keys and `ParseJson` dictionaries are case-sensitive, so `Delete`/lookups by string must use the lowercase key.
- Don't open the next dialog from inside a dialog's `wasClosed` observer: Roku clears `scene.dialog` afterwards and dismisses it. `PinPrompt` reports its result via a short Timer for this reason.
- `drive.ps1` sends a step's keys 250 ms apart; put a key that opens a dialog in its own step, or the following keys can be lost.
- The screensaver manifest must not have `title=` (only `screensaver_title`), and its release source must contain no `Main`: either makes Static Analysis treat it as an app with an in-channel screensaver (Req 4.5). The dev `Main` lives in `source/screensaver-dev.brs`, which release builds leave out.
- Certification (from 1 Oct 2026): keep `rsg_version=1.3` in both manifests and the memory monitor (`source/common/Memory.brs`) in both apps' main loops.
- Dev-installer screenshots don't capture the video plane: playing video shows as black, only the trick-play UI is visible.

## Tech stack and tooling

- **Language:** BrightScript, SceneGraph XML components. BrighterScript is acceptable if it simplifies the code, but compile to plain BrightScript.
- **Editor/debug:** VS Code with the RokuCommunity "BrightScript Language" extension (launch.json deploys and attaches the debugger).
- **Deploy:** `roku-deploy` (npm) or the extension's built-in deploy. Zip the project and sideload to `http://<roku-ip>` (dev installer). Debug console via telnet on port 8085.
- **Linting:** `bslint` if using BrighterScript.

## Project layout

```
manifest              ' ImmichView
manifest.screensaver  ' ImmichView Screensaver (deploy.ps1 writes it into that zip as manifest)
source/
  main.brs            ' Sub Main() – app entry
  screensaver.brs     ' Sub RunScreenSaver(params) – screensaver app entry
  common/             ' Shared helpers (both apps), incl. DevLaunch.brs (dev launch params)
components/
  MainScene.xml/.brs
  screens/            ' LoginScreen, HomeScreen (Photos/Albums/People/Search tabs), CollectionScreen (album or person), PhotoViewer, VideoPlayer, SettingsScreen, ProfilePickerScreen (Who's watching), ScreensaverSourceScreen
  tasks/              ' ImmichApiTask and any other Task nodes
  widgets/            ' JustifiedGrid, TimelineView (timeline buckets or smart search), TabBar, AppTitle, IconPill, UserMenu, OptionsPanel, PinPrompt, ProfileTile, ProgressRing, ListItem, AlbumTile, PeoplePane, PersonTile, SearchPane, AssetListSource
  screensaver/        ' ScreensaverScene and its components
images/               ' Icons, splash, focus art (shipped)
art/                  ' Brand kit: logo SVGs and the icon PNG that make-images.ps1 crops the title logo from (not shipped)
```

## Architecture rules

- **All network I/O runs in Task nodes**, never on the render thread. One generic `ImmichApiTask` takes `{method, path, body}` and returns parsed JSON or an error code via an observed field.
- **Authentication:** Immich API key sent as the `x-api-key` header. Users are profiles `{id, name, serverUrl, apiKey, pinSalt?, pinHash?}` (optional PIN stored as salted SHA-256; a household privacy lock, not security) stored as JSON in `roRegistrySection("immich")` (`profiles`, `activeProfile`); see `source/common/Settings.brs`. Don't use username/password login; typing on a remote is painful.
- **Image loading:** Poster and Video nodes need the auth header too. Create an `roHttpAgent`, `AddHeader("x-api-key", key)`, and call `node.setHttpAgent(agent)` on every Poster and Video node. Share one agent per grid/screen: creating one per tile (each loading the CA bundle) tripped the render-thread execution timeout.
- **Memory:** Roku texture memory is tight. Always set `loadWidth`/`loadHeight` on Posters, use Immich's small thumbnails for grids and preview size for full screen, and never load originals into a Poster. Recycle grid items (MarkupGrid/RowList) rather than creating thousands of nodes.
- **Pagination:** Album and timeline contents can be large. Fetch in pages and load more as focus nears the end of a grid.
- **Navigation:** maintain a screen stack in MainScene. Back closes the current screen. Back on the home screen exits.
- **Errors:** handle unreachable server, 401 (bad or expired key) and timeouts with a clear on-screen message and a path back to settings.

## Immich API (verify every endpoint against the user's server version)

Reference: https://api.immich.app and the OpenAPI spec for the server's version. Endpoints below are a starting point and may have changed:

| Purpose | Endpoint (likely) |
|---|---|
| Connectivity check | `GET /api/server/ping`, `GET /api/server/version` |
| Validate key / current user | `GET /api/users/me` |
| List albums | `GET /api/albums` |
| Album contents | v3.3.1: `GET /api/albums/{id}` no longer embeds assets; use the timeline endpoints with `albumId=` |
| Timeline buckets | `GET /api/timeline/buckets`, `GET /api/timeline/bucket` (verified v3.3.1: `timeBucket=YYYY-MM-DD` as returned; bucket data is column arrays `id[]`, `ratio[]`, `isImage[]`, `duration[]` in ms; library timeline uses `visibility=timeline&withPartners=true&withStacked=true`) |
| Thumbnail / preview | `GET /api/assets/{id}/thumbnail?size=thumbnail\|preview` (verified: thumbnail is WebP and renders on Roku OS 15; preview is JPEG) |
| Asset metadata (EXIF) | `GET /api/assets/{id}` |
| Video stream (transcoded if available) | `GET /api/assets/{id}/video/playback` (verified v3.3.1: MP4 with byte ranges; used with `streamFormat=mp4`). The HLS endpoints (`/video/stream/main.m3u8`) need real-time transcoding, which is off on this server (400). Sampled library: mostly H.264, a few HEVC |
| Smart search | `POST /api/search/smart` |
| Metadata search | `POST /api/search/metadata` |
| Random assets (screensaver) | `POST /api/search/random` (verified v3.3.1: `{size, type: "IMAGE", withExif, visibility}` or `albumIds` for one album; returns an array of assets) |
| People | `GET /api/people`, plus person filter in search |
| Memories ("on this day") | `GET /api/memories?for=YYYY-MM-DD` (verified: memories of type `on_this_day` with `data.year` and `assets[]`) |

Format notes:
- Roku can't decode HEIC. Always use Immich's generated thumbnail/preview images (JPEG/WebP), never originals. Confirm WebP renders on the target Roku OS version; if not, request JPEG or fall back.
- Video: Roku plays H.264 MP4 everywhere and HEVC on 4K models. Prefer the playback endpoint, which serves Immich's transcode. On HD-only Rokus, the user may need Immich's transcode policy set to cover HEVC; surface a helpful message when playback fails.

## Feature specs

### Login / Settings
- Enter server URL and API key with the Roku keyboard dialog. Validate with ping + `/users/me` before saving.
- Settings screen: change server or key, slideshow interval, screensaver source (random / specific album / memories), show/hide info overlay.

### Home
- Rows: Albums, Recent, Memories (if available), People, and a Search entry.

### Album grid
- MarkupGrid of thumbnails, paged loading, play-icon and duration badge on videos.

### Photo viewer
- Full screen preview image, left/right to move between items, OK toggles info overlay (date, location, camera), Play starts or stops slideshow.
- Preload the next and previous images, crossfade between them.

### Video player
- Standard Roku Video node with trick play. Return to the same position in the grid afterwards.

### Search
- Keyboard and voice input (voice comes through the keyboard dialog). Smart search results shown in the same grid component. People search by face thumbnails.

### Screensaver
- Separate app (ImmichView Screensaver, `manifest.screensaver`) with `screensaver_title=ImmichView`. Entry point `Sub RunScreenSaver(params)` in `source/screensaver.brs`, which creates `ScreensaverScene`. No user input, deep links or `Main` in release builds (Roku screensaver rules).
- Uses the stored server URL and key (same registry section). If not configured, show a simple "Open Immich app to set up" message.
- Photos only by default. Fetch a batch of random assets (or album/memories, per setting), cycle with crossfade at the configured interval, refill the batch when it runs low. Include a slow pan/position shift to avoid burn-in.

## Build phases (each must run on a real Roku before moving on)

1. **Skeleton + login:** manifest, MainScene, ApiTask, settings stored in registry, connection check. Acceptance: enter URL and key, see "Connected as <name>".
2. **Albums:** home screen with album row, album grid with thumbnails and paging. Acceptance: browse an album of 500+ photos without crashes or memory warnings.
3. **Photo viewer + slideshow.**
4. **Video playback.**
5. **Search** (smart search, then people).
6. **Screensaver.**
7. **Polish:** focus art, splash, icons, error states, timeline view.

## Conventions

- Keep BrightScript functions small. One component per file pair (`.xml` + `.brs`).
- Log through a single `logDebug()` helper that can be switched off for release builds.
- No credentials in source or committed config. Keep dev Roku IP and password in a git-ignored `.env` used by the deploy script.
