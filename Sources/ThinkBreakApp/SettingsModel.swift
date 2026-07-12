import AppKit
import ApplicationServices
import Foundation
import ThinkBreakCore

@MainActor
final class SettingsModel: ObservableObject {
    @Published var settings: ThinkBreakSettings {
        didSet { persist() }
    }
    @Published var selectedProfileID: UUID?
    @Published var message: String?

    private let repository: FileSettingsRepository

    init(repository: FileSettingsRepository = FileSettingsRepository()) {
        self.repository = repository
        let loaded = (try? repository.load()) ?? .default
        settings = loaded
        selectedProfileID = loaded.activeProfileID ?? loaded.profiles.first?.id
    }

    var activeProfile: ContentProfile? { settings.activeProfile }

    func setActive(_ id: UUID) {
        settings.activeProfileID = id
        selectedProfileID = id
    }

    func addProfile() {
        let profile = ContentProfile(
            name: "新内容",
            url: URL(string: "https://example.com/")!,
            kind: .reading
        )
        settings.profiles.append(profile)
        settings.activeProfileID = profile.id
        selectedProfileID = profile.id
    }

    func removeSelectedProfile() {
        guard let selectedProfileID,
              let index = settings.profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        settings.profiles.remove(at: index)
        let replacement = settings.profiles.indices.contains(index) ? settings.profiles[index] : settings.profiles.last
        self.selectedProfileID = replacement?.id
        if settings.activeProfileID == selectedProfileID { settings.activeProfileID = replacement?.id }
    }

    func moveSelected(by offset: Int) {
        guard let selectedProfileID,
              let source = settings.profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        let destination = source + offset
        guard settings.profiles.indices.contains(destination) else { return }
        settings.profiles.swapAt(source, destination)
    }

    func updateSelected(name: String? = nil, urlString: String? = nil, kind: ContentKind? = nil, enabled: Bool? = nil) {
        guard let selectedProfileID,
              let index = settings.profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        if let name { settings.profiles[index].name = name }
        if let urlString, let url = normalizedURL(urlString) { settings.profiles[index].url = url }
        if let kind { settings.profiles[index].kind = kind }
        if let enabled { settings.profiles[index].enabled = enabled }
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        message = trusted ? "辅助功能权限已启用。" : "请在系统设置中允许 ThinkBreak 控制窗口。"
    }

    func openChromeScriptInstructions() {
        NSWorkspace.shared.open(URL(string: "https://support.google.com/chrome/?p=applescript")!)
        message = "在 Chrome 菜单中选择“显示 > 开发者 > 允许来自 Apple 事件的 JavaScript”。"
    }

    private func persist() {
        do { try repository.save(settings) }
        catch { message = "保存设置失败：\(error.localizedDescription)" }
    }

    private func normalizedURL(_ value: String) -> URL? {
        if let url = URL(string: value), url.scheme != nil { return url }
        return URL(string: "https://\(value)")
    }
}
