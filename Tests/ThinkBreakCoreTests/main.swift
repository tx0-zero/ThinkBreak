import Foundation
import ThinkBreakCore

@main
enum CoreTestRunner {
    static func main() async {
        var failures: [String] = []
        var checkCount = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            checkCount += 1
            if !condition() { failures.append(message) }
        }

        let defaults = ThinkBreakSettings.default
        check(defaults.isEnabled, "default settings should be enabled")
        check(defaults.switchDelaySeconds == 2, "default delay should be 2 seconds")
        check(defaults.safetyTimeoutSeconds == 1_800, "default timeout should be 30 minutes")
        check(defaults.activeProfile?.name == "抖音", "default active profile should be 抖音")
        check(defaults.activeProfile?.kind == .media, "default profile should be media")

        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let repository = FileSettingsRepository(directory: directory)
            let initialSettings = try repository.load()
            check(initialSettings == .default, "missing settings file should load defaults")
            var customized = ThinkBreakSettings.default
            customized.switchDelaySeconds = 7
            try repository.save(customized)
            let savedSettings = try repository.load()
            check(savedSettings == customized, "saved settings should load unchanged")
            try? FileManager.default.removeItem(at: directory)
        } catch {
            failures.append("settings repository threw: \(error)")
        }

        do {
            let profile = ContentProfile(name: "小说", url: URL(string: "https://example.com/book/1")!, kind: .reading)
            let settings = ThinkBreakSettings(isEnabled: false, activeProfileID: profile.id, switchDelaySeconds: 5, safetyTimeoutSeconds: 600, profiles: [profile])
            let roundTrip = try JSONDecoder().decode(ThinkBreakSettings.self, from: JSONEncoder().encode(settings))
            check(roundTrip == settings, "settings should round trip through JSON")
        } catch {
            failures.append("settings round trip threw: \(error)")
        }

        do {
            let input = Data("{\"session_id\":\"abc-123\"}".utf8)
            let event = try HookInvocationParser.parse(eventName: "start", hostName: "codex", stdin: input)
            check(event == .start(host: .codex, sessionID: "abc-123"), "hook parser should map stdin session id")
            let fallback = try HookInvocationParser.parse(eventName: "attention", hostName: "claude-code", stdin: Data("{}".utf8), fallbackSessionID: "fallback")
            check(fallback == .attention(host: .claudeCode, sessionID: "fallback"), "hook parser should use fallback session id")
        } catch {
            failures.append("hook parser threw: \(error)")
        }

        do {
            let socketURL = FileManager.default.temporaryDirectory.appendingPathComponent("thinkbreak-\(UUID().uuidString).sock")
            let received = EventRecorder()
            let server = try UnixSocketServer(socketURL: socketURL) { event in
                await received.record(event)
            }
            try server.start()
            let event = HookEvent.start(host: .codex, sessionID: "socket-test")
            try UnixSocketClient.send(event, to: socketURL)
            try? await Task.sleep(nanoseconds: 100_000_000)
            let socketSnapshot = await received.snapshot()
            check(socketSnapshot == [event], "unix socket should deliver hook event")
            server.stop()
        } catch {
            failures.append("unix socket transport threw: \(error)")
        }

        let shortClock = ManualClock()
        let shortEffects = RecordingEffects()
        let shortCoordinator = SessionCoordinator(settings: { .default }, clock: shortClock, effects: shortEffects)
        await shortCoordinator.handle(.start(host: .codex, sessionID: "short"))
        await shortCoordinator.handle(.stop(host: .codex, sessionID: "short"))
        await shortClock.advance(by: 3)
        await Task.yield()
        let shortSnapshot = await shortEffects.snapshot()
        check(shortSnapshot == [.capture("short"), .discard("short")], "short task should not switch and should release its saved origin")

        let longClock = ManualClock()
        let longEffects = RecordingEffects()
        let longCoordinator = SessionCoordinator(settings: { .default }, clock: longClock, effects: longEffects)
        await longCoordinator.handle(.start(host: .codex, sessionID: "long"))
        await Task.yield()
        await longClock.advance(by: 2)
        await Task.yield()
        await longCoordinator.handle(.stop(host: .codex, sessionID: "long"))
        let longSnapshot = await longEffects.snapshot()
        check(longSnapshot == [.capture("long"), .open("抖音"), .pause, .restore("long")], "long task should switch, pause, and restore")

        let staleClock = ManualClock()
        let staleEffects = RecordingEffects()
        let staleCoordinator = SessionCoordinator(settings: { .default }, clock: staleClock, effects: staleEffects)
        await staleCoordinator.handle(.start(host: .codex, sessionID: "old"))
        await Task.yield()
        await staleClock.advance(by: 2)
        await Task.yield()
        await staleCoordinator.handle(.start(host: .claudeCode, sessionID: "new"))
        await staleCoordinator.handle(.stop(host: .codex, sessionID: "old"))
        let staleSnapshot = await staleEffects.snapshot()
        check(!staleSnapshot.contains(.restore("old")), "stale stop should not restore old origin")
        check(staleSnapshot.contains(.discard("old")), "stale stop should release the old saved origin")

        let attentionClock = ManualClock()
        let attentionEffects = RecordingEffects()
        let attentionCoordinator = SessionCoordinator(settings: { .default }, clock: attentionClock, effects: attentionEffects)
        await attentionCoordinator.handle(.start(host: .claudeCode, sessionID: "attention"))
        await Task.yield()
        await attentionClock.advance(by: 2)
        await Task.yield()
        await attentionCoordinator.handle(.attention(host: .claudeCode, sessionID: "attention"))
        let attentionSnapshot = await attentionEffects.snapshot()
        check(Array(attentionSnapshot.suffix(2)) == [.pause, .restore("attention")], "attention should pause and restore")

        var configuredTimeoutSettings = ThinkBreakSettings.default
        configuredTimeoutSettings.safetyTimeoutSeconds = 10
        let timeoutSettings = configuredTimeoutSettings
        let timeoutClock = ManualClock()
        let timeoutEffects = RecordingEffects()
        let timeoutCoordinator = SessionCoordinator(settings: { timeoutSettings }, clock: timeoutClock, effects: timeoutEffects)
        await timeoutCoordinator.handle(.start(host: .codex, sessionID: "timeout"))
        await Task.yield()
        await timeoutClock.advance(by: 2)
        for _ in 0..<5 { await Task.yield() }
        await timeoutClock.advance(by: 10)
        await Task.yield()
        let timeoutSnapshot = await timeoutEffects.snapshot()
        check(Array(timeoutSnapshot.suffix(3)) == [.pause, .restore("timeout"), .warning("等待内容已达到安全时限，已暂停并返回。")], "safety timeout should pause, restore, and warn")

        var configuredDisabledSettings = ThinkBreakSettings.default
        configuredDisabledSettings.isEnabled = false
        let disabledSettings = configuredDisabledSettings
        let disabledEffects = RecordingEffects()
        let disabledCoordinator = SessionCoordinator(settings: { disabledSettings }, effects: disabledEffects)
        await disabledCoordinator.handle(.start(host: .codex, sessionID: "disabled"))
        let disabledSnapshot = await disabledEffects.snapshot()
        check(disabledSnapshot.isEmpty, "disabled settings should ignore start events")

        if failures.isEmpty {
            print("PASS: \(checkCount) core checks")
        } else {
            failures.forEach { fputs("FAIL: \($0)\n", stderr) }
            exit(1)
        }
    }
}

