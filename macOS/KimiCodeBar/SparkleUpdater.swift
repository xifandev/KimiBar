import Foundation
import AppKit
import Sparkle

final class SparkleUpdater: ObservableObject {
    static let shared = SparkleUpdater()

    private let updaterController: SPUStandardUpdaterController
    private let delegate: UpdaterDelegate

    @Published var isUpdateAvailable = false
    @Published var isUpdateReadyToRestart = false
    @Published var didDownloadFail = false

    private init() {
        let delegate = UpdaterDelegate()
        self.delegate = delegate
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
        delegate.owner = self
    }

    /// 后台静默检查并下载更新（配合 SUAutomaticallyUpdate 使用）
    func checkForUpdatesInBackground() {
        updaterController.updater.checkForUpdatesInBackground()
    }

    /// 调用 Sparkle 立即安装并重启
    func restartToInstallUpdate() {
        delegate.installUpdateBlock?()
    }

    /// 静默下载失败时，打开 GitHub Releases 页面让用户手动下载
    func openGitHubReleases() {
        if let url = URL(string: "https://github.com/xifandev/KimiCodeBar/releases/") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Inner Delegate

    private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
        weak var owner: SparkleUpdater?
        var installUpdateBlock: (() -> Void)?

        func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
            DispatchQueue.main.async {
                self.owner?.isUpdateAvailable = true
                self.owner?.didDownloadFail = false
            }
        }

        func updater(_ updater: SPUUpdater, didNotFindUpdate error: Error) {
            DispatchQueue.main.async {
                self.owner?.isUpdateAvailable = false
            }
        }

        func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock: @escaping () -> Void) {
            DispatchQueue.main.async {
                self.installUpdateBlock = immediateInstallationBlock
                self.owner?.isUpdateReadyToRestart = true
                self.owner?.didDownloadFail = false
            }
        }

        func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
            DispatchQueue.main.async {
                self.owner?.didDownloadFail = true
            }
        }
    }
}
