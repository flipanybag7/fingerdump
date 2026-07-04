import SwiftUI

@main
struct FingerDumpApp: App {
    @StateObject private var scanner = ScannerService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanner)
        }
    }
}
