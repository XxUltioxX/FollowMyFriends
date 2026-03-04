import SwiftUI

struct LogRow: View {
    let entry: LogEntry
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Timestamp
            Text(entry.formattedTime)
                .font(.system(size: 11).monospaced())
                .foregroundStyle(Color.textTertiary)
                .frame(width: 65, alignment: .leading)

            // Level badge
            Text(entry.level.badge)
                .font(.system(size: 9, weight: .bold).monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(entry.level.color.opacity(0.15))
                .foregroundStyle(entry.level.color)
                .cornerRadius(4)
                .frame(width: 55, alignment: .center)

            // Message
            Text(entry.message)
                .font(.system(size: 12).monospaced())
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(isHovered ? Color.surface : Color.clear)
        .onHover { isHovered = $0 }
    }
}
