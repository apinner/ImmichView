# ImmichView

A sideloaded Roku channel for browsing a self-hosted [Immich](https://immich.app) library. See [CLAUDE.md](CLAUDE.md) for the design and build phases.

## Setup

1. Enable developer mode on the Roku (Home ×3, Up ×2, Right, Left, Right, Left, Right) and set a dev password.
2. Copy `.env.example` to `.env` and fill in `ROKU_HOST` and `ROKU_DEV_PASSWORD`. `.env` is git-ignored.
3. Deploy, either:
   - from VS Code with the BrightScript Language extension: **Run > Start Debugging** ("Roku: deploy and debug"), or
   - from PowerShell: `.\deploy.ps1`
4. In the channel, enter your server URL and an API key (Immich web app > Account Settings > API Keys).

Debug output: `telnet <roku-ip> 8085`, or the extension's debug console.
