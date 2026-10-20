import AppKit
import Carbon.HIToolbox
@preconcurrency import ScreenCaptureKit
import UserNotifications

// Calibration knobs.
let pollInterval: TimeInterval = 1
let sampleMax = 256              // captures are downscaled to at most this many px per side
let channelTolerance = 32        // per-channel difference that counts a pixel as "changed"
let changedFraction = 0.003      // raise it if blinking cursors/spinners trigger alerts

let repo = "WsMonty/notify-me"
let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

func isNewer(_ a: String, than b: String) -> Bool { a.compare(b, options: .numeric) == .orderedDescending }

struct Tag: Decodable { let name: String }

enum Target {
    case window(CGWindowID)
    case area(CGDirectDisplayID, CGRect) // display-relative, top-left origin, points
}

// MARK: - Selection overlay

func windowAt(_ p: CGPoint) -> (CGWindowID, CGRect)? {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    for w in list where (w[kCGWindowLayer as String] as? Int) == 0 && (w[kCGWindowOwnerPID as String] as? pid_t) != getpid() {
        guard let b = w[kCGWindowBounds as String], let r = CGRect(dictionaryRepresentation: b as! CFDictionary), r.contains(p),
              let id = w[kCGWindowNumber as String] as? CGWindowID else { continue }
        return (id, r)
    }
    return nil
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

final class OverlayView: NSView {
    let screen: NSScreen
    let onDone: (Target?) -> Void
    var start: NSPoint?, current: NSPoint?
    var hover: (CGWindowID, NSRect)?

    init(screen: NSScreen, onDone: @escaping (Target?) -> Void) {
        self.screen = screen
        self.onDone = onDone
        super.init(frame: NSRect(origin: .zero, size: screen.frame.size))
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    var selection: NSRect? {
        guard let a = start, let b = current else { return nil }
        let r = NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
        return r.width > 4 && r.height > 4 ? r : nil
    }

    override func mouseMoved(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        let primaryH = NSScreen.screens[0].frame.height
        let cg = CGPoint(x: p.x + screen.frame.minX, y: primaryH - (p.y + screen.frame.minY))
        hover = windowAt(cg).map { id, r in
            (id, NSRect(x: r.minX - screen.frame.minX, y: primaryH - r.maxY - screen.frame.minY, width: r.width, height: r.height))
        }
        needsDisplay = true
    }
    override func mouseExited(with e: NSEvent) { hover = nil; needsDisplay = true }
    override func mouseDown(with e: NSEvent) { start = convert(e.locationInWindow, from: nil); current = start }
    override func mouseDragged(with e: NSEvent) { current = convert(e.locationInWindow, from: nil); needsDisplay = true }
    override func mouseUp(with e: NSEvent) {
        defer { start = nil; current = nil; needsDisplay = true }
        if let r = selection {
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber).uint32Value
            onDone(.area(id, CGRect(x: r.minX, y: bounds.height - r.maxY, width: r.width, height: r.height)))
        } else if let (id, _) = hover {
            onDone(.window(id))
        }
    }
    override func keyDown(with e: NSEvent) { if e.keyCode == UInt16(kVK_Escape) { onDone(nil) } }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.3).setFill()
        bounds.fill()
        guard let hole = selection ?? (start == nil ? hover?.1 : nil) else { return }
        // Not fully clear: macOS passes clicks on fully transparent pixels through to the window below.
        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        hole.fill(using: .copy)
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: hole)
        path.lineWidth = 2
        path.stroke()
    }
}

// MARK: - Watching

