import SwiftUI

struct CategoryDetailView: View {
    let category: ScanResult.CategoryResult

    var body: some View {
        List {
            if !category.identifiers.isEmpty {
                Section {
                    ForEach(category.identifiers) { ident in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(ident.name)
                                    .font(.headline)
                                Spacer()
                                StatusIndicator(
                                    isLeaking: ident.isLeaking,
                                    isSpoofed: ident.isSpoofed
                                )
                            }

                            Text(ident.description)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Divider()

                            HStack {
                                Text("Real value:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(ident.realValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(ident.isLeaking ? .red : .primary)
                                    .multilineTextAlignment(.trailing)
                            }

                            if ident.isSpoofed {
                                HStack {
                                    Text("Spoofed:")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    Spacer()
                                    Text(ident.spoofedValue)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .multilineTextAlignment(.trailing)
                                }
                            }

                            if !ident.isAvailable {
                                Text("Not available on this device")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Text("No identifiers available")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(category.name)
    }
}

struct StatusIndicator: View {
    let isLeaking: Bool
    let isSpoofed: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLeaking {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                Text("LEAK")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
            } else if isSpoofed {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("SPOOFED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            } else {
                Image(systemName: "shield")
                    .foregroundColor(.gray)
                    .font(.caption)
                Text("UNHOOKED")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isLeaking ? Color.red.opacity(0.15) :
                      isSpoofed ? Color.green.opacity(0.15) :
                      Color.gray.opacity(0.15))
        )
    }
}
