# ImmichView

A Roku channel for browsing a self-hosted [Immich](https://immich.app) library (tested with Immich v3.3.1). See [CLAUDE.md](CLAUDE.md) for the design notes.

## Features

- **Photos:** your whole library as a timeline grouped by month, in a justified grid like the Immich web app
- **All / Photos / Videos filter** in the `*` View options panel, applied everywhere and remembered
- **Albums** and **People** (named faces), each opening the same month-grouped grid
- **Search:** Immich smart search by what's in the photo, typed or spoken with the Roku keyboard's mic
- **Photo viewer:** full-screen photos with crossfade, an info overlay (date, place, camera) and a slideshow
- **Videos:** played with the standard Roku player and trick play
- **Screensaver:** random photos, today's memories or one album, with a slow drift against burn-in
- **Multiple users:** each with their own server and API key, switched from the user menu at the top right

## Remote

| Where | Button | Does |
|---|---|---|
| Home | Up / Down | Move between the top-right pills, the tabs and the content |
| Top-right pills | OK | User menu (switch user) or Settings (gear) |
| Home, albums, people | `*` | View options: show All, Photos or Videos |
| Photo grids | ⏪ / ⏩ | Jump four rows |
| Photo viewer | OK (or Up/Down) | Show or hide info |
| Photo viewer | Play | Start or stop the slideshow |
| Photo viewer, on a video | OK / Play | Play the video |

Turn on the screensaver in Roku **Settings > Theme > Screensavers > ImmichView**; choose its photos in ImmichView's Settings.

## Immich server tips

- Create an API key in the Immich web app under **Account Settings > API Keys**.
- Roku can't rotate video and HD Rokus can't play HEVC. Set **Administration > Settings > Video Transcoding** to transcode videos above the target resolution (720p) with only H.264 accepted, then run **Jobs > Transcode Videos > Missing**. ImmichView plays Immich's transcodes automatically.
- The first smart search after the server has been idle can take up to a minute while Immich loads its model.

## Development setup

1. Enable developer mode on the Roku (Home ×3, Up ×2, Right, Left, Right, Left, Right) and set a dev password.
2. Copy `.env.example` to `.env` and fill it in. `.env` is git-ignored.
3. Deploy, either:
   - from VS Code with the BrightScript Language extension: **Run > Start Debugging** ("Roku: deploy and debug"), or
   - from PowerShell: `.\deploy.ps1`, then `.\tools\relaunch.ps1` to sign in from `.env` and see the debug log
4. In the channel, enter your server URL and an API key.

More tools: `tools\screenshot.ps1`, `tools\drive.ps1` (scripted remote keys), `tools\relaunch.ps1 -Screensaver`. Debug output: `telnet <roku-ip> 8085`.

The dev launch parameters (`serverUrl`, `apiKey`, `screensaver`) only exist in dev builds (`bs_const DEV=true`, which `deploy.ps1` sets); release builds compile them out.

## Privacy, support and licence

- [Privacy policy](https://apinner.github.io/RokuImmichClient/privacy.html) and [support page](https://apinner.github.io/RokuImmichClient/) (source in `docs/`).
- MIT licensed; see [LICENSE](LICENSE).
- ImmichView is an unofficial app. It is not affiliated with or endorsed by Immich or FUTO.
