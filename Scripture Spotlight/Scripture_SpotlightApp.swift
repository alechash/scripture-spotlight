    //
    //  Scripture_SpotlightApp.swift
    //  Scripture Spotlight
    //
    //  Created by Jude Wilson (Bethel) on 8/1/25.
    //

import SwiftUI
import HotKey
import AppKit

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
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            return
        }
        
        let inputView = InputOverlayView {
            self.window?.orderOut(nil)
        }
        
        let hosting = NSHostingController(rootView: inputView)
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.setContentSize(NSSize(width: 440, height: 360))
        newWindow.styleMask = [.titled, .closable]
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.backgroundColor = .clear
        newWindow.isReleasedWhenClosed = false
        newWindow.contentView?.superview?.wantsLayer = true
        newWindow.contentView?.superview?.layer?.cornerRadius = 12
        newWindow.contentView?.superview?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.9).cgColor
        newWindow.level = .floating
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window = newWindow
    }
    
    @objc func showFromMenu() {
        showInputOverlay()
    }
}

@main
struct Scripture_SpotlightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            TipsView()
                .preferredColorScheme(.dark)
        }
    }
}

struct TipsView: View {
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
            }
            Text("JW Library must be installed and properly configured for these links to open.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .cornerRadius(14)
        .padding()
        .frame(minWidth: 400, minHeight: 250)
        .background(Color(.darkGray).opacity(0.1))
        .preferredColorScheme(.dark)
    }
}

struct InputOverlayView: View {
    @FocusState private var isFocused: Bool
    @State private var input = ""
    @State private var showTips = true
    var onSubmit: () -> Void
    
    var body: some View {
        ZStack {
            Color(.windowBackgroundColor).opacity(0.97)
                .cornerRadius(18)
                .shadow(radius: 24)
            VStack(alignment: .leading, spacing: 16) {
                Text("📖 Scripture Spotlight")
                    .font(.title2)
                    .bold()
                
                Text("Press ⏎ to launch JW Library with your reference.")
                    .font(.subheadline)
                
                TextField("e.g., John 3:16 or wt Sep 2025", text: $input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isFocused)
                    .onSubmit {
                        ScriptureLauncher.shared.handleInput(input)
                        onSubmit()
                    }
                
                Button("Open") {
                    ScriptureLauncher.shared.handleInput(input)
                    onSubmit()
                }
                .keyboardShortcut(.defaultAction)
                
                DisclosureGroup("Tips & Instructions", isExpanded: $showTips) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• You can launch this tool from anywhere using ⌘⇧J.")
                        Text("• You can also type scripture references directly in Spotlight")
                        
                        Text("✅ Supported formats:")
                            .font(.headline)
                            .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• `John 3:16` → Opens that verse")
                            Text("• `wt sep 2025` → Opens September 2025 Watchtower")
                            Text("• `1 Pet 2:9` → Works with abbreviations")
                        }
                        
                        Text("⚠️ JW Library must be installed and properly configured for these links to open.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                
            }
            .padding()
            .frame(minWidth: 420)
        }
        .padding()
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
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
