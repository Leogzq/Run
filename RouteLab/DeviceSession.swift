import Foundation
import SwiftUI
import UIKit

@MainActor
final class DeviceSession: ObservableObject {
    @Published var status = "尚未连接设备"
    @Published var busy = false
    @Published var running = false
    @Published var confirmedPoint: Point?
    @Published var error: String?
    private let bridge = DeviceBridge()
    private var routeTask: Task<Void, Never>?

    private var pairingURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DevicePairing/pairing.plist")
    }

    var hasPairing: Bool { FileManager.default.fileExists(atPath: pairingURL.path) }

    func importPairing(_ url: URL) throws {
        guard !busy && !running else { throw SessionError.message("请先停止模拟。") }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard data.count < 5_000_000,
              let object = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              !object.isEmpty else {
            throw SessionError.message("文件不是有效的配对记录。")
        }
        var folder = pairingURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        try data.write(to: pairingURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        status = "配对文件已导入，等待连接验证"
    }

    func play(_ route: Route, speed: Double, loops: Int, fluctuate: Bool) {
        guard !busy, !running else { return }
        let track = Track(route.points)
        guard hasPairing else { error = "请先在“我的 → 设备配置”导入本机配对文件。"; return }
        guard track.length > 0, speed.isFinite, speed > 0, speed <= 1000, loops > 0, loops <= 10000 else {
            error = "请检查路线、速度和循环次数。"
            return
        }
        busy = true
        routeTask = Task {
            do {
                status = "正在连接 LocalDevVPN…"
                try await bridge.connect(pairingFile: pairingURL)
                if !(try await bridge.isDeveloperImageMounted()) {
                    for artifact in DeveloperImageStore.artifacts where !DeveloperImageStore.isPresent(artifact) {
                        status = "正在下载开发支持文件…"
                        try await DeveloperImageStore.download(artifact)
                    }
                    status = "正在挂载开发支持文件…"
                    try await bridge.mountDeveloperImage(DeveloperImageStore.paths)
                }
                try Task.checkCancellation()
                running = true
                busy = false
                UIApplication.shared.isIdleTimerDisabled = true
                var traveled = 0.0
                var previous = ProcessInfo.processInfo.systemUptime
                let total = track.length * Double(loops)
                while !Task.isCancelled, traveled < total {
                    let now = ProcessInfo.processInfo.systemUptime
                    traveled += max(0, now - previous) * speed * (fluctuate ? Double.random(in: 0.85...1.15) : 1)
                    previous = now
                    let offset = traveled >= total ? track.length : traveled.truncatingRemainder(dividingBy: track.length)
                    guard let point = track.point(at: offset) else { break }
                    try await bridge.setLocation(SelectedCoordinate(latitude: point.latitude, longitude: point.longitude))
                    confirmedPoint = point
                    status = "模拟中 · 第 \(min(loops, Int(traveled / track.length) + 1))/\(loops) 圈"
                    try await Task.sleep(for: .seconds(1))
                }
            } catch is CancellationError {
                // Stop restores location below, after pending writes finish.
            } catch {
                self.error = error.localizedDescription
                status = "连接或模拟失败"
            }
            busy = true
            do {
                try await bridge.clearLocation()
                status = "已停止，设备已确认清除模拟定位"
            } catch {
                status = "未能确认清除定位，请断开 LocalDevVPN 并检查定位，必要时重启手机"
            }
            await bridge.disconnect()
            running = false
            busy = false
            confirmedPoint = nil
            UIApplication.shared.isIdleTimerDisabled = false
            routeTask = nil
        }
    }

    func stop() {
        guard routeTask != nil else { return }
        routeTask?.cancel()
        status = "正在停止并恢复定位…"
    }
}

enum SessionError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}
