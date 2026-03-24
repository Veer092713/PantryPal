import SwiftUI
import AVFoundation
import Vision
@preconcurrency import VisionKit
import NaturalLanguage

// MARK: - Scan Mode

enum ScanMode: Identifiable {
    case productName
    case expiryDate

    var id: String {
        switch self {
        case .productName: return "name"
        case .expiryDate:  return "date"
        }
    }

    var navTitle: String {
        switch self {
        case .productName: return "Scan Product Name"
        case .expiryDate:  return "Scan Expiry Date"
        }
    }

    var hint: String {
        switch self {
        case .productName: return "Tap the product name on the packaging"
        case .expiryDate:  return "Point at the expiry / best by / sell by date — it fills automatically"
        }
    }
}

// MARK: - Scan Field Result

enum ScanFieldResult {
    case name(String)
    case date(Date)
}

// MARK: - Field Scanner Sheet

struct FieldScannerSheet: View {
    let mode: ScanMode
    let onComplete: (ScanFieldResult) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                FieldScannerView(
                    mode: mode,
                    onComplete: { result in
                        onComplete(result)
                        dismiss()
                    },
                    onCancel: { dismiss() }
                )
                .ignoresSafeArea()
            } else {
                ScannerUnavailableView()
            }
        }
        // Dismiss when app backgrounds so the camera session doesn't freeze on reopen
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            dismiss()
        }
    }
}

// MARK: - Field Scanner View

struct FieldScannerView: UIViewControllerRepresentable {
    let mode: ScanMode
    let onComplete: (ScanFieldResult) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(mode: mode, onComplete: onComplete, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["en-US"])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()

        // Add Cancel button directly into the UIKit view hierarchy.
        // This is required because DataScannerViewController's view captures
        // all touches — SwiftUI ZStack overlays cannot receive taps on top of it.
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cancelBtn.setTitleColor(.white, for: .normal)
        cancelBtn.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        cancelBtn.layer.cornerRadius = 16
        cancelBtn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        cancelBtn.addTarget(context.coordinator, action: #selector(Coordinator.cancelTapped), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(cancelBtn)
        NSLayoutConstraint.activate([
            cancelBtn.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            cancelBtn.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 10)
        ])

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = mode.navTitle
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.shadowColor = UIColor.black.withAlphaComponent(0.5)
        titleLabel.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: cancelBtn.centerYAnchor)
        ])

        // Hint label at the bottom
        let hintContainer = UIView()
        hintContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        hintContainer.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(hintContainer)

        let hintLabel = UILabel()
        hintLabel.text = mode.hint
        hintLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        hintLabel.textColor = .white
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            hintContainer.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            hintContainer.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            hintContainer.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),

            hintLabel.topAnchor.constraint(equalTo: hintContainer.topAnchor, constant: 14),
            hintLabel.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            hintLabel.leadingAnchor.constraint(equalTo: hintContainer.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: hintContainer.trailingAnchor, constant: -16)
        ])

        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    // stopScanning is thread-safe; timer cleanup hops to main actor.
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
        Task { @MainActor in coordinator.invalidateTimer() }
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let mode: ScanMode
        let onComplete: (ScanFieldResult) -> Void
        let onCancel: () -> Void
        private var done = false
        private var debounceTimer: Timer?

        init(mode: ScanMode, onComplete: @escaping (ScanFieldResult) -> Void, onCancel: @escaping () -> Void) {
            self.mode = mode
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func invalidateTimer() {
            debounceTimer?.invalidate()
            debounceTimer = nil
        }

        @objc func cancelTapped() { onCancel() }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !done, mode == .expiryDate else { return }
            scheduleProcess(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !done, mode == .expiryDate else { return }
            scheduleProcess(allItems)
        }

        private func scheduleProcess(_ allItems: [RecognizedItem]) {
            let texts = allItems.compactMap { item -> String? in
                guard case .text(let t) = item else { return nil }
                return t.transcript
            }
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                // Run regex-heavy date parsing on a background thread so the main
                // thread is never blocked — prevents the OS watchdog SIGKILL.
                Task { @MainActor [weak self] in
                    guard let self, !self.done else { return }
                    let date = await Task.detached(priority: .userInitiated) {
                        let merged = texts.joined(separator: " ")
                        return DateParser.extract(from: texts + [merged])
                    }.value
                    guard !self.done, let date else { return }
                    self.done = true
                    self.invalidateTimer()
                    self.onComplete(.date(date))
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didTapOn item: RecognizedItem) {
            guard !done, mode == .productName else { return }
            if case .text(let t) = item {
                done = true
                Task.detached(priority: .userInitiated) { [onComplete = self.onComplete] in
                    let cleaned = NameCleaner.clean(t.transcript)
                    await MainActor.run { onComplete(.name(cleaned)) }
                }
            }
        }
    }
}

