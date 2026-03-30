import Foundation

/// Starts `ngrok http 127.0.0.1:<playgroundPort>` and reads the public URL from the agent’s local HTTP API.
///
/// Ngrok v3 prefers `GET /api/endpoints` (`url` field); older agents use `GET /api/tunnels` (`public_url`).
/// We bind the agent web UI to a fixed loopback port so we always query **this** child process, not another
/// ngrok you may already have on `4040`. Child stdio is discarded so log output cannot fill a pipe and stall ngrok.
final class NgrokTunnelService: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var fragmentConfigURL: URL?

    /// Loopback port for this app’s ngrok child (avoids clashing with a separate `ngrok` using 4040).
    private static let agentWebAPIPort: UInt16 = 14_043

    static func resolveExecutable(customPath: String) -> URL? {
        let trimmed = customPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, FileManager.default.isExecutableFile(atPath: trimmed) {
            return URL(fileURLWithPath: trimmed)
        }

        let home = NSHomeDirectory()
        let candidates = [
            "/opt/homebrew/bin/ngrok",
            "/usr/local/bin/ngrok",
            "/opt/homebrew/sbin/ngrok",
            "\(home)/bin/ngrok",
            "\(home)/.local/bin/ngrok",
            "\(home)/go/bin/ngrok",
            "/opt/homebrew/opt/ngrok/bin/ngrok",
            "/usr/local/opt/ngrok/bin/ngrok",
            "/opt/homebrew/Caskroom/ngrok/latest/ngrok",
            "\(home)/Applications/ngrok",
            "/Applications/ngrok.app/Contents/MacOS/ngrok",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        // Finder-launched apps often have no Homebrew on PATH; mimic a shell login PATH.
        if let which = pathFromShellLookup() {
            return URL(fileURLWithPath: which)
        }

        return nil
    }

    /// Runs `/bin/sh -c` with PATH that includes standard Homebrew locations.
    private static func pathFromShellLookup() -> String? {
        let home = NSHomeDirectory()
        let script = """
        PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:\(home)/bin:\(home)/.local/bin:$PATH"
        command -v ngrok 2>/dev/null || true
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let line = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !line.isEmpty, line.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: line) else {
            return nil
        }
        return line
    }

    /// Writes a merge config so this child’s API is on ``agentWebAPIPort`` (merges with the user’s default ngrok config for authtoken).
    @discardableResult
    func start(port: UInt16, executable: URL) throws -> URL {
        stop()
        let fragment = FileManager.default.temporaryDirectory
            .appendingPathComponent("promptzen-ngrok-\(UUID().uuidString).yml", isDirectory: false)
        let yaml = """
        version: 3
        agent:
          web_addr: 127.0.0.1:\(Self.agentWebAPIPort)
        """
        try yaml.write(to: fragment, atomically: true, encoding: .utf8)
        fragmentConfigURL = fragment

        let p = Process()
        p.executableURL = executable
        p.arguments = ["http", "127.0.0.1:\(port)", "--config", fragment.path]
        p.standardInput = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        lock.lock()
        process = p
        lock.unlock()

        guard let apiRoot = URL(string: "http://127.0.0.1:\(Self.agentWebAPIPort)") else {
            throw NgrokTunnelError.invalidAgentAPIRoot
        }
        return apiRoot
    }

    func stop() {
        lock.lock()
        let p = process
        process = nil
        let fragment = fragmentConfigURL
        fragmentConfigURL = nil
        lock.unlock()
        p?.terminate()
        p?.waitUntilExit()
        if let fragment {
            try? FileManager.default.removeItem(at: fragment)
        }
    }

    /// Polls this child’s local API for a public `https` URL (ngrok v3 `endpoints`, else legacy `tunnels`).
    static func fetchPublicURL(apiRoot: URL, localForwardPort: UInt16, session: URLSession = .shared) async throws -> String {
        let endpoints = Self.agentAPIURL(root: apiRoot, path: "/api/endpoints")
        let tunnels = Self.agentAPIURL(root: apiRoot, path: "/api/tunnels")
        for _ in 0 ..< 60 {
            if let endpoints {
                do {
                    let (data, _) = try await session.data(from: endpoints)
                    if let url = Self.parseNgrokEndpointsJSON(data, localForwardPort: localForwardPort) {
                        return url
                    }
                } catch {
                    // API not up yet
                }
            }
            if let tunnels {
                do {
                    let (data, _) = try await session.data(from: tunnels)
                    if let url = Self.parseNgrokTunnelsJSON(data, localForwardPort: localForwardPort) {
                        return url
                    }
                } catch {
                    // API not up yet
                }
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        throw NgrokTunnelError.publicURLTimeout
    }

    private static func agentAPIURL(root: URL, path: String) -> URL? {
        guard var c = URLComponents(url: root, resolvingAgainstBaseURL: false) else { return nil }
        c.path = path
        return c.url
    }

    private static func parseNgrokEndpointsJSON(_ data: Data, localForwardPort: UInt16) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let endpoints = obj["endpoints"] as? [[String: Any]] else {
            return nil
        }
        var pairs: [(publicURL: String, upstream: String?)] = []
        for e in endpoints {
            guard let url = e["url"] as? String,
                  url.hasPrefix("https://") || url.hasPrefix("http://") else { continue }
            let upstream = (e["upstream"] as? [String: Any])?["url"] as? String
            pairs.append((url, upstream))
        }
        for pair in pairs where pair.publicURL.hasPrefix("https://") {
            if let up = pair.upstream, upstreamPortMatches(up, localPort: localForwardPort) {
                return pair.publicURL
            }
        }
        if let firstHTTPS = pairs.first(where: { $0.publicURL.hasPrefix("https://") }) {
            return firstHTTPS.publicURL
        }
        return pairs.first?.publicURL
    }

    private static func parseNgrokTunnelsJSON(_ data: Data, localForwardPort: UInt16) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tunnels = obj["tunnels"] as? [[String: Any]] else {
            return nil
        }
        var list: [(publicURL: String, addr: String?)] = []
        for t in tunnels {
            guard let pub = t["public_url"] as? String else { continue }
            let addr = (t["config"] as? [String: Any])?["addr"] as? String
            list.append((pub, addr))
        }
        for item in list where item.publicURL.hasPrefix("https://") {
            if let addr = item.addr, tunnelAddrMatchesForwardPort(addr, localPort: localForwardPort) {
                return item.publicURL
            }
        }
        if let firstHTTPS = list.first(where: { $0.publicURL.hasPrefix("https://") }) {
            return firstHTTPS.publicURL
        }
        return list.first?.publicURL
    }

    private static func upstreamPortMatches(_ upstreamURL: String, localPort: UInt16) -> Bool {
        guard let u = URL(string: upstreamURL) else { return false }
        if let p = u.port { return UInt16(p) == localPort }
        return localPort == 80
    }

    /// `config.addr` values look like `localhost:8080` or `127.0.0.1:8080`.
    private static func tunnelAddrMatchesForwardPort(_ addr: String, localPort: UInt16) -> Bool {
        if let r = addr.range(of: #":(\d+)$"#, options: .regularExpression),
           let p = UInt16(addr[r].dropFirst()) {
            return p == localPort
        }
        return false
    }
}

enum NgrokTunnelError: Error, LocalizedError {
    case publicURLTimeout
    case executableNotFound
    case invalidAgentAPIRoot

    var errorDescription: String? {
        switch self {
        case .publicURLTimeout:
            return "Timed out waiting for ngrok public URL. Run `ngrok config add-authtoken` if needed, ensure port 14043 is free (PromptZen’s tunnel uses it for the local API), then try again."
        case .executableNotFound:
            return "ngrok executable not found. Install with Homebrew or set a custom path in settings."
        case .invalidAgentAPIRoot:
            return "Internal error building ngrok local API URL."
        }
    }
}
