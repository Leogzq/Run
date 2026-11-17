import SwiftUI
import CoreNFC

final class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var content = ""
    @Published var status = "将手机顶部靠近公开 NDEF 标签"
    private var session: NFCNDEFReaderSession?
    func read() {
        guard NFCNDEFReaderSession.readingAvailable else { status = "此设备无法读取 NFC 标签"; return }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "将手机顶部靠近 NDEF 标签"
        session?.begin()
    }
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { self.status = error.localizedDescription; self.session = nil }
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let strings = messages.flatMap(\.records).map { record -> String in
            if let url = record.wellKnownTypeURIPayload() { return url.absoluteString }
            let (text, _) = record.wellKnownTypeTextPayload()
            return text ?? record.payload.base64EncodedString()
        }
        DispatchQueue.main.async { self.content = strings.joined(separator: "\n"); self.status = "读取完成" }
    }
}

struct NFCPage: View {
    @StateObject private var reader = NFCReader()
    var body: some View {
        Form {
            Section("读取公开 NDEF 标签") {
                Text(reader.status)
                Button("开始读取") { reader.read() }
                if !reader.content.isEmpty {
                    Text(reader.content).textSelection(.enabled)
                    ShareLink("导出读取内容", item: reader.content)
                }
            }
            Section {
                Text("原版通过 Android Intent 向目标应用发送 NFC 数据。当前 iOS 版本仅实现读取与导出，尚未实现该跳转功能。")
            }
        }.navigationTitle("NFC 工具")
    }
}