// MARK: - Name Cleaner

enum NameCleaner {

    private static let rejectPatterns: [String] = [
        #"^\$?\d+[\.,]\d{2}$"#,
        #"^\d+\s*(g|kg|oz|lb|ml|l|fl oz)\b"#,
        #"^\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}$"#,
        #"^\d+%$"#,
        #"^[\d\s\-]{6,}$"#,
    ]

    static func clean(_ raw: String) -> String {
        var s = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let letters = s.filter { $0.isLetter }
        guard letters.count >= 2 else { return raw.trimmingCharacters(in: .whitespacesAndNewlines) }

        for pattern in rejectPatterns {
            if s.uppercased().range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return raw.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        s = s.components(separatedBy: " ").map { word -> String in
            guard word == word.uppercased(),
                  word.count > 3,
                  word.rangeOfCharacter(from: .letters) != nil
            else { return word }
            return word.capitalized
        }.joined(separator: " ")

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(s)
        if recognizer.dominantLanguage == nil {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Date Parser

enum DateParser {

    private static let expiryKeywords: [String] = [
        "BEST IF USED BY", "BEST BEFORE", "EXPIRATION DATE",
        "EXPIRY DATE", "EXP DATE", "SELL BY", "BEST BY",
        "USE BY", "EXPIRES", "EXPIRY", "EXP", "BBD", "BB"
    ]

    private static let mfgKeywords: [String] = [
        "MANUFACTURED", "MANUFACTURE DATE", "MANUFACTURING DATE",
        "PRODUCTION DATE", "PACKED ON", "PACK DATE",
        "MFG DATE", "MFD DATE", "MFG", "MFD"
    ]

    static func extract(from texts: [String]) -> Date? {
        for text in texts {
            let u = text.uppercased()
            guard !mfgKeywords.contains(where: { u.contains($0) }) else { continue }
            if expiryKeywords.contains(where: { u.contains($0) }), let d = parse(text) { return d }
        }
        for text in texts {
            let u = text.uppercased()
            guard !mfgKeywords.contains(where: { u.contains($0) }) else { continue }
            if let d = parse(text) { return d }
        }
        return nil
    }

    static func parse(_ raw: String) -> Date? {
        var s = raw.uppercased()

        for kw in expiryKeywords { s = s.replacingOccurrences(of: kw, with: " ") }

        // Strip colons and commas (e.g. "BEST BY: 12/JUN/2026" → " 12/JUN/2026")
        s = s.replacingOccurrences(of: ":", with: " ")
        s = s.replacingOccurrences(of: ",", with: " ")

        s = fixOCRDigits(s)

        // Replace dots and dashes between digits with /
        var chars = Array(s)
        for i in 1 ..< chars.count - 1 {
            if (chars[i] == "." || chars[i] == "-"),
               chars[i-1].isNumber, chars[i+1].isNumber {
                chars[i] = "/"
            }
        }
        s = String(chars)

        s = s.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")

        let now    = Date()
        let past   = Calendar.current.date(byAdding: .year, value: -2, to: now)!
        let future = Calendar.current.date(byAdding: .year, value: 10, to: now)!

        let patterns: [(String, String, Bool)] = [
            // ── ISO 8601 ──────────────────────────────────────────────
            (#"\d{4}/\d{1,2}/\d{1,2}"#,              "yyyy/M/d",      false),

            // ── Numeric / separator ───────────────────────────────────
            (#"\d{1,2}/\d{1,2}/\d{4}"#,              "M/d/yyyy",      false),
            (#"\d{1,2}/\d{1,2}/\d{2}"#,              "M/d/yy",        false),

            // ── Slash-separated with 3-letter month (12/JUN/2026) ─────
            (#"\d{1,2}/[A-Z]{3}/\d{4}"#,             "d/MMM/yyyy",    false),
            (#"\d{1,2}/[A-Z]{3}/\d{2}"#,             "d/MMM/yy",      false),
            (#"[A-Z]{3}/\d{1,2}/\d{4}"#,             "MMM/d/yyyy",    false),

            // ── Slash-separated with full month name ──────────────────
            (#"\d{1,2}/[A-Z]{4,9}/\d{4}"#,           "d/MMMM/yyyy",   false),
            (#"[A-Z]{4,9}/\d{1,2}/\d{4}"#,           "MMMM/d/yyyy",   false),

            // ── Space-separated with full month name ──────────────────
            (#"[A-Z]{4,9} \d{1,2} \d{4}"#,           "MMMM d yyyy",   false),
            (#"\d{1,2} [A-Z]{4,9} \d{4}"#,           "d MMMM yyyy",   false),
            (#"[A-Z]{4,9} \d{4}"#,                   "MMMM yyyy",     true),
            (#"[A-Z]{4,9} \d{2}"#,                   "MMMM yy",       true),

            // ── Space-separated with 3-letter month ───────────────────
            (#"[A-Z]{3} \d{1,2} \d{4}"#,             "MMM d yyyy",    false),
            (#"\d{1,2} [A-Z]{3} \d{4}"#,             "d MMM yyyy",    false),
            (#"[A-Z]{3} \d{4}"#,                     "MMM yyyy",      true),
            (#"[A-Z]{3} \d{2}"#,                     "MMM yy",        true),

            // ── Compact no-space (01JAN2026, 01JAN26) ─────────────────
            (#"\d{2}[A-Z]{3}\d{4}"#,                 "ddMMMyyyy",     false),
            (#"\d{2}[A-Z]{3}\d{2}"#,                 "ddMMMyy",       false),

            // ── Month/year only (numeric) ─────────────────────────────
            (#"\d{2}/\d{4}"#,                        "MM/yyyy",       true),
            (#"\d{1}/\d{4}"#,                        "M/yyyy",        true),
            (#"\d{2}/\d{2}"#,                        "MM/yy",         true),

            // ── Compact no-separator ──────────────────────────────────
            (#"\b\d{8}\b"#,                          "yyyyMMdd",      false),
            (#"\b\d{8}\b"#,                          "MMddyyyy",      false),
            (#"\b\d{8}\b"#,                          "ddMMyyyy",      false),
            (#"\b\d{6}\b"#,                          "MMyyyy",        true),
        ]

        for (pattern, format, monthOnly) in patterns {
            guard let range = s.range(of: pattern, options: .regularExpression) else { continue }
            fmt.dateFormat = format
            let candidate = String(s[range])
            guard let date = fmt.date(from: candidate),
                  date > past, date < future else { continue }

            if monthOnly {
                var c = Calendar.current.dateComponents([.year, .month], from: date)
                c.month! += 1
                c.day = 0
                return Calendar.current.date(from: c) ?? date
            }
            return date
        }
        return nil
    }

    private static func fixOCRDigits(_ s: String) -> String {
        let digitOrSep = #"[0-9\/\.\- ]"#
        var result = s
        let replacements: [(String, String)] = [
            (#"(?<=\#(digitOrSep))O(?=\#(digitOrSep))"#, "0"),
            (#"(?<=\#(digitOrSep))[Il](?=\#(digitOrSep))"#, "1"),
            (#"(?<=\#(digitOrSep))S(?=\#(digitOrSep))"#, "5"),
            (#"(?<=\#(digitOrSep))Z(?=\#(digitOrSep))"#, "2"),
            (#"(?<=\#(digitOrSep))B(?=\#(digitOrSep))"#, "8"),
        ]
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return result
    }
}

// MARK: - Scanner Unavailable

struct ScannerUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Scanner Unavailable")
                .font(.title2.bold())
            Text("DataScanner requires iOS 16+ and a supported device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
