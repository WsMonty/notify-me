<p align="center"><img src="icon/icon.png" width="160" alt="Notify Me icon"></p>

<h1 align="center">Notify Me</h1>

A tiny macOS menu-bar app that watches a window or screen area and plays a sound + notification when it changes. Handy for waiting on things that don't notify you themselves.

## Use

1. Press **⌃⌥⌘W**. The screen dims.
2. **Drag** to watch an area, or **click** a window to watch it. **Esc** cancels.
3. A red outline marks what's watched. When it changes you hear a sound and get a notification.
4. Press **⌃⌥⌘W** again to stop early.

Needs **Screen Recording** permission (System Settings → Privacy & Security). macOS 14+.

## Install

Download `NotifyMe.zip` from [Releases](../../releases), unzip, move to Applications.
The app isn't notarized, so the first time: right-click → **Open**, or run
`xattr -dr com.apple.quarantine /Applications/NotifyMe.app`.

## Build from source

```sh
./build.sh && open NotifyMe.app
```

Sensitivity knobs are at the top of `main.swift`.

## Release

```sh
git tag v1.0.0 && git push origin v1.0.0
```

GitHub Actions builds the app and attaches `NotifyMe.zip` to a new release.

## License

MIT, see [LICENSE](LICENSE).
