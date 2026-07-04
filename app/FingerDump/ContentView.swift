import SwiftUI

struct ContentView: View {
    @EnvironmentObject var scanner: ScannerService

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { scanner.runFullScan() }) {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Run Full Scan")
                        }
                    }
                    .disabled(scanner.state == .scanning)

                    if case .scanning = scanner.state {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Scanning...")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }

                    if case .failed(let msg) = scanner.state {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                if let result = scanner.lastResult {
                    Section("Results") {
                        DashboardSummaryView(result: result)
                    }

                    Section("Categories") {
                        ForEach(result.categories) { cat in
                            NavigationLink(destination: CategoryDetailView(category: cat)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(cat.name)
                                            .font(.headline)
                                        Text("\(cat.identifiers.count) identifiers")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    LeakBadge(
                                        leaking: cat.identifiers.filter(\.isLeaking).count,
                                        total: cat.identifiers.count
                                    )
                                }
                            }
                        }
                    }

                    if !scanner.scanHistory.isEmpty {
                        Section("History") {
                            ForEach(scanner.scanHistory.reversed()) { scan in
                                HStack {
                                    Text(scan.scanId)
                                        .font(.caption)
                                    Spacer()
                                    if scan.metadata.totalLeaking > 0 {
                                        Text("\(scan.metadata.totalLeaking) leaks")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else {
                                        Text("clean")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("FingerDump")
        }
    }
}

struct LeakBadge: View {
    let leaking: Int
    let total: Int

    var body: some View {
        if leaking > 0 {
            Text("\(leaking)/\(total)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(6)
        } else {
            Text("✓ \(total)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(6)
        }
    }
}