actor ManualClock: ThinkBreakClock {
    private var now: TimeInterval = 0
    private var sleepers: [(deadline: TimeInterval, continuation: CheckedContinuation<Void, Never>)] = []

    func sleep(seconds: TimeInterval) async {
        await withCheckedContinuation { continuation in
            sleepers.append((now + seconds, continuation))
        }
    }

    func advance(by seconds: TimeInterval) {
        now += seconds
        let ready = sleepers.filter { $0.deadline <= now }
        sleepers.removeAll { $0.deadline <= now }
        ready.forEach { $0.continuation.resume() }
    }
}

enum RecordedEffect: Equatable {
    case capture(String), open(String), pause, restore(String), discard(String), warning(String)
}

actor RecordingEffects: SessionEffects {
    private var entries: [RecordedEffect] = []
    func captureOrigin(sessionID: String) async { entries.append(.capture(sessionID)) }
    func open(profile: ContentProfile) async { entries.append(.open(profile.name)) }
    func pauseMedia() async { entries.append(.pause) }
    func restoreOrigin(sessionID: String) async { entries.append(.restore(sessionID)) }
    func discardOrigin(sessionID: String) async { entries.append(.discard(sessionID)) }
    func reportWarning(_ message: String) async { entries.append(.warning(message)) }
    func snapshot() -> [RecordedEffect] { entries }
}

actor EventRecorder {
    private var events: [HookEvent] = []
    func record(_ event: HookEvent) { events.append(event) }
    func snapshot() -> [HookEvent] { events }
}
