import SwiftUI
import AVFoundation
import Vision
@preconcurrency import VisionKit
import NaturalLanguage

// MARK: - Scan Mode

enum ScanMode: Identifiable {
    case barcode
    case productName
    case expiryDate

    var id: String {
        switch self {
        case .barcode:     return "barcode"
        case .productName: return "name"
        case .expiryDate:  return "date"
        }
    }

    var navTitle: String {
        switch self {
        case .barcode:     return "Scan Barcode"
        case .productName: return "Scan Product Name"
        case .expiryDate:  return "Scan Expiry Date"
        }
    }

    var hint: String {
        switch self {
        case .barcode:     return "Point at the barcode — name & brand fill automatically"
        case .productName: return "Tap the product name on the packaging"
        case .expiryDate:  return "Point at the expiry / best by / use by date — fills automatically"
        }
    }
}

// MARK: - Scan Field Result

enum ScanFieldResult {
    case name(String)
    case date(Date)
    case product(name: String, brand: String)
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
        let recognizedTypes: Set<DataScannerViewController.RecognizedDataType>
        switch mode {
        case .barcode:
            recognizedTypes = [.barcode()]
        case .productName, .expiryDate:
            recognizedTypes = [.text(languages: ["en-US"])]
        }

        let vc = DataScannerViewController(
            recognizedDataTypes: recognizedTypes,
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        context.coordinator.scanner = vc
        try? vc.startScanning()

        // Cancel button
        let cancelBtn = UIButton(type: .system)
        var cancelConfig = UIButton.Configuration.plain()
        cancelConfig.title = "Cancel"
        cancelConfig.baseForegroundColor = .white
        cancelConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        cancelConfig.background.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        cancelConfig.background.cornerRadius = 16
        var titleAttr = AttributeContainer()
        titleAttr.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cancelConfig.attributedTitle = AttributedString("Cancel", attributes: titleAttr)
        cancelBtn.configuration = cancelConfig
        cancelBtn.addTarget(context.coordinator, action: #selector(Coordinator.cancelTapped), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(cancelBtn)

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
            cancelBtn.leadingAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            cancelBtn.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            titleLabel.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: cancelBtn.centerYAnchor)
        ])

        // Hint / status label at bottom
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
        context.coordinator.hintLabel = hintLabel

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

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
        Task { @MainActor in coordinator.invalidateTimer() }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let mode: ScanMode
        let onComplete: (ScanFieldResult) -> Void
        let onCancel: () -> Void
        private var done = false
        private var debounceTimer: Timer?
        weak var scanner: DataScannerViewController?
        weak var hintLabel: UILabel?

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
            guard !done else { return }
            handleItems(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !done else { return }
            handleItems(allItems)
        }

        private func handleItems(_ allItems: [RecognizedItem]) {
            switch mode {
            case .barcode:
                let barcodes = allItems.compactMap { item -> String? in
                    guard case .barcode(let b) = item else { return nil }
                    return b.payloadStringValue
                }
                if let barcode = barcodes.first {
                    handleBarcode(barcode)
                }
            case .expiryDate:
                scheduleProcess(allItems)
            case .productName:
                break
            }
        }

        private func handleBarcode(_ barcode: String) {
            guard !done, !barcode.isEmpty else { return }
            done = true
            scanner?.stopScanning()
            hintLabel?.text = "Looking up product…"

            Task {
                let result = await OpenFoodFacts.lookup(barcode: barcode)
                switch result {
                case .found(let name, let brand):
                    onComplete(.product(name: name, brand: brand))
                case .notFound:
                    done = false
                    hintLabel?.text = "This product is not registered for barcode scanning. Please use the name scanner instead."
                    try? scanner?.startScanning()
                case .networkError:
                    done = false
                    hintLabel?.text = "Network error. Check your connection and try again."
                    try? scanner?.startScanning()
                }
            }
        }

        private func scheduleProcess(_ allItems: [RecognizedItem]) {
            let texts = allItems.compactMap { item -> String? in
                guard case .text(let t) = item else { return nil }
                return t.transcript
            }
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
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

// MARK: - Open Food Facts

enum OpenFoodFacts {
    enum LookupResult {
        case found(name: String, brand: String)
        case notFound
        case networkError
    }

    static func lookup(barcode: String) async -> LookupResult {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=product_name,brands") else {
            return .notFound
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .notFound
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int, status == 1,
                  let product = json["product"] as? [String: Any] else {
                return .notFound
            }
            let name  = (product["product_name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let brand = (product["brands"]       as? String ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return .notFound }
            return .found(name: name, brand: brand)
        } catch {
            return .networkError
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

    nonisolated static func clean(_ raw: String) -> String {
        var s = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let letters = s.filter { $0.isLetter }
        guard letters.count >= 2 else { return raw.trimmingCharacters(in: .whitespaces) }

        for pattern in rejectPatterns {
            if s.uppercased().range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return raw.trimmingCharacters(in: .whitespaces)
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
            return raw.trimmingCharacters(in: .whitespaces)
        }

        return s.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Date Parser

enum DateParser {

    private static let expiryKeywords: [String] = [
        "BEST IF USED BY", "BEST BEFORE END", "BEST BEFORE", "EXPIRATION DATE",
        "EXPIRY DATE", "EXP DATE", "SELL BY", "BEST BY",
        "USE BY", "EXPIRES", "EXPIRY", "EXP", "BBD", "BB"
    ]

    private static let mfgKeywords: [String] = [
        "MANUFACTURED", "MANUFACTURE DATE", "MANUFACTURING DATE",
        "PRODUCTION DATE", "PACKED ON", "PACK DATE",
        "MFG DATE", "MFD DATE", "MFG", "MFD"
    ]

    nonisolated static func extract(from texts: [String]) -> Date? {
        // First pass: strings that contain an expiry keyword (most reliable)
        for text in texts {
            let u = text.uppercased()
            guard !mfgKeywords.contains(where: { u.contains($0) }) else { continue }
            if expiryKeywords.contains(where: { u.contains($0) }), let d = parse(text) { return d }
        }
        // Second pass: any string that parses to a valid future-ish date
        for text in texts {
            let u = text.uppercased()
            guard !mfgKeywords.contains(where: { u.contains($0) }) else { continue }
            if let d = parse(text) { return d }
        }
        return nil
    }

    nonisolated static func parse(_ raw: String) -> Date? {
        var s = raw.uppercased()

        for kw in expiryKeywords { s = s.replacingOccurrences(of: kw, with: " ") }

        // Strip common punctuation used before dates (e.g. "EXP: 12/2026")
        s = s.replacingOccurrences(of: ":", with: " ")
        s = s.replacingOccurrences(of: ",", with: " ")

        s = fixOCRDigits(s)

        // Normalize separators between digits (. or - → /)
        var chars = Array(s)
        for i in 1 ..< chars.count - 1 {
            if (chars[i] == "." || chars[i] == "-"),
               chars[i-1].isNumber, chars[i+1].isNumber {
                chars[i] = "/"
            }
        }
        s = String(chars)

        // Normalize separators between letter/digit boundaries (e.g. JAN-2026 → JAN/2026)
        s = s.replacingOccurrences(of: #"([A-Z])-(\d)"#, with: "$1/$2", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(\d)-([A-Z])"#, with: "$1/$2", options: .regularExpression)
        s = s.replacingOccurrences(of: #"([A-Z])\.(\d)"#, with: "$1/$2", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(\d)\.([A-Z])"#, with: "$1/$2", options: .regularExpression)

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
            // ── ISO 8601 ──────────────────────────────────────────────────
            (#"\d{4}/\d{1,2}/\d{1,2}"#,              "yyyy/M/d",      false),

            // ── Numeric / separator ───────────────────────────────────────
            (#"\d{1,2}/\d{1,2}/\d{4}"#,              "M/d/yyyy",      false),
            (#"\d{1,2}/\d{1,2}/\d{2}"#,              "M/d/yy",        false),

            // ── Slash-separated with 3-letter month ───────────────────────
            (#"\d{1,2}/[A-Z]{3}/\d{4}"#,             "d/MMM/yyyy",    false),
            (#"\d{1,2}/[A-Z]{3}/\d{2}"#,             "d/MMM/yy",      false),
            (#"[A-Z]{3}/\d{1,2}/\d{4}"#,             "MMM/d/yyyy",    false),

            // ── Slash-separated with full month name ──────────────────────
            (#"\d{1,2}/[A-Z]{4,9}/\d{4}"#,           "d/MMMM/yyyy",   false),
            (#"[A-Z]{4,9}/\d{1,2}/\d{4}"#,           "MMMM/d/yyyy",   false),

            // ── Space-separated with full month name ──────────────────────
            (#"[A-Z]{4,9} \d{1,2} \d{4}"#,           "MMMM d yyyy",   false),
            (#"\d{1,2} [A-Z]{4,9} \d{4}"#,           "d MMMM yyyy",   false),
            (#"[A-Z]{4,9} \d{4}"#,                   "MMMM yyyy",     true),
            (#"[A-Z]{4,9} \d{2}"#,                   "MMMM yy",       true),

            // ── Space-separated with 3-letter month ───────────────────────
            (#"[A-Z]{3} \d{1,2} \d{4}"#,             "MMM d yyyy",    false),
            (#"\d{1,2} [A-Z]{3} \d{4}"#,             "d MMM yyyy",    false),
            (#"[A-Z]{3} \d{4}"#,                     "MMM yyyy",      true),
            (#"[A-Z]{3} \d{2}"#,                     "MMM yy",        true),

            // ── Compact no-space (01JAN2026, 01JAN26) ─────────────────────
            (#"\d{2}[A-Z]{3}\d{4}"#,                 "ddMMMyyyy",     false),
            (#"\d{2}[A-Z]{3}\d{2}"#,                 "ddMMMyy",       false),

            // ── Month/year only (numeric) ─────────────────────────────────
            (#"\d{2}/\d{4}"#,                        "MM/yyyy",       true),
            (#"\d{1}/\d{4}"#,                        "M/yyyy",        true),
            (#"\d{2}/\d{2}"#,                        "MM/yy",         true),

            // ── Compact no-separator ──────────────────────────────────────
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

    nonisolated private static func fixOCRDigits(_ s: String) -> String {
        let digitOrSep = #"[0-9\/\.\- ]"#
        var result = s
        let replacements: [(String, String)] = [
            // Common letter/digit OCR confusion in date strings
            (#"(?<=\#(digitOrSep))O(?=\#(digitOrSep))"#, "0"),
            (#"(?<=\#(digitOrSep))[Il](?=\#(digitOrSep))"#, "1"),
            (#"(?<=\#(digitOrSep))S(?=\#(digitOrSep))"#, "5"),
            (#"(?<=\#(digitOrSep))Z(?=\#(digitOrSep))"#, "2"),
            (#"(?<=\#(digitOrSep))B(?=\#(digitOrSep))"#, "8"),
            (#"(?<=\#(digitOrSep))G(?=\#(digitOrSep))"#, "6"),
            (#"(?<=\#(digitOrSep))q(?=\#(digitOrSep))"#, "9"),
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
