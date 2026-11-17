import Foundation
import MapKit
import SwiftUI

@main
struct RouteLabApp: App {
    var body: some Scene {
        WindowGroup { Editor() }
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

struct Editor: View {
    @AppStorage("savedRoutes") private var saved: Data = Data()
    @Environment(\.scenePhase) private var phase
    @State private var routes: [Route] = []
    @State private var current = Route(name: "", points: [])
    @State private var position: MapCameraPosition = .automatic
    @State private var cursor: Point?
    @State private var run: Task<Void, Never>?
    @State private var speed = 6.0
    @State private var distance = 0.0
    @State private var query = ""
    @State private var searching = false
    @State private var message: String?
    @State private var showRoutes = false
    @State private var addPoints = true

    private var track: Track { Track(current.points) }

    var body: some View {
        NavigationStack {
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
            .navigationTitle("路线工具")
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
            }
            .onChange(of: phase) { _, value in if value != .active { stop() } }
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
                if let cursor {
                    Annotation("回放位置", coordinate: cursor.coordinate) {
                        Image(systemName: "location.circle.fill")
                            .font(.title).foregroundStyle(.white, .blue)
                            .background(.white, in: Circle())
                    }
                }
            }
            .onTapGesture { screen in
                guard addPoints, run == nil, let c = proxy.convert(screen, from: .local) else { return }
                resetPlayback()
                current.points.append(Point(c))
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("点击地图添加路线点", isOn: $addPoints)
                .disabled(run != nil)
            TextField("路线名称", text: $current.name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("\(current.points.count) 点 · \(track.length / 1000, specifier: "%.2f") 公里")
                Spacer()
                Button("撤销点") {
                    resetPlayback()
                    _ = current.points.popLast()
                }.disabled(current.points.isEmpty || run != nil)
                Button("新建") {
                    resetPlayback()
                    current = Route(name: "", points: [])
                }
                Button("保存", action: save).disabled(track.length <= 0)
            }.font(.subheadline)
            HStack {
                Text("速度 \(speed, specifier: "%.0f") 公里/小时").font(.subheadline)
                Slider(value: $speed, in: 1...40, step: 1).disabled(run != nil)
            }
            if track.length > 0 {
                ProgressView(value: min(distance, track.length), total: track.length)
            }
            Button(run == nil ? "开始应用内回放" : "停止回放") {
                if run == nil { play() } else { stop() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(track.length <= 0)
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

    private func play() {
        let route = track
        guard route.length > 0 else { return }
        let rate = speed / 3.6
        let start = ProcessInfo.processInfo.systemUptime
        distance = 0
        cursor = route.point(at: 0)
        run = Task { @MainActor in
            while !Task.isCancelled {
                distance = min(route.length, (ProcessInfo.processInfo.systemUptime - start) * rate)
                cursor = route.point(at: distance)
                if distance >= route.length { run = nil; return }
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
            }
        }
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
