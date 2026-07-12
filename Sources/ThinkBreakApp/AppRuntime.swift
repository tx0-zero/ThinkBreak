import Foundation
import ThinkBreakCore

@MainActor
final class AppRuntime: ObservableObject {
    let settingsModel: SettingsModel
    let automation: DesktopAutomation
    private let coordinator: SessionCoordinator
    private var server: UnixSocketServer?

    init() {
        let settingsModel = SettingsModel()
        let automation = DesktopAutomation()
        self.settingsModel = settingsModel
        self.automation = automation
        let effects = DesktopEffects(automation: automation) { [weak settingsModel] message in
            settingsModel?.message = message
        }
        coordinator = SessionCoordinator(
            settings: { (try? FileSettingsRepository().load()) ?? .default },
            effects: effects
        )
        do {
            let coordinator = coordinator
            server = try UnixSocketServer(socketURL: ThinkBreakPaths.socketFile) { event in
                await coordinator.handle(event)
            }
            try server?.start()
        } catch {
            settingsModel.message = "启动本地事件服务失败：\(error.localizedDescription)"
        }
    }

    func previewActiveProfile() {
        guard let profile = settingsModel.activeProfile else { return }
        Task {
            do { try await automation.preview(profile: profile) }
            catch { settingsModel.message = "打开失败：\(error.localizedDescription)" }
        }
    }

    func testChromeScripting() {
        do { settingsModel.message = try automation.testChromeScripting() }
        catch { settingsModel.message = "Chrome 脚本控制不可用：\(error.localizedDescription)" }
    }
}
