import Foundation

struct ScanResult: Codable, Identifiable {
    var id: String { scanId }
    let scanId: String
    let deviceName: String
    let iosVersion: String
    let timestamp: String
    let metadata: ScanMetadata
    let categories: [CategoryResult]

    struct ScanMetadata: Codable {
        let totalIdentifiers: Int
        let totalLeaking: Int
        let totalSpoofed: Int
    }

    struct CategoryResult: Codable, Identifiable {
        var id: Int { category }
        let category: Int
        let name: String
        let count: Int
        let identifiers: [IdentifierResult]
    }

    struct IdentifierResult: Codable, Identifiable {
        var id: String { key }
        let key: String
        let name: String
        let description: String
        let realValue: String
        let spoofedValue: String
        let isSpoofed: Bool
        let isLeaking: Bool
        let isAvailable: Bool
    }
}
