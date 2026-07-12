import AppKit
import SwiftUI
import ThinkBreakCore

@main
struct ThinkBreakApp: App {
    @StateObject private var runtime = AppRuntime()

    var body: some Scene {
        MenuBarExtra("ThinkBreak", systemImage: "hourglass.circle") {
            Toggle("启用自动切换", isOn: Binding(
                get: { runtime.settingsModel.settings.isEnabled },
                set: { runtime.settingsModel.settings.isEnabled = $0 }
            ))

            Menu("等待内容") {
                ForEach(runtime.settingsModel.settings.profiles.filter(\.enabled)) { profile in
                    Button {
                        runtime.settingsModel.setActive(profile.id)
                    } label: {
                        if runtime.settingsModel.settings.activeProfileID == profile.id {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }
            }

            Button("立即打开当前内容", action: runtime.previewActiveProfile)
            Divider()
            SettingsLink { Text("设置…") }
            Button("退出 ThinkBreak") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(
                model: runtime.settingsModel,
                preview: runtime.previewActiveProfile,
                testChrome: runtime.testChromeScripting
            )
        }
    }
}
