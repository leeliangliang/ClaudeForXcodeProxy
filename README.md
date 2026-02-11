# Xcode Claude SDK Proxy Helper

A lightweight macOS utility to configure proxy environment variables for the **Claude SDK integrated in Xcode 26.3+**.

[中文文档](README_CN.md)

## Background

Starting from **Xcode 26.3**, Apple integrates the [Anthropic Claude SDK](https://www.anthropic.com/) to provide AI-powered coding assistance. The Claude SDK in Xcode reads `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` environment variables to determine the API endpoint and credentials.

## Why This Tool?

If you need to route Claude SDK API requests through a proxy (e.g., for network restrictions, corporate environments, or using a custom API gateway), you'll find that macOS GUI apps like Xcode **do not** inherit shell environment variables (`~/.zshrc`, `~/.bashrc`). Setting `ANTHROPIC_BASE_URL` in your terminal has **no effect** on Xcode.

This tool solves the problem by using macOS `launchctl` to set environment variables at the **system session level**, making them available to all GUI applications — including Xcode and its built-in Claude SDK.

## Features

- Set `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` globally for Xcode 26.3+ Claude SDK
- Persist configuration via macOS LaunchAgent (survives reboot)
- One-click apply and remove
- Bilingual UI (English / Simplified Chinese)
- Native SwiftUI macOS app

## Requirements

- macOS 15.0 or later
- Xcode 26.3 or later (with built-in Claude SDK support)

## Installation

### Option 1: Download Release

Download the latest `.app` from the [Releases](../../releases) page, move it to `/Applications`, and open it.

### Option 2: Build from Source

```bash
git clone https://github.com/user/ClaudeForXcodeProxy.git
cd ClaudeForXcodeProxy
open ClaudeForXcodeProxy.xcodeproj
```

Then build and run in Xcode (⌘R).

## Usage

1. **Open** the app
2. **Enter** your proxy Base URL (e.g., `https://your-proxy.example.com/v1`)
3. **Enter** your Auth Token
4. **Click** "Apply Settings"
5. **Restart Xcode** for changes to take effect

### Remove Configuration

Click "Remove Configuration" to unload the LaunchAgent and delete the persisted plist file, then restart Xcode.

## How It Works

The app performs two actions when you apply settings:

1. **Immediate**: Calls `launchctl setenv` to set `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` in the current user session.
2. **Persistent**: Creates a LaunchAgent plist at `~/Library/LaunchAgents/com.xcodeClaudeEnvConfig.setenv.plist` with `RunAtLoad: true`, so the variables are restored on every login.

### Environment Variables

| Variable | Description |
|---|---|
| `ANTHROPIC_BASE_URL` | The proxy base URL for Xcode Claude SDK API requests |
| `ANTHROPIC_AUTH_TOKEN` | The authentication token for the proxy |

## Project Structure

```
ClaudeForXcodeProxy/
├── ClaudeForXcodeProxy/
│   ├── XcodeClaudeEnvConfigApp.swift   # App entry point
│   ├── ContentView.swift               # Main UI
│   ├── LaunchAgentManager.swift        # Core logic (launchctl + plist)
│   ├── Localizable.xcstrings           # Localization (en / zh-Hans)
│   └── Assets.xcassets                 # App assets
└── README.md
```

## Important: Xcode API Key Setting

> **Note:** After setting environment variables with this tool, Xcode may still show Claude Agent as "Not Signed In" and prompt you for an Anthropic API Key. In this case, go to **Xcode Settings → Intelligence → Claude Agent**, click the API Key field, and **enter any random string** (e.g., `placeholder`) to bypass the restriction, then click **Done**. The actual API routing will still use the proxy configured via environment variables.

![Xcode Claude Agent API Key Setting](docs/xcode_apikey_setting.png)

## FAQ

**Q: Why do I need to restart Xcode after applying?**
A: Xcode reads environment variables at launch. Changes made via `launchctl setenv` only affect newly launched processes.

**Q: Will this affect other apps?**
A: Yes, `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` are set at the user session level and are visible to all GUI apps. This is by design, as it enables any tool that uses the Anthropic SDK to benefit from the proxy.

**Q: Where is the configuration stored?**
A: `~/Library/LaunchAgents/com.xcodeClaudeEnvConfig.setenv.plist`

**Q: How do I verify the variables are set?**
A: Open Terminal and run:
```bash
launchctl getenv ANTHROPIC_BASE_URL
launchctl getenv ANTHROPIC_AUTH_TOKEN
```

## License

MIT License. See [LICENSE](LICENSE) for details.
