    //
    //  SpotlightExtension.swift
    //  Scripture Spotlight
    //
    //  Created by Jude Wilson (Bethel) on 8/1/25.
    //

import AppIntents
import AppKit

    // MARK: - Document index (Insight / topical lookup)
struct DocEntry: Decodable {
    let MepsDocumentId: Int
    let Title: String
    let TocTitle: String?
}

final class DocumentIndex {
    static let shared = DocumentIndex()
    private(set) var entries: [DocEntry] = []
    
    private init() { load() }
    
    private func load() {
            // Prefer a bundled resource named "Insight.json"
        if let url = Bundle.main.url(forResource: "Insight", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            decode(data)
            return
        }
            // Fallback: ~/Insight/Insight.json so you can iterate without bundling
        let fallback = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Insight")
            .appendingPathComponent("Insight.json")
        if let data = try? Data(contentsOf: fallback) {
            decode(data)
        }
    }
    
    private func decode(_ data: Data) {
        do {
            let list = try JSONDecoder().decode([DocEntry].self, from: data)
            self.entries = list
        } catch {
            NSLog("DocumentIndex decode error: \(error.localizedDescription)")
        }
    }
    
        /// Fuzzy lookup: prefer Title that starts with the query, else contains; then try TocTitle.
    func lookupMEPSID(for rawQuery: String) -> Int? {
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return nil }
        if let hit = entries.first(where: { $0.Title.lowercased().hasPrefix(q) }) { return hit.MepsDocumentId }
        if let hit = entries.first(where: { $0.Title.lowercased().contains(q) }) { return hit.MepsDocumentId }
        if let hit = entries.first(where: { ($0.TocTitle ?? "").lowercased().contains(q) }) { return hit.MepsDocumentId }
        return nil
    }
}

    // MARK: - Unified input decoder
enum InputDecoder {
    static func decodeInput(_ raw: String) -> URL? {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !input.isEmpty else { return nil }
        
            // 1) Help:  help *
        if let helpURL = decodeHelp(input) { return helpURL }
        
            // 1) Insight/Topical:  i <term>
        if let topicURL = decodeInsight(input) { return topicURL }
        
            // 2) Daily Text
        if let dtURL = decodeDailyText(input) { return dtURL }
        
            // 3) Watchtower issue:  wt <month> <yyyy>
        if let wtURL = decodeWatchtower(input) { return wtURL }
        
            // 4) Bible reference
        if let bibleURL = decodeBible(input) { return bibleURL }
        
        return nil
    }
    
        // MARK: Modules
    private static func decodeHelp(_ input: String) -> URL? {
            // Accept: i respect  |  i  resp
        if (input == "help") {
            return URL(string: "https://google.com")
        }
        
        return nil
    }
    
    private static func decodeInsight(_ input: String) -> URL? {
            // Accept: i respect  |  i  resp
        let pattern = #"^i\s+(.+)$"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard let m = re.firstMatch(in: input, range: range) else { return nil }
        let term = (input as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        guard let id = DocumentIndex.shared.lookupMEPSID(for: term) else { return nil }
        let urlStr = "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&docid=\(id)"
        return URL(string: urlStr)
    }
    
    private static func decodeDailyText(_ input: String) -> URL? {
        if ["dt", "daily", "daily text", "dailytext"].contains(input) {
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyyMMdd" // correct calendar year
            let today = df.string(from: Date())
                // JW site supports alias "daily-text"; keeping https because app scheme may vary per install
            let urlStr = "https://www.jw.org/finder?srcid=jwlshare&wtlocale=E&prefer=lang&alias=daily-text&date=\(today)"
            return URL(string: urlStr)
        }
        return nil
    }
    
    private static func decodeWatchtower(_ input: String) -> URL? {
            // e.g., wt sep 2025  | wt september 2025 | wt se 2025
        let pattern = #"^wt\s+([a-z]{2,})\s+(\d{4})$"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard let m = re.firstMatch(in: input, range: range) else { return nil }
        let monthAbbr = (input as NSString).substring(with: m.range(at: 1))
        let year = (input as NSString).substring(with: m.range(at: 2))
        let months = [
            "january":"01","february":"02","march":"03","april":"04","may":"05","june":"06",
            "july":"07","august":"08","september":"09","october":"10","november":"11","december":"12"
        ]
        guard let (_, mm) = months.first(where: { key, _ in key.contains(monthAbbr) }) else { return nil }
        let yy = String(year.suffix(2))
        let urlStr = "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&pub=wp\(yy)&issue=\(year)\(mm)"
        return URL(string: urlStr)
    }
    
    private static func decodeBible(_ input: String) -> URL? {
            // Bible books map
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
        guard let re = try? NSRegularExpression(pattern: #"^([1-3]?\s?[a-z\s]+)(?:\s+(\d+)(?::(\d+))?)?$"#) else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard let m = re.firstMatch(in: input, range: range) else { return nil }
        var book = (input as NSString).substring(with: m.range(at: 1))
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
        let chapterStr: String = {
            if m.range(at: 2).location != NSNotFound { return String(format: "%03d", Int((input as NSString).substring(with: m.range(at: 2))) ?? 0) }
            return "000"
        }()
        let verseStr: String = {
            if m.range(at: 3).location != NSNotFound { return String(format: "%03d", Int((input as NSString).substring(with: m.range(at: 3))) ?? 0) }
            return "000"
        }()
        guard let (_, num) = bibleBooks.first(where: { key, _ in key.contains(book) }) else { return nil }
        let bookCode = String(format: "%02d", num)
        let urlStr = "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&bible=\(bookCode)\(chapterStr)\(verseStr)&pub=nwtsty"
        return URL(string: urlStr)
    }
}

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
        let input = reference
        print("Requested input: \(input)")
        if let url = InputDecoder.decodeInput(input) {
            try await NSWorkspace.shared.open(url, configuration: .init())
        } else {
            NSLog("No match for input: \(input)")
        }
        return .result()
    }
}
