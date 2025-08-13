    //
    //  Scripture_SpotlightApp.swift
    //  Scripture Spotlight
    //
    //  Created by Jude Wilson (Bethel) on 8/1/25.
    //

import SwiftUI
import HotKey
import AppKit
import ServiceManagement

extension Notification.Name {
    static let ScriptureSpotlightFocusField = Notification.Name("ScriptureSpotlightFocusField")
}

final class SpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKey: HotKey?
    var window: NSWindow?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey = HotKey(key: .j, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = {
            DispatchQueue.main.async {
                self.showInputOverlay()
            }
        }
            // Open the TipsView window (Settings) explicitly on launch
        DispatchQueue.main.async {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
            // Add menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "book.fill", accessibilityDescription: "Scripture Shortcut")
            button.action = #selector(showFromMenu)
            button.target = self
        }
    }
    
    func showInputOverlay() {
        if let win = window {
            win.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(name: .ScriptureSpotlightFocusField, object: nil)
            }
            return
        }
        
        let inputView = InputOverlayView {
            self.window?.orderOut(nil)
        }
        
        let hosting = NSHostingController(rootView: inputView)
        let panel = SpotlightPanel(contentViewController: hosting)
        
            // Spotlight-like size
        panel.setContentSize(NSSize(width: 760, height: 260))
        
            // Borderless + clear so AppKit doesn't draw its own background panel
        panel.styleMask = [.borderless]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
            // Clip the entire window content to our rounded shape to avoid a second rounded backdrop
        if let superview = panel.contentView?.superview {
            superview.wantsLayer = true
            superview.layer?.cornerRadius = 22
            superview.layer?.masksToBounds = true
        }
        
            // Center and bring to front
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        panel.makeKeyAndOrderFront(nil)
        
            // Ensure first responder after activation (let SwiftUI set FocusState)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .ScriptureSpotlightFocusField, object: nil)
        }
        
        window = panel
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
            self?.window = nil
        }
    }
    
    @objc func showFromMenu() {
        showInputOverlay()
    }
}

    // MARK: - Launch at Login helper (requires embedded Login Item helper target)
enum LaunchAtLogin {
        /// TODO: Set this to your embedded Login Item helper's bundle identifier
    static let helperBundleID = "com.yourcompany.ScriptureSpotlight.Launcher"
    
    static var isEnabled: Bool {
        let service = SMAppService.loginItem(identifier: helperBundleID)
        return service.status == .enabled
    }
    
    @discardableResult
    static func setEnabled(_ enable: Bool) -> Bool {
        let service = SMAppService.loginItem(identifier: helperBundleID)
        do {
            if enable { try service.register() } else { try service.unregister() }
            return true
        } catch {
            NSLog("LaunchAtLogin error: \(error.localizedDescription)")
            return false
        }
    }
    
        /// Opens System Settings → Login Items to let the user add the app manually.
    static func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else if let old = URL(string: "x-apple.systempreferences:com.apple.preference.users?LoginItems") {
            NSWorkspace.shared.open(old)
        }
    }
}

@main
struct Scripture_SpotlightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            TipsView()
        }
    }
}

struct TipsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var showLoginError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📖 Scripture Spotlight")
                .font(.title)
                .bold()
            Text("Press ⌘⇧J from anywhere to bring up your preset scripture or article reference launcher.")
            Text("Supported formats:")
                .bold()
            VStack(alignment: .leading, spacing: 4) {
                Text("- `John 3:16` → Opens that verse")
                Text("- `wt sep 2025` → Opens September 2025 Watchtower")
                Text("- `1 Pet 2:9` → Works with abbreviations")
                Divider().padding(.vertical, 8)
                HStack(spacing: 12) {
                    Toggle(isOn: $launchAtLogin) {
                        Text("Open at login")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { isOn in
                        if !LaunchAtLogin.setEnabled(isOn) {
                            launchAtLogin.toggle()
                            showLoginError = true
                        }
                    }
                    
                    Button("Open Login Items…") {
                        LaunchAtLogin.openLoginItemsSettings()
                    }
                }
                .alert("Couldn’t change Login Item", isPresented: $showLoginError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Make sure a Login Item helper target is embedded and its bundle identifier matches LaunchAtLogin.helperBundleID.")
                }
            }
            Text("JW Library must be installed and properly configured for these links to open.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .cornerRadius(14)
        .padding()
        .frame(minWidth: 400, minHeight: 100)
        .background(Color(.darkGray).opacity(0.1))
    }
}

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .withinWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerCurve = .continuous
        v.layer?.cornerRadius = 22
        v.layer?.masksToBounds = true
        v.layer?.backgroundColor = NSColor(Color.black.opacity(0.35)).cgColor
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct CapsuleFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

struct InputOverlayView: View {
    @FocusState private var isFocused: Bool
    @State private var input = ""
    var onSubmit: () -> Void
    
    var body: some View {
        ZStack {
            GlassBackground()
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .compositingGroup()
                .shadow(radius: 24)
            
            VStack(spacing: 14) {
                    // Title bar mimicking the tab look
                HStack(spacing: 8) {
                    Text("Scripture Spotlight")
                        .font(.title2)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 6)
                
                    // Prompt field
                HStack(spacing: 4) {
                    TextField("Search Scripture Spotlight", text: $input)
                        .textCase(nil)
                        .focused($isFocused)
                        .onSubmit {
                            ScriptureLauncher.shared.handleInput(input)
                            onSubmit()
                        }
                    Spacer(minLength: 4)
                    Button(action: {
                        ScriptureLauncher.shared.handleInput(input)
                        onSubmit()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .imageScale(.large)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(NSColor.systemPurple))
                    .cornerRadius(14)
                    .keyboardShortcut(.defaultAction)
                }
                .textFieldStyle(CapsuleFieldStyle())
                
                TipsCard()
                    .transition(.opacity)
            }
            .padding(26)
            .frame(minWidth: 720, minHeight: 180)
        }
        .padding(-10)
        .cornerRadius(20)
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ScriptureSpotlightFocusField)) { _ in
            isFocused = true
        }
        .onExitCommand { onSubmit() }
    }
}

struct TipsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill").imageScale(.medium)
                Text("Tips & Instructions").font(.headline)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "text.book.closed.fill").frame(width: 16)
                    Text("Try **John 3:16**, **1 Pet 2:9**, **wt September 2025**, **dt**, or **wol <search term>**")
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "command").frame(width: 16)
                    Text("Press **⌘⇧J** anywhere to open this window")
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "link").frame(width: 16)
                    Text("JW Library must be installed for links to open")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

    // ScriptureLauncher relies on InputDecoder defined in the shared file.
    // Ensure that file is added to both the App target and the Extension target in Xcode → File Inspector → Target Membership.
class ScriptureLauncher {
    static let shared = ScriptureLauncher()
    
    func handleInput(_ input: String) {
        Task {
            if let url = InputDecoder.decodeInput(input) {
                try? await NSWorkspace.shared.open(url, configuration: .init())
            }
        }
    }
    
    private func jwLibraryURL(from input: String) -> URL? {
            // Delegate to shared unified decoder so logic lives in one place
        return InputDecoder.decodeInput(input)
    }
}
