import Foundation

public protocol ThinkBreakClock: Sendable {
    func sleep(seconds: TimeInterval) async
}

public struct SystemClock: ThinkBreakClock {
    public init() {}
    public func sleep(seconds: TimeInterval) async {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

public protocol SessionEffects: Sendable {
    func captureOrigin(sessionID: String) async
    func open(profile: ContentProfile) async
    func pauseMedia() async
    func restoreOrigin(sessionID: String) async
    func discardOrigin(sessionID: String) async
    func reportWarning(_ message: String) async
}

public actor SessionCoordinator {
    private let settingsProvider: @Sendable () -> ThinkBreakSettings
    private let clock: any ThinkBreakClock
    private let effects: any SessionEffects

    private var currentSessionID: String?
    private var didSwitch = false
    private var delayTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    public init(
        settings: @escaping @Sendable () -> ThinkBreakSettings,
        clock: any ThinkBreakClock = SystemClock(),
        effects: any SessionEffects
    ) {
        self.settingsProvider = settings
        self.clock = clock
        self.effects = effects
    }

    deinit {
        delayTask?.cancel()
        timeoutTask?.cancel()
    }

    public func handle(_ event: HookEvent) async {
        switch event {
        case let .start(_, sessionID):
            await start(sessionID: sessionID)
        case let .stop(_, sessionID):
            await stop(sessionID: sessionID)
        case let .attention(_, sessionID):
            await attention(sessionID: sessionID)
        }
    }

    private func start(sessionID: String) async {
        let settings = settingsProvider()
        guard settings.isEnabled, let profile = settings.activeProfile else { return }

        delayTask?.cancel()
        timeoutTask?.cancel()
        currentSessionID = sessionID
        didSwitch = false
        await effects.captureOrigin(sessionID: sessionID)

        delayTask = Task { [clock] in
            await clock.sleep(seconds: settings.switchDelaySeconds)
            guard !Task.isCancelled else { return }
            await self.activate(sessionID: sessionID, profile: profile, timeout: settings.safetyTimeoutSeconds)
        }
    }

    private func activate(sessionID: String, profile: ContentProfile, timeout: TimeInterval) async {
        guard currentSessionID == sessionID else { return }
        didSwitch = true
        await effects.open(profile: profile)

        timeoutTask = Task { [clock] in
            await clock.sleep(seconds: timeout)
            guard !Task.isCancelled else { return }
            await self.timeout(sessionID: sessionID)
        }
    }

    private func stop(sessionID: String) async {
        guard currentSessionID == sessionID else {
            await effects.discardOrigin(sessionID: sessionID)
            return
        }
        delayTask?.cancel()
        timeoutTask?.cancel()
        if didSwitch {
            await effects.pauseMedia()
            await effects.restoreOrigin(sessionID: sessionID)
        } else {
            await effects.discardOrigin(sessionID: sessionID)
        }
        clearCurrent()
    }

    private func attention(sessionID: String) async {
        if currentSessionID == sessionID {
            delayTask?.cancel()
            timeoutTask?.cancel()
        }
        await effects.pauseMedia()
        await effects.restoreOrigin(sessionID: sessionID)
        if currentSessionID == sessionID { clearCurrent() }
    }

    private func timeout(sessionID: String) async {
        guard currentSessionID == sessionID else { return }
        await effects.pauseMedia()
        await effects.restoreOrigin(sessionID: sessionID)
        await effects.reportWarning("等待内容已达到安全时限，已暂停并返回。")
        clearCurrent()
    }

    private func clearCurrent() {
        currentSessionID = nil
        didSwitch = false
        delayTask = nil
        timeoutTask = nil
    }
}
