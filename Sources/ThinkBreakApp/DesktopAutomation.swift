import AppKit
import ApplicationServices
import Foundation
import ThinkBreakCore

struct OriginWindow {
    let processID: pid_t
    let bundleIdentifier: String?
    let title: String?
    let focusedElement: AXUIElement?
}

@MainActor
final class DesktopAutomation {
    private var origins: [String: OriginWindow] = [:]
    private let chrome = ChromeController()

    func captureOrigin(sessionID: String) {
        guard let application = NSWorkspace.shared.frontmostApplication else { return }
        origins[sessionID] = OriginWindow(
            processID: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            title: focusedWindowTitle(processID: application.processIdentifier),
            focusedElement: focusedUIElement(processID: application.processIdentifier)
        )
    }

    func open(profile: ContentProfile) async throws {
        try await chrome.open(profile: profile)
    }

    func pauseMedia() throws {
        try chrome.pauseMedia()
    }

    func restoreOrigin(sessionID: String) {
        guard let origin = origins.removeValue(forKey: sessionID) else { return }
        let application = NSRunningApplication(processIdentifier: origin.processID)
            ?? origin.bundleIdentifier.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first }
        application?.activate(options: [.activateAllWindows])

        guard AXIsProcessTrusted(), let application else { return }
        let axApplication = AXUIElementCreateApplication(application.processIdentifier)
        guard let title = origin.title,
              let window = windows(of: axApplication).first(where: { windowTitle($0) == title }) else { return }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        if let focusedElement = origin.focusedElement {
            AXUIElementSetAttributeValue(focusedElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
    }

    func discardOrigin(sessionID: String) {
        origins.removeValue(forKey: sessionID)
    }

    func preview(profile: ContentProfile) async throws {
        try await chrome.open(profile: profile)
    }

    func testChromeScripting() throws -> String {
        try chrome.testScripting()
    }

    private func focusedWindowTitle(processID: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let application = AXUIElementCreateApplication(processID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = value else { return nil }
        return windowTitle(window as! AXUIElement)
    }

    private func focusedUIElement(processID: pid_t) -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        let application = AXUIElementCreateApplication(processID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let element = value else { return nil }
        return (element as! AXUIElement)
    }

    private func windows(of application: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private func windowTitle(_ window: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}

actor DesktopEffects: SessionEffects {
    private let automation: DesktopAutomation
    private let notify: @MainActor @Sendable (String) -> Void

    init(automation: DesktopAutomation, notify: @escaping @MainActor @Sendable (String) -> Void) {
        self.automation = automation
        self.notify = notify
    }

    func captureOrigin(sessionID: String) async {
        await automation.captureOrigin(sessionID: sessionID)
    }

    func open(profile: ContentProfile) async {
        do { try await automation.open(profile: profile) }
        catch { await notify("打开等待内容失败：\(error.localizedDescription)") }
    }

    func pauseMedia() async {
        do { try await automation.pauseMedia() }
        catch { await notify("暂停网页媒体失败：\(error.localizedDescription)") }
    }

    func restoreOrigin(sessionID: String) async {
        await automation.restoreOrigin(sessionID: sessionID)
    }

    func discardOrigin(sessionID: String) async {
        await automation.discardOrigin(sessionID: sessionID)
    }

    func reportWarning(_ message: String) async {
        await notify(message)
    }
}
