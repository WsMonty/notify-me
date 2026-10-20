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

Requires macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/WsMonty/notify-me.git
cd notify-me
./build.sh
mv NotifyMe.app /Applications/ && open /Applications/NotifyMe.app
```

To update: `git pull && ./build.sh`, then replace the app in Applications.
macOS may ask for Screen Recording permission again after each rebuild.

Sensitivity knobs are at the top of `main.swift`.

## License

MIT, see [LICENSE](LICENSE).
