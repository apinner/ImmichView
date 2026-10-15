# ImmichView

A Roku channel for browsing a self-hosted [Immich](https://immich.app) library (tested with Immich v3.3.1). See [CLAUDE.md](CLAUDE.md) for the design notes.

## Features

- **Photos:** your whole library as a timeline grouped by month, in a justified grid like the Immich web app, with a Jump to panel (years and months) for going straight to any month
- **All / Photos / Videos filter** in the `*` View options panel, applied everywhere and remembered
- **Albums**, **People** (named faces) and **Places** (every town and city in your photos), each opening the same month-grouped grid
- **Search:** Immich smart search by what's in the photo, typed or spoken with the Roku keyboard's mic
- **Photo viewer:** full-screen photos with crossfade, an info overlay (date, place, camera), optional names of the people in each photo, a choice of background beside photos that don't fill the screen (default, black, ambient glow or blur), and a slideshow with a slow Ken Burns zoom and pan and a countdown ring
- **Videos:** played with the standard Roku player and trick play
- **Screensaver** (the companion ImmichView Screensaver app): random photos, today's memories or one album, with a slow drift against burn-in, a countdown ring and an optional clock
- **Multiple users:** each with their own server and API key, a "Who's watching?" picker at launch, optional per-user PINs, and quick switching from the user menu at the top right

## Remote

| Where | Button | Does |
|---|---|---|
| Home | Up / Down | Move between the top-right pills, the tabs and the content |
| Top-right pills | OK | User menu (switch user) or Settings (gear) |
| Home, albums, people | `*` | View options: show All, Photos or Videos |
| Photo grids | ⏪ / ⏩ | Jump four rows |
| Photo grids (timeline, albums, people) | Left on the first photo of a row | Jump to: pick a year and month; newer months load as you scroll back up |
| Photo viewer | OK (or Up/Down) | Show or hide info |
| Photo viewer | Play | Start or stop the slideshow |
| Photo viewer, on a video | OK / Play | Play the video |

The screensaver is a separate app, **ImmichView Screensaver** (Roku only allows screensavers as standalone apps). Add it, then pick it in Roku **Settings > Theme > Screensavers > ImmichView**. It shows the photos of the user last chosen in ImmichView; choose its photos, caption and clock in ImmichView's Settings.

## Immich server tips

- Create an API key in the Immich web app under **Account Settings > API Keys**.
- Roku can't rotate video, can't decode some formats (VP9 plays as sound with no picture; ImmichView then shows a message) and HD Rokus can't play HEVC. Set **Administration > Settings > Video Transcoding** to transcode videos above the target resolution (720p) with only H.264 accepted, then run **Jobs > Transcode Videos > Missing**. ImmichView plays Immich's transcodes automatically.
- The first smart search after the server has been idle can take up to a minute while Immich loads its model.

## Development setup

1. Enable developer mode on the Roku (Home ×3, Up ×2, Right, Left, Right, Left, Right) and set a dev password.
2. Copy `.env.example` to `.env` and fill it in. `.env` is git-ignored.
3. Deploy, either:
   - from VS Code with the BrightScript Language extension: **Run > Start Debugging** ("Roku: deploy and debug"), or
   - from PowerShell: `.\deploy.ps1`, then `.\tools\relaunch.ps1` to sign in from `.env` and see the debug log
4. In the channel, enter your server URL and an API key.

The screensaver app: `.\deploy.ps1 -Screensaver` (replaces the sideloaded ImmichView; a Roku holds one sideloaded app), then `.\tools\relaunch.ps1 -Screensaver` to show it. Both apps share `source/common`; the screensaver's manifest is `manifest.screensaver`.

More tools: `tools\screenshot.ps1`, `tools\drive.ps1` (scripted remote keys), `tools\package.ps1 [-Screensaver]` (signed store packages). Debug output: `telnet <roku-ip> 8085`.

The dev launch parameters (`serverUrl`, `apiKey`) and the screensaver's dev `Main` only exist in dev builds (`bs_const DEV=true`, which `deploy.ps1` sets); release builds compile them out.

## Privacy, support and licence

- [Privacy policy](https://apinner.github.io/ImmichView/privacy.html), [terms of use](https://apinner.github.io/ImmichView/terms.html) and [support page](https://apinner.github.io/ImmichView/) (source in `docs/`).
- MIT licensed; see [LICENSE](LICENSE).
- ImmichView is an unofficial app. It is not affiliated with or endorsed by Immich or FUTO.
