//
//  Scripture_SpotlightApp.swift
//  Scripture Spotlight
//
//  Created by Jude Wilson (Bethel) on 8/1/25.
//

import SwiftUI
import HotKey

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

class ScriptureLauncher {
    static let shared = ScriptureLauncher()

    func handleInput(_ input: String) {
        Task {
            if let url = jwLibraryURL(from: input) {
                try? await NSWorkspace.shared.open(url, configuration: .init())
            }
        }
    }

    private func jwLibraryURL(from input: String) -> URL? {
        let bibleBooks: [String: Int] = [
            "genesis": 1, "exodus": 2, "leviticus": 3, "numbers": 4, "deuteronomy": 5,
            "joshua": 6, "judges": 7, "ruth": 8, "1 samuel": 9, "2 samuel": 10,
            "1 kings": 11, "2 kings": 12, "1 chronicles": 13, "2 chronicles": 14,
            "ezra": 15, "nehemiah": 16, "esther": 17, "job": 18, "psalms": 19,
            "proverbs": 20, "ecclesiastes": 21, "song of solomon": 22, "isaiah": 23,
            "jeremiah": 24, "lamentations": 25, "ezekiel": 26, "daniel": 27,
            "hosea": 28, "joel": 29, "amos": 30, "obadiah": 31, "jonah": 32,
            "micah": 33, "nahum": 34, "habakkuk": 35, "zephaniah": 36, "haggai": 37,
            "zechariah": 38, "malachi": 39, "matthew": 40, "mark": 41, "luke": 42,
            "john": 43, "acts": 44, "romans": 45, "1 corinthians": 46, "2 corinthians": 47,
            "galatians": 48, "ephesians": 49, "philippians": 50, "colossians": 51,
            "1 thessalonians": 52, "2 thessalonians": 53, "1 timothy": 54, "2 timothy": 55,
            "titus": 56, "philemon": 57, "hebrews": 58, "james": 59, "1 peter": 60,
            "2 peter": 61, "1 john": 62, "2 john": 63, "3 john": 64, "jude": 65,
            "revelation": 66
        ]

        let input = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let bibleRegex = try! NSRegularExpression(pattern: #"^([1-3]?\s?[a-z\s]+)(?:\s+(\d+)(?::(\d+))?)?$"#)
        if let match = bibleRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            var bookStr = (input as NSString).substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
                .replacingOccurrences(of: ".", with: "")

            let chapterStr: String
            if match.range(at: 2).location != NSNotFound {
                chapterStr = String(format: "%03d", Int((input as NSString).substring(with: match.range(at: 2))) ?? 0)
            } else {
                chapterStr = "000"
            }

            let verseStr: String
            if match.range(at: 3).location != NSNotFound {
                verseStr = String(format: "%03d", Int((input as NSString).substring(with: match.range(at: 3))) ?? 0)
            } else {
                verseStr = "000"
            }

            if let (_, bookNumber) = bibleBooks.first(where: { key, _ in key.contains(bookStr) }) {
                let bookCode = String(format: "%02d", bookNumber)
                return URL(string: "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&bible=\(bookCode)\(chapterStr)\(verseStr)&pub=nwtsty")
            }
        }

        let wtRegex = try! NSRegularExpression(pattern: #"wt\s+([a-z]{2,})\s+(\d{4})"#)
        if let match = wtRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            let monthAbbr = (input as NSString).substring(with: match.range(at: 1))
            let yearStr = (input as NSString).substring(with: match.range(at: 2))

            let monthNames = [
                "january": "01", "february": "02", "march": "03", "april": "04", "may": "05", "june": "06",
                "july": "07", "august": "08", "september": "09", "october": "10", "november": "11", "december": "12"
            ]

            if let (_, mm) = monthNames.first(where: { key, _ in key.contains(monthAbbr) }) {
                let yy = String(yearStr.suffix(2))
                return URL(string: "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&pub=wp\(yy)&issue=\(yearStr)\(mm)")
            }
        }

        return nil
    }
}
