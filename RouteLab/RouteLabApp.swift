import Foundation
import MapKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct RouteLabApp: App {
    var body: some Scene {
        WindowGroup { HomeView() }
    }
}

private extension Point {
    init(_ c: CLLocationCoordinate2D) {
        self.init(latitude: c.latitude, longitude: c.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum EditorMode { case draw, run, library }

struct Editor: View {
    let mode: EditorMode
    @EnvironmentObject private var device: DeviceSession
    @AppStorage("runSpeed") private var runSpeed = 15.0
    @AppStorage("runLoops") private var runLoops = 100
    @AppStorage("runFluctuate") private var runFluctuate = true
    @AppStorage("runMode") private var runMode = "speed"
    @AppStorage("runCadence") private var runCadence = 180.0
    @State private var importingRoute = false
    @State private var exportURL: URL?
    @AppStorage("savedRoutes") private var saved: Data = Data()
    @Environment(\.scenePhase) private var phase
    @State private var routes: [Route] = []
    @State private var current = Route(name: "", points: [])
    @State private var position: MapCameraPosition = .automatic
    @State private var cursor: Point?
    @State private var run: Task<Void, Never>?
    @State private var distance = 0.0
    @State private var query = ""
    @State private var searching = false
    @State private var message: String?
    @State private var showRoutes = false
    @State private var addPoints = true

    private var track: Track { Track(current.points) }

    var body: some View {
        Group {
            VStack(spacing: 0) {
                HStack {
                    TextField("搜索地点", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit(findPlace)
                    Button("搜索", action: findPlace).disabled(searching)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                map
                controls
            }
            .navigationTitle(mode == .run ? "路线模拟" : mode == .library ? "本地路线" : "绘制路线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("本地路线") { showRoutes = true }
                }
            }
            .sheet(isPresented: $showRoutes) { library }
            .alert("提示", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) { Button("好", role: .cancel) { message = nil } }
              message: { Text(message ?? "") }
            .onAppear {
                routes = (try? JSONDecoder().decode([Route].self, from: saved)) ?? []
                if mode == .library { showRoutes = true }
                if mode == .run { addPoints = false }
            }
            .onChange(of: phase) { _, value in if value != .active { stop(); device.stop() } }
            .fileImporter(isPresented: $importingRoute, allowedContentTypes: [.json, .data]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    current = try RouteFiles.read(url)
                    save()
                } catch { message = error.localizedDescription }
            }
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $position) {
                if current.points.count >= 2 {
                    MapPolyline(coordinates: current.points.map(\.coordinate))
                        .stroke(.blue, lineWidth: 4)
                }
                if let first = current.points.first {
                    Marker("起点", coordinate: first.coordinate).tint(.green)
                }
                if let last = current.points.last, current.points.count >= 2 {
                    Marker("终点", coordinate: last.coordinate).tint(.red)
                }
                if let cursor = device.confirmedPoint ?? cursor {
                    Annotation("设备已确认位置", coordinate: cursor.coordinate) {
                        Image(systemName: "location.circle.fill")
                            .font(.title).foregroundStyle(.white, .blue)
                            .background(.white, in: Circle())
                    }
                }
            }
            .onTapGesture { screen in
                guard addPoints, !device.running, !device.busy, let c = proxy.convert(screen, from: .local) else { return }
                resetPlayback()
                current.points.append(Point(c))
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("点击地图添加路线点", isOn: $addPoints)
                .disabled(device.running || device.busy)
            TextField("路线名称", text: $current.name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("\(current.points.count) 点 · \(track.length / 1000, specifier: "%.2f") 公里")
                Spacer()
                Button("撤销点") {
                    resetPlayback()
                    _ = current.points.popLast()
                }.disabled(current.points.isEmpty || device.running || device.busy)
                Button("新建") {
                    resetPlayback()
                    current = Route(name: "", points: [])
                }
                Button("保存", action: save).disabled(track.length <= 0)
            }.font(.subheadline)
            if mode == .run {
                Picker("模拟方式", selection: $runMode) {
                    Text("按速度").tag("speed")
                    Text("按步频").tag("cadence")
                }.pickerStyle(.segmented)
                if runMode == "cadence" {
                    HStack {
                        Text("步频（步/分钟）")
                        TextField("180", value: $runCadence, format: .number).keyboardType(.decimalPad)
                    }
                }
                HStack {
                    Text("速度")
                    TextField("15", value: $runSpeed, format: .number)
                        .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    Text("m/s")
                    Text("循环")
                    TextField("100", value: $runLoops, format: .number)
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                }
                Toggle("速度浮动", isOn: $runFluctuate)
                Text(device.status).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("选路线") { showRoutes = true }
                    Button(device.running || device.busy ? "停止模拟" : "开始模拟") {
                        if device.running || device.busy { device.stop() }
                        else { device.play(current, speed: runMode == "cadence" ? runCadence * 0.8 / 60 : runSpeed, loops: runLoops, fluctuate: runFluctuate) }
                    }.buttonStyle(.borderedProminent).disabled(current.points.count < 2)
                }
            } else {
                HStack {
                    Button("闭合路线") {
                        if let first = current.points.first, current.points.last != first {
                            current.points.append(first)
                        }
                    }.disabled(current.points.count < 3)
                    Button("导入路线") { importingRoute = true }
                    Button("导出路线") {
                        do { exportURL = try RouteFiles.write(current) }
                        catch { message = error.localizedDescription }
                    }.disabled(current.points.count < 2)
                    if let exportURL { ShareLink("分享", item: exportURL) }
                }.font(.subheadline)
            }
        }
        .padding()
    }

    private var library: some View {
        NavigationStack {
            List {
                if routes.isEmpty { Text("暂无本地路线").foregroundStyle(.secondary) }
                ForEach(routes) { route in
                    Button {
                        resetPlayback()
                        current = route
                        if route.points.count > 1 {
                            let line = MKPolyline(coordinates: route.points.map(\.coordinate), count: route.points.count)
                            position = .rect(line.boundingMapRect.insetBy(dx: -2500, dy: -2500))
                        }
                        showRoutes = false
                    } label: {
                        VStack(alignment: .leading) {
                            Text(route.name)
                            Text("\(route.points.count) 个路线点").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.onDelete { offsets in
                    var updated = routes
                    updated.remove(atOffsets: offsets)
                    persist(updated)
                }
            }
            .navigationTitle("本地路线")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { showRoutes = false } }
            }
        }
    }

    private func findPlace() {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !searching else { return }
        searching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        if let region = position.region { request.region = region }
        Task { @MainActor in
            defer { searching = false }
            do {
                let response = try await MKLocalSearch(request: request).start()
                guard let item = response.mapItems.first else { message = "未找到地点。"; return }
                position = .region(MKCoordinateRegion(center: item.placemark.coordinate,
                    latitudinalMeters: 1800, longitudinalMeters: 1800))
            } catch {
                message = "搜索失败，请检查网络或试试其他关键词。"
            }
        }
    }

    private func save() {
        let name = current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { message = "请输入路线名称。"; return }
        var updated = routes
        current.name = name
        if let idx = updated.firstIndex(where: { $0.id == current.id }) { updated[idx] = current }
        else { updated.insert(current, at: 0) }
        persist(updated)
    }

    private func persist(_ updated: [Route]) {
        do {
            saved = try JSONEncoder().encode(updated)
            routes = updated
        } catch { message = "路线保存失败。" }
    }

    private func stop() {
        run?.cancel()
        run = nil
    }

    private func resetPlayback() {
        stop()
        cursor = nil
        distance = 0
    }
}
