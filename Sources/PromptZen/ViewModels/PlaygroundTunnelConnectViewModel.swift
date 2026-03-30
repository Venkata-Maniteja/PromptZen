import Combine
import Foundation

@MainActor
final class PlaygroundTunnelConnectViewModel: ObservableObject {
    enum Phase: Equatable {
        case disconnected
        case busy(String)
        case connected(local: String, lanURL: String?, publicURL: String?, tunnelWarning: String?)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .disconnected
    /// Full bearer token for `Authorization` (also embedded in the served HTML).
    @Published private(set) var tunnelSecret: String = ""

    private let httpServer = PlaygroundTunnelHTTPServer()
    private let ngrok = NgrokTunnelService()

    var isConnected: Bool {
        if case .connected = phase { return true }
        return false
    }

    var isBusy: Bool {
        if case .busy = phase { return true }
        return false
    }

    func connect(portString: String, ngrokExecutablePath: String) async {
        guard let port = Self.parsePort(portString) else {
            phase = .failed("Port must be between 1 and 65535.")
            return
        }

        phase = .busy("Starting local server…")
        tunnelSecret = ""

        let secret = PlaygroundTunnelChatService.ensureTunnelSecret()

        do {
            try await httpServer.start(port: port, tunnelSecret: secret)
            let local = "http://127.0.0.1:\(port)/"
            let lanURL = LocalIPv4Address.preferredForLAN().map { "http://\($0):\(port)/" }
            tunnelSecret = secret

            phase = .busy("Starting ngrok tunnel…")
            var publicURL: String?
            var warning: String?

            if let exe = NgrokTunnelService.resolveExecutable(customPath: ngrokExecutablePath) {
                do {
                    let apiRoot = try ngrok.start(port: port, executable: exe)
                    do {
                        publicURL = try await NgrokTunnelService.fetchPublicURL(
                            apiRoot: apiRoot,
                            localForwardPort: port
                        )
                    } catch {
                        warning = "ngrok is running but the public URL could not be read: \(error.localizedDescription)"
                    }
                } catch {
                    warning = "Could not start ngrok: \(error.localizedDescription)"
                }
            } else {
                warning = "ngrok not found. Install: brew install ngrok/ngrok/ngrok, then ngrok config add-authtoken <token>. Or run “which ngrok” in Terminal and paste that path into “ngrok executable path”. Local URL still works."
            }

            phase = .connected(local: local, lanURL: lanURL, publicURL: publicURL, tunnelWarning: warning)
        } catch {
            ngrok.stop()
            await httpServer.stop()
            tunnelSecret = ""
            phase = .failed(error.localizedDescription)
        }
    }

    func disconnect() async {
        ngrok.stop()
        await httpServer.stop()
        tunnelSecret = ""
        phase = .disconnected
    }

    private static func parsePort(_ raw: String) -> UInt16? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let v = UInt16(t), v > 0 else { return nil }
        return v
    }
}
