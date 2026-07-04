import Foundation
import Combine

enum ScanState {
    case idle
    case scanning
    case completed
    case failed(String)
}

class ScannerService: ObservableObject {
    @Published var state: ScanState = .idle
    @Published var lastResult: ScanResult?
    @Published var scanHistory: [ScanResult] = []

    private let socketPath = "/var/run/fingerdumpd.sock"

    func runFullScan() {
        state = .scanning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if let result = self.sendRequest("SCAN_ALL") {
                DispatchQueue.main.async {
                    self.lastResult = result
                    self.scanHistory.append(result)
                    if self.scanHistory.count > 50 {
                        self.scanHistory.removeFirst(self.scanHistory.count - 50)
                    }
                    self.state = .completed
                }
            } else {
                DispatchQueue.main.async {
                    self.state = .failed("Cannot connect to fingerdumpd daemon. Is it running?")
                }
            }
        }
    }

    func scanCategory(_ category: Int) {
        state = .scanning

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if let result = self.sendRequest("SCAN_CAT \(category)") {
                DispatchQueue.main.async {
                    self.lastResult = result
                    self.scanHistory.append(result)
                    self.state = .completed
                }
            } else {
                DispatchQueue.main.async {
                    self.state = .failed("Cannot connect to fingerdumpd daemon.")
                }
            }
        }
    }

    private func sendRequest(_ request: String) -> ScanResult? {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = socketPath
        let pathLen = path.withCString { strlen($0) }
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            path.withCString { strcpy(ptr, $0) }
        }

        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else { return nil }
        defer { close(sock) }

        var timeout = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else { return nil }

        let reqData = Data(request.utf8)
        var sent = 0
        reqData.withUnsafeBytes { buf in
            if let base = buf.baseAddress {
                sent = write(sock, base, buf.count)
            }
        }
        guard sent == reqData.count else { return nil }

        var allData = Data()
        var buffer = [UInt8](repeating: 0, count: 131072)
        while true {
            let n = read(sock, &buffer, buffer.count)
            if n <= 0 { break }
            allData.append(contentsOf: buffer[..<n])
            if allData.count >= 65536 { break }
        }

        guard !allData.isEmpty else { return nil }

        do {
            let resp = try JSONDecoder().decode(fd_response_t.self, from: allData)

            guard resp.statusCode == 0, !resp.jsonData.isEmpty else {
                print("fd response error: \(resp.message)")
                return nil
            }

            return try JSONDecoder().decode(ScanResult.self, from: Data(resp.jsonData.utf8))
        } catch {
            print("Scan decode error: \(error)")
            return nil
        }
    }
}

private struct fd_response_t: Codable {
    let statusCode: Int
    let message: String
    let jsonData: String
}
