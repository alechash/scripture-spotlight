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
        
            // 0) Help:  help *
        if let helpURL = decodeHelp(input) { return helpURL }
        
            // 1) Insight/Topical:  i <term>
        if let topicURL = decodeInsight(input) { return topicURL }
        
            // 2) Daily Text
        if let dtURL = decodeDailyText(input) { return dtURL }
        
            // 3) Watchtower issue:  wt <month> <yyyy>
        if let wtURL = decodeWatchtower(input) { return wtURL }
        
            // 4) Bible reference
        if let wolURL = decodeWol(input) { return wolURL }
        
            // 5) Bible reference
        if let bibleURL = decodeBible(input) { return bibleURL }
        
        return nil
    }
    
        // MARK: Modules
    private static func decodeHelp(_ input: String) -> URL? {
        if (input == "help") {
            return URL(string: "https://judes.club/app/scripture-spotlight")
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
    
    private static func decodeWol(_ input: String) -> URL? {
            // Accept: wol <term>
        let pattern = #"^wol\s+(.+)$"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(input.startIndex..., in: input)
        guard let m = re.firstMatch(in: input, range: range) else { return nil }
        let term = (input as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let urlStr = "https://wol.jw.org/en/wol/s/r1/lp-e?q=\(term)&p=par&r=occ&st=a"
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

    // MARK: - AppIntents autocompletion (Spotlight parameter sheet)

    // MARK: - Bible metadata (chapter counts per book)
nonisolated(unsafe) let kChapterCountByBook: [BibleBook: Int] = [
    .genesis: 50, .exodus: 40, .leviticus: 27, .numbers: 36, .deuteronomy: 34,
    .joshua: 24, .judges: 21, .ruth: 4, ._1samuel: 31, ._2samuel: 24,
    ._1kings: 22, ._2kings: 25, ._1chronicles: 29, ._2chronicles: 36,
    .ezra: 10, .nehemiah: 13, .esther: 10, .job: 42, .psalms: 150,
    .proverbs: 31, .ecclesiastes: 12, .songOfSolomon: 8, .isaiah: 66, .jeremiah: 52,
    .lamentations: 5, .ezekiel: 48, .daniel: 12, .hosea: 14, .joel: 3,
    .amos: 9, .obadiah: 1, .jonah: 4, .micah: 7, .nahum: 3,
    .habakkuk: 3, .zephaniah: 3, .haggai: 2, .zechariah: 14, .malachi: 4,
    .matthew: 28, .mark: 16, .luke: 24, .john: 21, .acts: 28,
    .romans: 16, ._1corinthians: 16, ._2corinthians: 13, .galatians: 6, .ephesians: 6,
    .philippians: 4, .colossians: 4, ._1thessalonians: 5, ._2thessalonians: 3,
    ._1timothy: 6, ._2timothy: 4, .titus: 3, .philemon: 1, .hebrews: 13,
    .james: 5, ._1peter: 5, ._2peter: 3, ._1john: 5, ._2john: 1, ._3john: 1, .jude: 1, .revelation: 22
]

    // Optional: a conservative max verse cap used when we cannot cheaply know per-chapter verse counts here.
nonisolated(unsafe) let kConservativeMaxVerse = 200

    // Sources (keep others for future; default will be .bible)
enum ScriptureSource: String, AppEnum, CaseIterable, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Source")
    nonisolated(unsafe) static var caseDisplayRepresentations: [ScriptureSource : DisplayRepresentation] = [
        .bible: .init(title: "Bible"),
        .watchtower: .init(title: "Watchtower"),
        .insight: .init(title: "Insight"),
        .wol: .init(title: "WOL")
    ]
    case bible, watchtower, insight, wol
}

    // Bible books with display names; Spotlight/Shortcuts will autocomplete this field
enum BibleBook: Int, AppEnum, CaseIterable, Sendable {
    nonisolated(unsafe) static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Bible Book")
    
    case genesis = 1, exodus, leviticus, numbers, deuteronomy,
         joshua, judges, ruth, _1samuel, _2samuel,
         _1kings, _2kings, _1chronicles, _2chronicles,
         ezra, nehemiah, esther, job, psalms,
         proverbs, ecclesiastes, songOfSolomon, isaiah, jeremiah,
         lamentations, ezekiel, daniel, hosea, joel,
         amos, obadiah, jonah, micah, nahum,
         habakkuk, zephaniah, haggai, zechariah, malachi,
         matthew = 40, mark, luke, john, acts,
         romans, _1corinthians, _2corinthians, galatians, ephesians,
         philippians, colossians, _1thessalonians, _2thessalonians,
         _1timothy, _2timothy, titus, philemon, hebrews,
         james, _1peter, _2peter, _1john, _2john, _3john, jude, revelation
    
    nonisolated(unsafe) static var allCases: [BibleBook] = [
        .genesis, .exodus, .leviticus, .numbers, .deuteronomy,
        .joshua, .judges, .ruth, ._1samuel, ._2samuel,
        ._1kings, ._2kings, ._1chronicles, ._2chronicles,
        .ezra, .nehemiah, .esther, .job, .psalms,
        .proverbs, .ecclesiastes, .songOfSolomon, .isaiah, .jeremiah,
        .lamentations, .ezekiel, .daniel, .hosea, .joel,
        .amos, .obadiah, .jonah, .micah, .nahum,
        .habakkuk, .zephaniah, .haggai, .zechariah, .malachi,
        .matthew, .mark, .luke, .john, .acts,
        .romans, ._1corinthians, ._2corinthians, .galatians, .ephesians,
        .philippians, .colossians, ._1thessalonians, ._2thessalonians,
        ._1timothy, ._2timothy, .titus, .philemon, .hebrews,
        .james, ._1peter, ._2peter, ._1john, ._2john, ._3john, .jude, .revelation
    ]
    
    nonisolated(unsafe) static var caseDisplayRepresentations: [BibleBook : DisplayRepresentation] = [
        .genesis: .init(title: "Genesis"), .exodus: .init(title: "Exodus"), .leviticus: .init(title: "Leviticus"), .numbers: .init(title: "Numbers"), .deuteronomy: .init(title: "Deuteronomy"),
        .joshua: .init(title: "Joshua"), .judges: .init(title: "Judges"), .ruth: .init(title: "Ruth"), ._1samuel: .init(title: "1 Samuel"), ._2samuel: .init(title: "2 Samuel"),
        ._1kings: .init(title: "1 Kings"), ._2kings: .init(title: "2 Kings"), ._1chronicles: .init(title: "1 Chronicles"), ._2chronicles: .init(title: "2 Chronicles"),
        .ezra: .init(title: "Ezra"), .nehemiah: .init(title: "Nehemiah"), .esther: .init(title: "Esther"), .job: .init(title: "Job"), .psalms: .init(title: "Psalms"),
        .proverbs: .init(title: "Proverbs"), .ecclesiastes: .init(title: "Ecclesiastes"), .songOfSolomon: .init(title: "Song of Solomon"), .isaiah: .init(title: "Isaiah"), .jeremiah: .init(title: "Jeremiah"),
        .lamentations: .init(title: "Lamentations"), .ezekiel: .init(title: "Ezekiel"), .daniel: .init(title: "Daniel"), .hosea: .init(title: "Hosea"), .joel: .init(title: "Joel"),
        .amos: .init(title: "Amos"), .obadiah: .init(title: "Obadiah"), .jonah: .init(title: "Jonah"), .micah: .init(title: "Micah"), .nahum: .init(title: "Nahum"),
        .habakkuk: .init(title: "Habakkuk"), .zephaniah: .init(title: "Zephaniah"), .haggai: .init(title: "Haggai"), .zechariah: .init(title: "Zechariah"), .malachi: .init(title: "Malachi"),
        .matthew: .init(title: "Matthew"), .mark: .init(title: "Mark"), .luke: .init(title: "Luke"), .john: .init(title: "John"), .acts: .init(title: "Acts"),
        .romans: .init(title: "Romans"), ._1corinthians: .init(title: "1 Corinthians"), ._2corinthians: .init(title: "2 Corinthians"), .galatians: .init(title: "Galatians"), .ephesians: .init(title: "Ephesians"),
        .philippians: .init(title: "Philippians"), .colossians: .init(title: "Colossians"), ._1thessalonians: .init(title: "1 Thessalonians"), ._2thessalonians: .init(title: "2 Thessalonians"),
        ._1timothy: .init(title: "1 Timothy"), ._2timothy: .init(title: "2 Timothy"), .titus: .init(title: "Titus"), .philemon: .init(title: "Philemon"), .hebrews: .init(title: "Hebrews"),
        .james: .init(title: "James"), ._1peter: .init(title: "1 Peter"), ._2peter: .init(title: "2 Peter"), ._1john: .init(title: "1 John"), ._2john: .init(title: "2 John"), ._3john: .init(title: "3 John"), .jude: .init(title: "Jude"), .revelation: .init(title: "Revelation")
    ]
}

    // Single intent that defaults to Bible and autocompletes the book parameter
@MainActor
struct ScriptureSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Scripture"
    static var description = IntentDescription("Opens a scripture in JW Library. Defaults to Bible.")
    
    @Parameter(title: "Source")
    var source: ScriptureSource
    
    @Parameter(title: "Book")
    var book: BibleBook?
    
    @Parameter(title: "Chapter")
    var chapter: Int?
    
    @Parameter(title: "Verse")
    var verse: Int?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\ScriptureSearchIntent.$book) \(\ScriptureSearchIntent.$chapter) \(\ScriptureSearchIntent.$verse)")
    }
    
    static var openAppWhenRun = true
    
    func perform() async throws -> some IntentResult {
        switch source {
        case .bible:
            guard let book else { return .result() }
                // Validate ranges using metadata
            let maxChapter = kChapterCountByBook[book] ?? 0
            var safeChapter = chapter ?? 0
            if safeChapter < 0 { safeChapter = 0 }
            if maxChapter > 0 && safeChapter > maxChapter { safeChapter = maxChapter }
            
            var safeVerse = verse ?? 0
            if safeVerse < 0 { safeVerse = 0 }
                // We don't have per-chapter verse counts inline; apply a conservative upper bound
                // TODO: Plug in per-chapter verse counts here for precise validation.
            if safeVerse > kConservativeMaxVerse { safeVerse = kConservativeMaxVerse }
            
            let bookCode = String(format: "%02d", book.rawValue)
            let ch = String(format: "%03d", safeChapter)
            let vs = String(format: "%03d", safeVerse)
            if let url = URL(string: "jwlibrary:///finder?srcid=jwlshare&wtlocale=E&prefer=lang&bible=\(bookCode)\(ch)\(vs)&pub=nwtsty") {
                try await NSWorkspace.shared.open(url, configuration: .init())
            }
        default:
                // For now we only implement Bible. Future: use `term` for other sources.
            break
        }
        return .result()
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
