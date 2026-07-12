import Darwin
import Foundation

public enum UnixSocketError: LocalizedError {
    case pathTooLong
    case systemCall(String, Int32)
    case invalidPayload

    public var errorDescription: String? {
        switch self {
        case .pathTooLong: "Unix socket path is too long"
        case let .systemCall(name, code): "\(name) failed: \(String(cString: strerror(code)))"
        case .invalidPayload: "Socket payload was not a valid hook event"
        }
    }
}

private func makeAddress(path: String) throws -> sockaddr_un {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8CString)
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard bytes.count <= capacity else { throw UnixSocketError.pathTooLong }
    withUnsafeMutableBytes(of: &address.sun_path) { destination in
        destination.initializeMemory(as: UInt8.self, repeating: 0)
        bytes.withUnsafeBytes { source in
            destination.copyBytes(from: source)
        }
    }
    return address
}

public enum UnixSocketClient {
    public static func send(_ event: HookEvent, to socketURL: URL) throws {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw UnixSocketError.systemCall("socket", errno) }
        defer { Darwin.close(descriptor) }

        var address = try makeAddress(path: socketURL.path)
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { throw UnixSocketError.systemCall("connect", errno) }

        var payload = try JSONEncoder().encode(event)
        payload.append(0x0A)
        let result = payload.withUnsafeBytes { bytes in
            Darwin.write(descriptor, bytes.baseAddress, bytes.count)
        }
        guard result == payload.count else { throw UnixSocketError.systemCall("write", errno) }
    }
}

public final class UnixSocketServer: @unchecked Sendable {
    public typealias Handler = @Sendable (HookEvent) async -> Void

    private let socketURL: URL
    private let handler: Handler
    private let queue = DispatchQueue(label: "com.tx0zero.ThinkBreak.socket")
    private let lock = NSLock()
    private var descriptor: Int32 = -1
    private var isRunning = false

    public init(socketURL: URL, handler: @escaping Handler) throws {
        self.socketURL = socketURL
        self.handler = handler
    }

    public func start() throws {
        try FileManager.default.createDirectory(
            at: socketURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        unlink(socketURL.path)

        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw UnixSocketError.systemCall("socket", errno) }
        var address = try makeAddress(path: socketURL.path)
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            Darwin.close(fd)
            throw UnixSocketError.systemCall("bind", errno)
        }
        guard Darwin.listen(fd, 8) == 0 else {
            Darwin.close(fd)
            throw UnixSocketError.systemCall("listen", errno)
        }

        lock.lock()
        descriptor = fd
        isRunning = true
        lock.unlock()
        queue.async { [weak self] in self?.acceptLoop() }
    }

    public func stop() {
        lock.lock()
        guard isRunning else { lock.unlock(); return }
        isRunning = false
        let fd = descriptor
        descriptor = -1
        lock.unlock()
        Darwin.shutdown(fd, SHUT_RDWR)
        Darwin.close(fd)
        unlink(socketURL.path)
    }

    deinit { stop() }

    private func acceptLoop() {
        while runningDescriptor() >= 0 {
            let client = Darwin.accept(runningDescriptor(), nil, nil)
            if client < 0 {
                if !currentlyRunning() { return }
                continue
            }
            handle(client: client)
        }
    }

    private func handle(client: Int32) {
        defer { Darwin.close(client) }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(client, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
            if data.contains(0x0A) { break }
        }
        guard let newline = data.firstIndex(of: 0x0A) else { return }
        let payload = data[..<newline]
        guard let event = try? JSONDecoder().decode(HookEvent.self, from: payload) else { return }
        Task { await handler(event) }
    }

    private func runningDescriptor() -> Int32 {
        lock.lock(); defer { lock.unlock() }
        return isRunning ? descriptor : -1
    }

    private func currentlyRunning() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return isRunning
    }
}
