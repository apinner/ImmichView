# Immich Client for Roku

A Roku channel (BrightScript + SceneGraph) that acts as a client for a self-hosted Immich server. Sideloaded via Roku developer mode; not intended for the Roku Channel Store.

## Goals

1. Browse albums and the photo timeline
2. Full-screen photo viewing with slideshow
3. Video playback
4. Search (smart/CLIP search, people)
5. Roku system screensaver showing photos from the library

## Open questions (ask the user before Phase 1 if not yet answered)

- Immich server version (check `GET /api/server/version`). The API changed significantly across v1 → v2 → v3; current releases are 3.x.
- Server reachable on LAN only (http://192.168.x.x:2283) or via HTTPS reverse proxy?
- Roku model(s) in use (HD vs 4K matters for HEVC playback and texture memory).
- Is developer mode enabled on the Roku, and what is its IP and dev password?

## Tech stack and tooling

- **Language:** BrightScript, SceneGraph XML components. BrighterScript is acceptable if it simplifies the code, but compile to plain BrightScript.
- **Editor/debug:** VS Code with the RokuCommunity "BrightScript Language" extension (launch.json deploys and attaches the debugger).
- **Deploy:** `roku-deploy` (npm) or the extension's built-in deploy. Zip the project and sideload to `http://<roku-ip>` (dev installer). Debug console via telnet on port 8085.
- **Linting:** `bslint` if using BrighterScript.

## Project layout

```
manifest
source/
  main.brs            ' Sub Main() – app entry
  screensaver.brs     ' Sub RunScreenSaver(params) – screensaver entry
components/
  MainScene.xml/.brs
  screens/            ' LoginScreen, HomeScreen, AlbumGrid, PhotoViewer, VideoPlayer, SearchScreen, SettingsScreen
  tasks/              ' ImmichApiTask and any other Task nodes
  widgets/            ' Reusable tiles, badges, overlays
  screensaver/        ' ScreensaverScene and its components
images/               ' Icons, splash, focus art
```

## Architecture rules

- **All network I/O runs in Task nodes**, never on the render thread. One generic `ImmichApiTask` takes `{method, path, body}` and returns parsed JSON or an error code via an observed field.
- **Authentication:** Immich API key sent as the `x-api-key` header. Store server URL and API key in `roRegistrySection("immich")`. Don't use username/password login; typing on a remote is painful.
- **Image loading:** Poster and Video nodes need the auth header too. Create an `roHttpAgent`, `AddHeader("x-api-key", key)`, and call `node.setHttpAgent(agent)` on every Poster and Video node.
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
| Album contents | `GET /api/albums/{id}` |
| Timeline buckets | `GET /api/timeline/buckets`, `GET /api/timeline/bucket` |
| Thumbnail / preview | `GET /api/assets/{id}/thumbnail?size=thumbnail\|preview` |
| Asset metadata (EXIF) | `GET /api/assets/{id}` |
| Video stream (transcoded if available) | `GET /api/assets/{id}/video/playback` |
| Smart search | `POST /api/search/smart` |
| Metadata search | `POST /api/search/metadata` |
| Random assets (screensaver) | `POST /api/search/random` |
| People | `GET /api/people`, plus person filter in search |
| Memories ("on this day") | `GET /api/memories` |

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
- Manifest: `screensaver_title=Immich Photos`. Entry point `Sub RunScreenSaver(params)` in `source/screensaver.brs`, which creates `ScreensaverScene`.
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
