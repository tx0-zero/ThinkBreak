import Foundation

public enum HookInvocationError: LocalizedError {
    case invalidEvent(String)
    case missingSessionID

    public var errorDescription: String? {
        switch self {
        case let .invalidEvent(value): "Unknown ThinkBreak hook event: \(value)"
        case .missingSessionID: "Hook payload did not include a session identifier"
        }
    }
}

public enum HookInvocationParser {
    public static func parse(
        eventName: String,
        hostName: String,
        stdin: Data,
        fallbackSessionID: String? = nil
    ) throws -> HookEvent {
        let object = (try? JSONSerialization.jsonObject(with: stdin)) as? [String: Any]
        let sessionID = ["session_id", "thread_id", "conversation_id"]
            .compactMap { object?[$0] as? String }
            .first(where: { !$0.isEmpty })
            ?? fallbackSessionID
        guard let sessionID, !sessionID.isEmpty else { throw HookInvocationError.missingSessionID }

        let host = AgentHost(rawValue: hostName) ?? .unknown
        switch eventName {
        case "start": return .start(host: host, sessionID: sessionID)
        case "stop": return .stop(host: host, sessionID: sessionID)
        case "attention": return .attention(host: host, sessionID: sessionID)
        default: throw HookInvocationError.invalidEvent(eventName)
        }
    }
}
