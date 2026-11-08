import Foundation

@MainActor
extension EditorModel {
    func start() {
        guard !started else { return }
        started = true
        isBusy = true
        Task.detached { [weak self] in
            do {
                try ServiceControl.startIfNeeded()
                let configuration = try ConfigurationStore.loadSnapshot()
                let running = ServiceControl.isRunning
                await self?.load(configuration, running: running)
            } catch {
                await self?.report(error)
            }
        }
    }

    func toggleService() {
        guard !isBusy else { return }
        isBusy = true
        Task.detached { [weak self] in
            do {
                if ServiceControl.isRunning {
                    try ServiceControl.stopIfNeeded()
                } else {
                    try ServiceControl.startIfNeeded()
                }
                let running = ServiceControl.isRunning
                let configuration = try ConfigurationStore.loadSnapshot()
                await self?.load(configuration, running: running)
            } catch {
                await self?.report(error)
            }
        }
    }

    func reloadConfiguration() {
        guard !isBusy else { return }
        guard !hasUnsavedMenu, !hasUnsavedAction else {
            message = L10n.text("请先保存脚本，再重新加载配置")
            return
        }
        isBusy = true
        Task.detached { [weak self] in
            do {
                let configuration = try ConfigurationLoader.load()
                try MenuScripts.check(
                    configuration: configuration,
                    sampleFile: ConfigurationStore.scriptURL.path
                )
                try ServiceControl.run(["restart"])
                let running = ServiceControl.isRunning
                await self?.load(configuration, running: running)
            } catch {
                await self?.report(error)
            }
        }
    }
}
