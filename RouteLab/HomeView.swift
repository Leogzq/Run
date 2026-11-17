import SwiftUI
import UniformTypeIdentifiers

enum OriginalStyle {
    static let green = Color(red: 18/255, green: 107/255, blue: 94/255)
    static let background = Color(red: 244/255, green: 240/255, blue: 232/255)
    static let card = Color(red: 1, green: 253/255, blue: 249/255)
    static let stroke = Color(red: 216/255, green: 210/255, blue: 196/255)
}

struct HomeView: View {
    @StateObject private var device = DeviceSession()
    @State private var selected = 0

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        NavigationLink { tips } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("操作提示").font(.headline)
                                Text("1. 点击“绘制路线”先搜索地点或直接点地图。\n2. 完成后可保存路线或分享路线。\n3. 进入“路线模拟”选择路线并设置参数。\n4. 首次模拟前，请完成设备配对配置。")
                                    .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                                Text("点击卡片查看完整操作说明")
                                    .font(.caption.bold()).foregroundStyle(OriginalStyle.green)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(18).originalCard()
                        }.buttonStyle(.plain)
                        NavigationLink { NFCPage() } label: {
                            HomeCard(icon: "wave.3.right", title: "NFC 工具", subtitle: "读取公开 NDEF 标签与查看链接")
                        }
                        NavigationLink { Editor(mode: .run) } label: {
                            HomeCard(icon: "figure.run", title: "路线模拟", subtitle: "选择路线文件后按所选速度模拟移动。")
                        }
                        NavigationLink { Editor(mode: .draw) } label: {
                            HomeCard(icon: "pencil.and.outline", title: "绘制路线", subtitle: "打开地图点选路径，并保存为可复用路线。")
                        }
                        NavigationLink { Editor(mode: .library) } label: {
                            HomeCard(icon: "map", title: "查看已有路线", subtitle: "集中查看本地路线，并管理本地路线编辑。")
                        }
                    }.padding(16)
                }.background(OriginalStyle.background)
                    .navigationTitle("开始").navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(OriginalStyle.green, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }.tabItem { Label("开始", systemImage: "map") }.tag(0)
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        NavigationLink { DeviceSetupView() } label: {
                            HomeCard(icon: "iphone", title: "设备配置", subtitle: "iOS 26.1 · 配对文件与开发定位服务")
                        }
                        NavigationLink { SettingsPage() } label: {
                            HomeCard(icon: "gearshape", title: "设置", subtitle: "模拟参数、版本与项目源码")
                        }
                        NavigationLink { tips } label: {
                            HomeCard(icon: "questionmark.circle", title: "操作说明", subtitle: "首次安装、设备连接与功能说明")
                        }
                        if device.running || device.busy {
                            Text(device.status).padding()
                            Button("停止模拟") { device.stop() }.buttonStyle(.borderedProminent)
                        }
                    }.padding(16)
                }.background(OriginalStyle.background)
                    .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(OriginalStyle.green, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            }.tabItem { Label("我的", systemImage: "person") }.tag(1)
        }.tint(OriginalStyle.green).environmentObject(device)
            .alert("设备提示", isPresented: Binding(get: { device.error != nil }, set: { if !$0 { device.error = nil } })) {
                Button("好") { device.error = nil }
            } message: { Text(device.error ?? "") }
    }

    private var tips: some View {
        ScrollView {
            Text("先在绘制路线中搜索地点，开启绘制后点击地图添加点，保存后可在本地路线中重新编辑或导出。\n\n路线模拟需要本机配对文件、开发者模式和 LocalDevVPN。首次在电脑上生成 RPPairing 文件，传到手机后在设备配置中导入。连接 Wi-Fi 并开启 LocalDevVPN 后，再开始模拟。\n\n模拟运行时保持本应用在前台。停止后会向设备发送清除定位请求，确认失败时请检查手机定位，必要时重启。\n\n当前 iOS 重建版使用 Apple 地图，尚未接入原应用共享服务器。Android NDEF 跳转与 iOS NFC 接口不同，目前支持读取公开标签。后台持续模拟仍待实现。")
                .padding().frame(maxWidth: .infinity, alignment: .leading)
        }.navigationTitle("操作提示")
    }
}

struct HomeCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 29)).frame(width: 40).foregroundStyle(OriginalStyle.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).originalCard()
    }
}

extension View {
    func originalCard() -> some View {
        background(OriginalStyle.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(OriginalStyle.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 2, y: 2)
    }
}

struct DeviceSetupView: View {
    @EnvironmentObject private var device: DeviceSession
    @State private var importing = false
    var body: some View {
        Form {
            Section("iPhone 15 Pro Max · iOS 26.1") {
                Text("1. 在设置 → 隐私与安全性中打开开发者模式，按提示重启。")
                Text("2. 首次用数据线连接电脑，解锁并信任电脑，通过 idevice_pair 生成本机的 RPPairing 配对文件。")
                Link("打开配对工具与说明", destination: URL(string: "https://github.com/jkcoxson/idevice_pair")!)
                Text("3. 安装并开启 LocalDevVPN，然后返回本应用。")
                Link("下载 LocalDevVPN", destination: URL(string: "https://apps.apple.com/app/id6755608044")!)
                Text("4. 保持 Wi-Fi 连接，将配对文件导入本应用。")
                Button(device.hasPairing ? "替换配对文件" : "导入配对文件") { importing = true }
                    .disabled(device.running || device.busy)
                Text(device.status).font(.footnote)
            }
            Section {
                Text("配对文件含本机连接凭据，仅保存在本机且不参与备份。")
            }
        }.navigationTitle("设备配置")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
                do { try device.importPairing(result.get()) }
                catch { device.error = error.localizedDescription }
            }
    }
}

struct SettingsPage: View {
    @AppStorage("runSpeed") private var speed = 15.0
    @AppStorage("runLoops") private var loops = 100
    @AppStorage("runFluctuate") private var fluctuate = true
    var body: some View {
        Form {
            Section("路线模拟") {
                HStack { Text("速度（m/s）"); TextField("15", value: $speed, format: .number).keyboardType(.decimalPad) }
                Stepper("循环次数 \(loops)", value: $loops, in: 1...10000)
                Toggle("速度浮动", isOn: $fluctuate)
            }
            Section("版本与开源许可") {
                Text("iOS 重建测试版 0.2")
                Text("开发定位连接代码采用 Waypoint 的 AGPL-3.0 实现，包含 idevice 依赖。本软件按 AGPL-3.0 提供，不提供担保。")
                Link("源码与许可证", destination: URL(string: "https://github.com/Leogzq/Run")!)
                Link("Waypoint 原项目", destination: URL(string: "https://github.com/raph559/WaypointApp")!)
            }
        }.navigationTitle("设置")
    }
}
