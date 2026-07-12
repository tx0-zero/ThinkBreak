import Foundation

public enum ContentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case media
    case reading

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .media: "视频 / 音频"
        case .reading: "阅读"
        }
    }
}

public struct ContentProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var url: URL
    public var kind: ContentKind
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        kind: ContentKind,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
        self.enabled = enabled
    }
}

public struct ThinkBreakSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var activeProfileID: UUID?
    public var switchDelaySeconds: TimeInterval
    public var safetyTimeoutSeconds: TimeInterval
    public var profiles: [ContentProfile]

    public init(
        isEnabled: Bool,
        activeProfileID: UUID?,
        switchDelaySeconds: TimeInterval,
        safetyTimeoutSeconds: TimeInterval,
        profiles: [ContentProfile]
    ) {
        self.isEnabled = isEnabled
        self.activeProfileID = activeProfileID
        self.switchDelaySeconds = switchDelaySeconds
        self.safetyTimeoutSeconds = safetyTimeoutSeconds
        self.profiles = profiles
    }

    public var activeProfile: ContentProfile? {
        if let activeProfileID,
           let profile = profiles.first(where: { $0.id == activeProfileID && $0.enabled }) {
            return profile
        }
        return profiles.first(where: \.enabled)
    }

    public static var `default`: ThinkBreakSettings {
        let douyin = ContentProfile(
            id: UUID(uuidString: "7C54F6E8-0C68-4D02-9F59-7D87A379B29C")!,
            name: "抖音",
            url: URL(string: "https://www.douyin.com/")!,
            kind: .media
        )
        return ThinkBreakSettings(
            isEnabled: true,
            activeProfileID: douyin.id,
            switchDelaySeconds: 2,
            safetyTimeoutSeconds: 1_800,
            profiles: [douyin]
        )
    }
}

public enum AgentHost: String, Codable, Sendable {
    case codex
    case claudeCode = "claude-code"
    case unknown
}

public enum HookEvent: Equatable, Sendable {
    case start(host: AgentHost, sessionID: String)
    case stop(host: AgentHost, sessionID: String)
    case attention(host: AgentHost, sessionID: String)

    public var sessionID: String {
        switch self {
        case let .start(_, sessionID), let .stop(_, sessionID), let .attention(_, sessionID): sessionID
        }
    }

    public var host: AgentHost {
        switch self {
        case let .start(host, _), let .stop(host, _), let .attention(host, _): host
        }
    }
}

extension HookEvent: Codable {
    private enum CodingKeys: String, CodingKey { case event, host, sessionID = "session_id" }
    private enum EventName: String, Codable { case start, stop, attention }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(EventName.self, forKey: .event)
        let host = try container.decode(AgentHost.self, forKey: .host)
        let sessionID = try container.decode(String.self, forKey: .sessionID)
        switch name {
        case .start: self = .start(host: host, sessionID: sessionID)
        case .stop: self = .stop(host: host, sessionID: sessionID)
        case .attention: self = .attention(host: host, sessionID: sessionID)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let name: EventName
        switch self {
        case .start: name = .start
        case .stop: name = .stop
        case .attention: name = .attention
        }
        try container.encode(name, forKey: .event)
        try container.encode(host, forKey: .host)
        try container.encode(sessionID, forKey: .sessionID)
    }
}
