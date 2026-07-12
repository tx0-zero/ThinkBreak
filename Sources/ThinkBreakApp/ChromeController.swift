import AppKit
import Foundation
import ThinkBreakCore

@MainActor
final class ChromeController {
    private let defaults = UserDefaults.standard
    private let windowKey = "chromeWindowID"
    private let tabKey = "profileTabIDs"

    func open(profile: ContentProfile) async throws {
        let IDs = try ensureTab(for: profile)
        defaults.set(IDs.window, forKey: windowKey)
        var tabs = defaults.dictionary(forKey: tabKey) as? [String: Int] ?? [:]
        tabs[profile.id.uuidString] = IDs.tab
        defaults.set(tabs, forKey: tabKey)

        try activate(windowID: IDs.window, tabID: IDs.tab)
        if profile.kind == .media {
            try? await Task.sleep(nanoseconds: 450_000_000)
            try resumeVisibleMedia(windowID: IDs.window, tabID: IDs.tab)
        }
    }

    func pauseMedia() throws {
        guard let windowID = savedWindowID(), let tabID = activeTabID(windowID: windowID) else { return }
        let javascript = "Array.from(document.querySelectorAll('video,audio')).forEach(function(m){m.pause();});'paused'"
        _ = try executeJavaScript(javascript, windowID: windowID, tabID: tabID)
    }

    func testScripting() throws -> String {
        guard let windowID = savedWindowID(), let tabID = activeTabID(windowID: windowID) else {
            return "请先用“立即打开”创建等待窗口。"
        }
        _ = try executeJavaScript("document.title", windowID: windowID, tabID: tabID)
        return "Chrome 脚本控制正常。"
    }

    private func ensureTab(for profile: ContentProfile) throws -> (window: Int, tab: Int) {
        let windowID = savedWindowID()
        let tabID = (defaults.dictionary(forKey: tabKey) as? [String: Int])?[profile.id.uuidString]
        let script: String
        if let windowID {
            script = """
            tell application "Google Chrome"
              if not (exists window id \(windowID)) then error "missing-window"
              set targetWindow to window id \(windowID)
              \(tabSelectionScript(windowVariable: "targetWindow", tabID: tabID, url: profile.url.absoluteString))
            end tell
            """
            if let result = try? run(script), let parsed = parseIDs(result) { return parsed }
        }

        let newWindowScript = """
        tell application "Google Chrome"
          activate
          set targetWindow to make new window
          set URL of active tab of targetWindow to "\(appleScriptEscape(profile.url.absoluteString))"
          return (id of targetWindow as text) & "|" & (id of active tab of targetWindow as text)
        end tell
        """
        return try parseRequiredIDs(run(newWindowScript))
    }

    private func tabSelectionScript(windowVariable: String, tabID: Int?, url: String) -> String {
        if let tabID {
            return """
            repeat with tabIndex from 1 to (count of tabs of \(windowVariable))
              if id of tab tabIndex of \(windowVariable) is \(tabID) then
                set active tab index of \(windowVariable) to tabIndex
                return (id of \(windowVariable) as text) & "|" & (id of active tab of \(windowVariable) as text)
              end if
            end repeat
            set newTab to make new tab at end of tabs of \(windowVariable) with properties {URL:"\(appleScriptEscape(url))"}
            set active tab index of \(windowVariable) to (count of tabs of \(windowVariable))
            return (id of \(windowVariable) as text) & "|" & (id of newTab as text)
            """
        }
        return """
        set newTab to make new tab at end of tabs of \(windowVariable) with properties {URL:"\(appleScriptEscape(url))"}
        set active tab index of \(windowVariable) to (count of tabs of \(windowVariable))
        return (id of \(windowVariable) as text) & "|" & (id of newTab as text)
        """
    }

    private func activate(windowID: Int, tabID: Int) throws {
        let script = """
        tell application "Google Chrome"
          activate
          set targetWindow to window id \(windowID)
          repeat with tabIndex from 1 to (count of tabs of targetWindow)
            if id of tab tabIndex of targetWindow is \(tabID) then
              set active tab index of targetWindow to tabIndex
              exit repeat
            end if
          end repeat
          set index of targetWindow to 1
        end tell
        """
        _ = try run(script)
    }

    private func resumeVisibleMedia(windowID: Int, tabID: Int) throws {
        let javascript = """
        (function(){const all=[...document.querySelectorAll('video,audio')];const visible=all.find(m=>{const r=m.getBoundingClientRect();return r.width>0&&r.height>0&&r.bottom>0&&r.top<innerHeight});all.forEach(m=>{if(m!==visible)m.pause()});if(visible){visible.play().catch(()=>{});return 'playing'}return 'none'})()
        """
        _ = try executeJavaScript(javascript, windowID: windowID, tabID: tabID)
    }

    private func executeJavaScript(_ javascript: String, windowID: Int, tabID: Int) throws -> String {
        let script = """
        tell application "Google Chrome"
          set targetWindow to window id \(windowID)
          set targetTab to first tab of targetWindow whose id is \(tabID)
          return execute targetTab javascript "\(appleScriptEscape(javascript))"
        end tell
        """
        return try run(script)
    }

    private func activeTabID(windowID: Int) -> Int? {
        let result = try? run("tell application \"Google Chrome\" to return id of active tab of window id \(windowID) as text")
        return result.flatMap(Int.init)
    }

    private func savedWindowID() -> Int? {
        let value = defaults.integer(forKey: windowKey)
        return value == 0 ? nil : value
    }

    private func run(_ source: String) throws -> String {
        guard let script = NSAppleScript(source: source) else { throw ChromeAutomationError.invalidScript }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
            throw ChromeAutomationError.appleScript(message)
        }
        return result.stringValue ?? ""
    }

    private func parseRequiredIDs(_ value: String) throws -> (window: Int, tab: Int) {
        guard let result = parseIDs(value) else { throw ChromeAutomationError.invalidResponse(value) }
        return result
    }

    private func parseIDs(_ value: String) -> (window: Int, tab: Int)? {
        let parts = value.split(separator: "|")
        guard parts.count == 2, let window = Int(parts[0]), let tab = Int(parts[1]) else { return nil }
        return (window, tab)
    }

    private func appleScriptEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
}

enum ChromeAutomationError: LocalizedError {
    case invalidScript
    case appleScript(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidScript: "无法创建 Chrome 控制脚本。"
        case let .appleScript(message): message
        case let .invalidResponse(value): "Chrome 返回了无法识别的结果：\(value)"
        }
    }
}
