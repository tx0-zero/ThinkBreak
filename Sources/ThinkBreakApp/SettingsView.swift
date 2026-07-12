import SwiftUI
import ThinkBreakCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let preview: () -> Void
    let testChrome: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            profileList.frame(width: 210)
            Divider()
            detail.frame(minWidth: 430, minHeight: 430)
        }
        .frame(width: 680, height: 470)
    }

    private var profileList: some View {
        VStack(spacing: 8) {
            List(model.settings.profiles, selection: $model.selectedProfileID) { profile in
                HStack {
                    Image(systemName: profile.kind == .media ? "play.rectangle" : "book")
                    Text(profile.name)
                    Spacer()
                    if model.settings.activeProfileID == profile.id {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .tag(profile.id)
            }
            HStack {
                Button(action: model.addProfile) { Image(systemName: "plus") }
                Button(action: model.removeSelectedProfile) { Image(systemName: "minus") }
                    .disabled(model.selectedProfileID == nil)
                Spacer()
                Button { model.moveSelected(by: -1) } label: { Image(systemName: "arrow.up") }
                Button { model.moveSelected(by: 1) } label: { Image(systemName: "arrow.down") }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("ThinkBreak 设置").font(.title2.bold())
            Toggle("启用自动切换", isOn: binding(\.isEnabled))

            if let profile = selectedProfileBinding {
                ProfileEditor(
                    profile: profile,
                    makeActive: {
                        if let id = model.selectedProfileID { model.setActive(id) }
                    },
                    preview: preview
                )
            } else {
                ContentUnavailableView("没有等待内容", systemImage: "hourglass", description: Text("点击左下角 + 添加一个网页。"))
            }

            GroupBox("触发时间") {
                VStack(alignment: .leading, spacing: 8) {
                    Stepper("任务运行 \(Int(model.settings.switchDelaySeconds)) 秒后切出", value: binding(\.switchDelaySeconds), in: 0...30, step: 1)
                    Stepper("安全时限 \(Int(model.settings.safetyTimeoutSeconds / 60)) 分钟", value: timeoutMinutes, in: 5...180, step: 5)
                }.padding(8)
            }

            GroupBox("首次使用") {
                HStack {
                    Button("授予辅助功能权限", action: model.requestAccessibilityPermission)
                    Button("Chrome 脚本设置", action: model.openChromeScriptInstructions)
                    Button("测试 Chrome", action: testChrome)
                }.padding(8)
            }

            if let message = model.message {
                Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer()
        }
        .padding(22)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ThinkBreakSettings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: keyPath] }, set: { model.settings[keyPath: keyPath] = $0 })
    }

    private var timeoutMinutes: Binding<Double> {
        Binding(
            get: { model.settings.safetyTimeoutSeconds / 60 },
            set: { model.settings.safetyTimeoutSeconds = $0 * 60 }
        )
    }

    private var selectedProfileBinding: Binding<ContentProfile>? {
        guard let id = model.selectedProfileID,
              model.settings.profiles.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { model.settings.profiles.first(where: { $0.id == id })! },
            set: { updated in
                guard let index = model.settings.profiles.firstIndex(where: { $0.id == id }) else { return }
                model.settings.profiles[index] = updated
            }
        )
    }
}

private struct ProfileEditor: View {
    @Binding var profile: ContentProfile
    let makeActive: () -> Void
    let preview: () -> Void
    @State private var urlText: String
    @State private var urlError: String?

    init(profile: Binding<ContentProfile>, makeActive: @escaping () -> Void, preview: @escaping () -> Void) {
        _profile = profile
        self.makeActive = makeActive
        self.preview = preview
        _urlText = State(initialValue: profile.wrappedValue.url.absoluteString)
    }

    var body: some View {
        GroupBox("当前内容") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("名称", text: $profile.name)
                HStack {
                    TextField("网址", text: $urlText)
                        .onSubmit(commitURL)
                    Button("保存网址", action: commitURL)
                }
                if let urlError { Text(urlError).font(.caption).foregroundStyle(.red) }
                Picker("类型", selection: $profile.kind) {
                    ForEach(ContentKind.allCases) { kind in Text(kind.displayName).tag(kind) }
                }
                Toggle("启用此内容", isOn: $profile.enabled)
                HStack {
                    Button("设为当前内容", action: makeActive)
                    Button("立即打开", action: preview)
                }
            }
            .padding(8)
        }
        .onChange(of: profile.id) { _, _ in
            urlText = profile.url.absoluteString
            urlError = nil
        }
    }

    private func commitURL() {
        let candidate = urlText.contains("://") ? urlText : "https://\(urlText)"
        guard let url = URL(string: candidate), let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            urlError = "请输入有效的 http 或 https 网址。"
            return
        }
        profile.url = url
        urlText = url.absoluteString
        urlError = nil
    }
}
