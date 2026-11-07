import SwiftUI

public extension Color {
    init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(normalized, radix: 16) ?? 0x43D10D
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}

public extension Workload { var color: Color { Color(hex: colorHex) } }
public extension WorkSession { var color: Color { Color(hex: colorHex) } }
public extension TrackingSettings { var tint: Color { ThemePalette.color(for: themeHex) } }

public enum ThemePalette {
    public static let hexes = ["34C759", "0099FF", "30B0A8", "5856D6", "FF2D55", "FF9500"]

    public static func canonicalHex(_ hex: String) -> String {
        switch hex.replacingOccurrences(of: "#", with: "").uppercased() {
        case "43D10D", "34C759": return "34C759"
        case "2699F5", "0099FF": return "0099FF"
        case "7955EB", "5856D6": return "5856D6"
        case "F39538", "ED9438", "FF9500": return "FF9500"
        case "ED68B6", "EF4D69", "FF2D55": return "FF2D55"
        case "22B6A9", "20B5AB", "30B0A8": return "30B0A8"
        default: return hex
        }
    }

    public static func color(for hex: String) -> Color {
        switch canonicalHex(hex) {
        case "34C759": return .green
        case "0099FF": return .blue
        case "30B0A8": return .mint
        case "5856D6": return .indigo
        case "FF2D55": return .pink
        case "FF9500": return .orange
        default: return Color(hex: hex)
        }
    }
}