func pixels(_ img: CGImage) -> [UInt8] {
    var buf = [UInt8](repeating: 0, count: img.width * img.height * 4)
    buf.withUnsafeMutableBytes { raw in
        let ctx = CGContext(data: raw.baseAddress, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: img.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    }
    return buf
}

func changed(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    guard a.count == b.count else { return true } // window was resized
    var n = 0
    for i in stride(from: 0, to: a.count, by: 4) {
        let d = max(abs(Int(a[i]) - Int(b[i])), abs(Int(a[i + 1]) - Int(b[i + 1])), abs(Int(a[i + 2]) - Int(b[i + 2])))
        if d > channelTolerance { n += 1 }
    }
    return Double(n) / Double(a.count / 4) > changedFraction
}

// MARK: - App

final class Controller: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var overlays: [NSWindow] = []
    var timer: Timer?
    var last: [UInt8]?
    var busy = false
    let updateItem = NSMenuItem(title: "", action: #selector(runDeploy), keyEquivalent: "")
    var watchedWindow: CGWindowID?
    let outline: NSWindow = {
        let w = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.animationBehavior = .none
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let v = NSView()
        v.wantsLayer = true
        v.layer?.borderColor = NSColor.systemRed.cgColor
        v.layer?.borderWidth = 3
        v.layer?.cornerRadius = 4
        w.contentView = v
        return w
    }()

    override init() {
        super.init()
        let menu = NSMenu()
        menu.addItem(withTitle: "Select… (⌃⌥⌘W)", action: #selector(toggle), keyEquivalent: "").target = self
        updateItem.target = self
        updateItem.isHidden = true
        menu.addItem(updateItem)
        menu.addItem(withTitle: "Check for Updates", action: #selector(checkNow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Hide Menu Bar Icon", action: #selector(hideIcon), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Notify Me \(currentVersion)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
        updateIcon()

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        if !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }

        checkForUpdates(manual: false)
        Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { _ in
            MainActor.assumeIsolated { controller.checkForUpdates(manual: false) }
        }
    }

    // AppKit persists isVisible itself (via the item's autosaveName). Opening the app again brings the icon back.
    @objc func hideIcon() {
        status.isVisible = false
        notify("Menu bar icon hidden", "⌃⌥⌘W still works. Open Notify Me again to bring the icon back.")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        status.isVisible = true
        return false
    }

    @objc func checkNow() { checkForUpdates(manual: true) }

    // Newest git tag on GitHub vs. the tag this copy was built from.
    func checkForUpdates(manual: Bool) {
        Task { @MainActor in
            guard let (data, _) = try? await URLSession.shared.data(from: URL(string: "https://api.github.com/repos/\(repo)/tags?per_page=100")!),
                  let tags = try? JSONDecoder().decode([Tag].self, from: data) else {
                if manual { notify("Couldn't check for updates", "Is your internet connection working?") }
                return
            }
            guard let latest = tags.map(\.name).max(by: { isNewer($1, than: $0) }), isNewer(latest, than: currentVersion) else {
                if manual { notify("You're up to date", "Notify Me \(currentVersion) is the latest version.") }
                return
            }
            updateItem.title = "Update to \(latest)…"
            updateItem.isHidden = false
            if manual || UserDefaults.standard.string(forKey: "notifiedVersion") != latest {
                UserDefaults.standard.set(latest, forKey: "notifiedVersion")
                notify("Notify Me \(latest) is available", "Choose “Update to \(latest)…” in the menu bar, or run ./deploy.sh.")
            }
        }
    }

    // Runs deploy.sh from the clone this app was built from, in Terminal.
    @objc func runDeploy() {
        guard let src = Bundle.main.object(forInfoDictionaryKey: "NotifyMeSource") as? String,
              FileManager.default.isExecutableFile(atPath: src + "/deploy.sh") else {
            notify("Can't find the source folder", "Run ./deploy.sh in your notify-me folder.")
            return
        }
        try? Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: ["-a", "Terminal", src + "/deploy.sh"])
    }

    func updateIcon() {
        status.button?.image = NSImage(systemSymbolName: timer == nil ? "eye" : "eye.fill", accessibilityDescription: "Notify Me")
    }

    @objc func toggle() {
        if timer != nil { stop(); return }
        if !overlays.isEmpty { closeOverlays(); return }
        NSApp.activate()
        overlays = NSScreen.screens.map { screen in
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.level = .screenSaver
            w.backgroundColor = .clear
            w.isOpaque = false
            w.ignoresMouseEvents = false
            w.animationBehavior = .none
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            w.contentView = OverlayView(screen: screen) { [weak self] target in
                self?.closeOverlays()
                if let target { self?.watch(target) }
            }
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            return w
        }
        let mouse = NSEvent.mouseLocation
        if let w = overlays.first(where: { $0.frame.contains(mouse) }) ?? overlays.first {
            w.makeKeyAndOrderFront(nil)
            w.makeFirstResponder(w.contentView)
        }
    }

    // Drawn just outside the watched rect, so area captures never see it
    func showOutline(_ r: CGRect) {
        let primaryH = NSScreen.screens[0].frame.height
        outline.setFrame(NSRect(x: r.minX, y: primaryH - r.maxY, width: r.width, height: r.height).insetBy(dx: -4, dy: -4), display: true)
        if let id = watchedWindow {
            outline.level = .normal
            outline.order(.above, relativeTo: Int(id)) // sits on the watched window, hides behind windows covering it
        } else {
            outline.level = .floating
            outline.orderFrontRegardless()
        }
    }

    func closeOverlays() {
        overlays.forEach { $0.orderOut(nil) }
        overlays = []
    }

    func watch(_ target: Target) {
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                let filter: SCContentFilter, size: CGSize
                let config = SCStreamConfiguration()
                config.showsCursor = false
                switch target {
                case .window(let id):
                    guard let w = content.windows.first(where: { $0.windowID == id }) else { throw CocoaError(.fileNoSuchFile) }
                    filter = SCContentFilter(desktopIndependentWindow: w)
                    size = w.frame.size
                    watchedWindow = id
                    showOutline(w.frame)
                case .area(let id, let rect):
                    guard let d = content.displays.first(where: { $0.displayID == id }) else { throw CocoaError(.fileNoSuchFile) }
                    filter = SCContentFilter(display: d, excludingWindows: [])
                    config.sourceRect = rect
                    size = rect.size
                    watchedWindow = nil
                    showOutline(rect.offsetBy(dx: d.frame.minX, dy: d.frame.minY))
                }
                let scale = min(1, CGFloat(sampleMax) / max(size.width, size.height))
                config.width = max(1, Int(size.width * scale))
                config.height = max(1, Int(size.height * scale))

                last = nil
                timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.tick(filter, config) }
                }
                updateIcon()
            } catch {
                notify("Can't capture the screen", "\(error.localizedDescription) Check Screen Recording permission.")
            }
        }
    }

    func tick(_ filter: SCContentFilter, _ config: SCStreamConfiguration) {
        guard !busy else { return }
        busy = true
        // follow the watched window if it moves
        if let id = watchedWindow,
           let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]])?.first,
           let b = info[kCGWindowBounds as String], let r = CGRect(dictionaryRepresentation: b as! CFDictionary) {
            showOutline(r)
        }
        Task { @MainActor in
            defer { busy = false }
            do {
                let px = pixels(try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config))
                if let last, changed(last, px) {
                    stop()
                    notify("Something changed", "The watched area changed.")
                } else {
                    last = px
                }
            } catch {
                guard timer != nil else { return }
                stop()
                notify("Stopped watching", "The watched window is gone (\(error.localizedDescription))")
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        last = nil
        watchedWindow = nil
        outline.orderOut(nil)
        updateIcon()
    }

    func notify(_ title: String, _ body: String) {
        NSSound(named: "Glass")?.play()
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .list])
    }
}

// ⌃⌥⌘W global hotkey
func registerHotkey() {
    var ref: EventHotKeyRef?
    RegisterEventHotKey(UInt32(kVK_ANSI_W), UInt32(cmdKey | optionKey | controlKey), EventHotKeyID(signature: 0x4E4D4520, id: 1),
                        GetApplicationEventTarget(), 0, &ref)
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        MainActor.assumeIsolated { controller.toggle() }
        return noErr
    }, 1, &spec, nil, nil)
}

if CommandLine.arguments.contains("--selftest") {
    let a = [UInt8](repeating: 0, count: 100 * 100 * 4)
    var b = a
    b[0] = 255                              // 1 of 10k pixels: noise
    precondition(!changed(a, b))
    for i in stride(from: 0, to: 400 * 4, by: 4) { b[i] = 255 } // 4% of pixels
    precondition(changed(a, b))
    precondition(changed(a, []))            // resize
    precondition(isNewer("v1.10.0", than: "v1.9.3"))
    precondition(!isNewer("v1.0.0", than: "v1.0.0"))
    precondition(isNewer("v1.0.0", than: "dev"))
    print("ok"); exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
app.delegate = controller
registerHotkey()
app.run()
