import Darwin
import Foundation

/// Picks a non-loopback IPv4 on an `en*` interface (typically Wi‑Fi `en0`) for same‑LAN URLs.
enum LocalIPv4Address {
    static func preferredForLAN() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var byName: [String: String] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            defer { ptr = p.pointee.ifa_next }
            let interface = p.pointee

            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(
                addr, socklen_t(addr.pointee.sa_len),
                &hostname, socklen_t(hostname.count),
                nil, 0,
                NI_NUMERICHOST
            ) == 0 else { continue }

            let ipEnd = hostname.firstIndex(of: 0) ?? hostname.endIndex
            let ip = String(decoding: hostname[..<ipEnd].map { UInt8(bitPattern: $0) }, as: UTF8.self)
            guard !ip.hasPrefix("127."), !ip.hasPrefix("169.254.") else { continue }

            if byName[name] == nil { byName[name] = ip }
        }

        for key in ["en0", "en1", "en2", "en3", "en4"] {
            if let ip = byName[key] { return ip }
        }
        return byName.keys.sorted().compactMap { byName[$0] }.first
    }
}
