import Foundation

/// 通过 macOS LaunchAgent 在后台管理 kimi web 服务。
///
/// 与直接调用 Terminal.app 相比，LaunchAgent 方案：
/// - 不弹出终端窗口
/// - 服务由 launchd 管理，KimiCodeBar 退出/崩溃后仍能继续运行
/// - 可配置崩溃自动重启（KeepAlive）
///
/// 注意：当前使用 `--dangerous-bypass-auth` 关闭 bearer-token 鉴权，
/// 仅适合在本地可信网络环境使用。
final class KimiWebLaunchAgentManager: @unchecked Sendable {
    static let shared = KimiWebLaunchAgentManager()

    private let label = "com.kimicodebar.kimiweb"

    private var launchAgentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private var plistURL: URL {
        launchAgentsDir.appendingPathComponent("\(label).plist")
    }

    private var logsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/KimiCodeBar", isDirectory: true)
    }

    private var logURL: URL {
        logsDir.appendingPathComponent("kimi-web.log", isDirectory: false)
    }

    private init() {}

    // MARK: - Public

    /// 写入 plist 并加载到 launchd。
    func install() async {
        await Task.detached(priority: .utility) {
            self.ensureDirectories()
            guard let kimiPath = self.findKimiPath() else { return }

            // 若 plist 已存在且已加载，先卸载，避免 load 时报 "already loaded"
            if FileManager.default.fileExists(atPath: self.plistURL.path) {
                self.unload()
            }

            let plist = self.generatePlist(kimiPath: kimiPath)
            try? plist.write(to: self.plistURL, options: .atomic)

            self.runLaunchctl(arguments: ["load", self.plistURL.path])
        }.value
    }

    /// 启动服务。
    func start() async {
        await Task.detached(priority: .utility) { () -> Void in
            self.runLaunchctl(arguments: ["start", self.label])
        }.value
    }

    /// 停止服务。
    func stop() async {
        await Task.detached(priority: .utility) { () -> Void in
            self.runLaunchctl(arguments: ["stop", self.label])
        }.value
    }

    /// 从 launchd 卸载服务。
    func unload() {
        runLaunchctl(arguments: ["unload", plistURL.path])
    }

    /// 卸载并删除 plist 文件。
    func uninstall() async {
        await Task.detached(priority: .utility) {
            self.unload()
            try? FileManager.default.removeItem(at: self.plistURL)
        }.value
    }

    /// 检查当前是否已加载。
    func isLoaded() async -> Bool {
        await Task.detached(priority: .utility) {
            let result = self.runLaunchctl(arguments: ["list", self.label])
            return result.exitCode == 0 && result.output.contains(self.label)
        }.value
    }

    // MARK: - Private

    private func ensureDirectories() {
        try? FileManager.default.createDirectory(
            at: launchAgentsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? FileManager.default.createDirectory(
            at: logsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func findKimiPath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.kimi-code/bin/kimi",
            "\(home)/.kimi/bin/kimi",
            "/usr/local/bin/kimi",
            "/opt/homebrew/bin/kimi",
            "/usr/bin/kimi"
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    private func generatePlist(kimiPath: String) -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                kimiPath,
                "web",
                "--no-open",
                "--dangerous-bypass-auth"
            ],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
            "EnvironmentVariables": [
                "PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:\(FileManager.default.homeDirectoryForCurrentUser.path)/.kimi-code/bin:\(FileManager.default.homeDirectoryForCurrentUser.path)/.kimi/bin"
            ]
        ]

        return try! PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
    }

    @discardableResult
    private func runLaunchctl(arguments: [String]) -> (output: String, exitCode: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output.trimmingCharacters(in: .whitespacesAndNewlines), task.terminationStatus)
        } catch {
            return ("", -1)
        }
    }
}
