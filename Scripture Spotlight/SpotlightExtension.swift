//
//  SpotlightExtension.swift
//  Scripture Spotlight
//
//  Created by Jude Wilson (Bethel) on 8/1/25.
//

import AppIntents
import AppKit

@MainActor
struct OpenScriptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Open a Bible Verse"
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$reference)")
    }

    static var description = IntentDescription("Opens a scripture in JW Library.")

    @Parameter(title: "Scripture Reference")
    var reference: String

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        print("Requested scripture: \(reference)")

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

        let input = reference.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
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

            if let (matchedBook, bookNumber) = bibleBooks.first(where: { key, _ in key.contains(bookStr) }) {
                print("Matched book: \(matchedBook)")
                let bookCode = String(format: "%02d", bookNumber)
                let urlStr = "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&bible=\(bookCode)\(chapterStr)\(verseStr)&pub=nwtsty"
                
                print(urlStr)
                if let url = URL(string: urlStr) {
                    try await NSWorkspace.shared.open(url, configuration: .init())
                }
            }
        }

        // Check for Watchtower input
        let wtRegex = try! NSRegularExpression(pattern: #"wt\s+([a-z]{2,})\s+(\d{4})"#)
        if let match = wtRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            let monthAbbr = (input as NSString).substring(with: match.range(at: 1))
            let yearStr = (input as NSString).substring(with: match.range(at: 2))

            let monthNames = [
                "january": "01", "february": "02", "march": "03", "april": "04", "may": "05", "june": "06",
                "july": "07", "august": "08", "september": "09", "october": "10", "november": "11", "december": "12"
            ]

            if let (fullMonth, mm) = monthNames.first(where: { key, _ in key.contains(monthAbbr) }) {
                let yy = String(yearStr.suffix(2))
                let urlStr = "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&pub=wp\(yy)&issue=\(yearStr)\(mm)"
                print("Watchtower URL: \(urlStr)")
                if let url = URL(string: urlStr) {
                    try await NSWorkspace.shared.open(url, configuration: .init())
                }
            }
        }

        if (input == "dt" || input == "daily" || input == "daily text") {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMDD"

            let formattedDate = dateFormatter.string(from: Date())
            
            let urlStr = "https://www.jw.org/finder?srcid=jwlshare&wtlocale=E&prefer=lang&alias=daily-text&date=\(formattedDate)"

            print("Daily Text URL: \(urlStr)")

            if let url = URL(string: urlStr) {
                try await NSWorkspace.shared.open(url, configuration: .init())
            }

        }

        return .result()
    }
}
