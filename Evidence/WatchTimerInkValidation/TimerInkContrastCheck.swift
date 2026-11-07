import Foundation

private enum WatchTimerInkStyle {
    static func opacity(on hex: String, usingLightInk: Bool, isLuminanceReduced: Bool = false) -> Double {
        // Reduced luminance keeps opaque ink.
        guard !isLuminanceReduced else { return 1 }
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard normalized.count == 6, let value = UInt32(normalized, radix: 16) else { return 1 }
        let background = [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)].map { $0 / 255 }
        let ink = usingLightInk ? 1.0 : 0.0
        let composite = background.map { ink * 0.7 + $0 * 0.3 }
        let backgroundLuminance = luminance(background)
        let inkLuminance = luminance(composite)
        let contrast = (max(backgroundLuminance, inkLuminance) + 0.05) / (min(backgroundLuminance, inkLuminance) + 0.05)
        // Fade timer ink only when the composite retains at least 4.5:1 contrast.
        return contrast >= 4.5 ? 0.7 : 1
    }

    private static func luminance(_ channels: [Double]) -> Double {
        let linear = channels.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}

@main
struct TimerInkCheck {
    struct Case: Decodable { let hex: String; let light: Bool; let expected: Double; let referenceContrast: Double? }
    static func main() throws {
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        var reduced = 0
        var opaque = 0
        var minimumContrast = Double.infinity
        for item in cases {
            let actual = WatchTimerInkStyle.opacity(on: item.hex, usingLightInk: item.light)
            precondition(actual == item.expected, "Unexpected opacity for \(item.hex), light=\(item.light): \(actual) vs \(item.expected)")
            precondition(WatchTimerInkStyle.opacity(on: item.hex, usingLightInk: item.light, isLuminanceReduced: true) == 1, "Reduced luminance must retain opaque ink")
            if actual == 0.7 {
                reduced += 1
                minimumContrast = min(minimumContrast, item.referenceContrast!)
                precondition(item.referenceContrast! >= 4.5)
            } else { opaque += 1 }
        }
        let summary: [String: Any] = ["passed": true, "cases": cases.count, "normalOpacityChecks": cases.count, "reducedLuminanceChecks": cases.count, "reducedDecisions": reduced, "opaqueDecisions": opaque, "minimumReducedContrast": minimumContrast, "contrastCriterion": 4.5]
        let data = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
}
