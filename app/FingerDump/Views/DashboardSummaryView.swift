import SwiftUI

struct DashboardSummaryView: View {
    let result: ScanResult

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatBox(
                    value: "\(result.metadata.totalIdentifiers)",
                    label: "Identifiers",
                    color: .blue
                )
                StatBox(
                    value: "\(result.metadata.totalSpoofed)",
                    label: "Spoofed",
                    color: .green
                )
                StatBox(
                    value: "\(result.metadata.totalLeaking)",
                    label: "Leaking",
                    color: result.metadata.totalLeaking > 0 ? .red : .green
                )
            }

            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.secondary)
                Text(result.deviceName)
                    .font(.subheadline)
                Spacer()
                Text("iOS \(result.iosVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(result.timestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(result.scanId)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
