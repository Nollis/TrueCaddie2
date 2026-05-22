import Foundation

/// Transport seam between the host and OpenAI's Realtime API.
///
/// Two production implementations live alongside this protocol —
/// `OpenAIRealtimeWebSocketConnection` (legacy v1, kept for parity tests) and
/// `OpenAIRealtimeWebRTCConnection` (the live path required by
/// `gpt-realtime-2`). `StubOpenAIRealtimeConnection` is the in-memory test
/// double.
protocol OpenAIRealtimeConnectioning: AnyObject {
    var onJSONMessage: ((String) -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onFailure: ((String) -> Void)? { get set }

    func connect()
    func disconnect()
    func sendJSON(_ json: String)
}

final class OpenAIRealtimeWebSocketConnection: NSObject, OpenAIRealtimeConnectioning, URLSessionWebSocketDelegate {
    let configuration: OpenAIRealtimeSessionConfiguration
    var onJSONMessage: ((String) -> Void)?
    var onDisconnected: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private let credentialProvider: (any RealtimeVoiceCredentialProviding)?
    private let sessionConfiguration: URLSessionConfiguration
    private var urlSession: URLSession?
    private var task: URLSessionWebSocketTask?
    private var pendingOutbound: [String] = []
    private var isOpen = false
    private var hasFinished = false

    init(
        configuration: OpenAIRealtimeSessionConfiguration = .default,
        credentialProvider: (any RealtimeVoiceCredentialProviding)? = nil,
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.configuration = configuration
        self.credentialProvider = credentialProvider
        self.sessionConfiguration = sessionConfiguration
        super.init()
    }

    func connect() {
        guard task == nil else { return }
        hasFinished = false
        isOpen = false
        pendingOutbound.removeAll()

        guard let credentialProvider else {
            emitFailure("Realtime credential provider not configured")
            return
        }

        let credential: RealtimeVoiceCredential
        do {
            credential = try credentialProvider.currentCredential()
        } catch {
            emitFailure("Missing realtime credential: \(error.localizedDescription)")
            return
        }

        guard let request = Self.makeRequest(
            configuration: configuration,
            credential: credential
        ) else {
            emitFailure("Invalid realtime websocket URL: \(configuration.webSocketURL)")
            return
        }

        // Authorization sits on Apple's reserved-header list, so URLRequest
        // headers can be dropped silently. Put them on the session config too,
        // which is not filtered.
        let config = (sessionConfiguration.copy() as? URLSessionConfiguration) ?? .default
        var extraHeaders = config.httpAdditionalHeaders ?? [:]
        extraHeaders["Authorization"] = "Bearer \(credential.apiKey)"
        extraHeaders["OpenAI-Beta"] = "realtime=v2"
        config.httpAdditionalHeaders = extraHeaders

        let session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
        urlSession = session

        print("[OpenAIRealtimeWebSocket] Opening \(request.url?.absoluteString ?? "?")")

        let newTask = session.webSocketTask(with: request)
        task = newTask
        newTask.resume()
        receiveNext()
    }

    func disconnect() {
        guard let activeTask = task else { return }
        task = nil
        isOpen = false
        if !hasFinished {
            hasFinished = true
            activeTask.cancel(with: .normalClosure, reason: nil)
            emitDisconnected()
        }
        urlSession?.finishTasksAndInvalidate()
        urlSession = nil
    }

    func sendJSON(_ json: String) {
        guard let task else {
            emitFailure("Cannot send realtime message before connect")
            return
        }
        if !isOpen {
            pendingOutbound.append(json)
            return
        }
        deliver(json, on: task)
    }

    static func makeRequest(
        configuration: OpenAIRealtimeSessionConfiguration,
        credential: RealtimeVoiceCredential?
    ) -> URLRequest? {
        guard var components = URLComponents(string: configuration.webSocketURL) else {
            return nil
        }
        guard
            let scheme = components.scheme,
            ["ws", "wss"].contains(scheme),
            components.host != nil
        else {
            return nil
        }
        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "model" }) {
            queryItems.append(URLQueryItem(name: "model", value: configuration.model))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("realtime=v2", forHTTPHeaderField: "OpenAI-Beta")
        if let credential {
            request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocolName: String?
    ) {
        print("[OpenAIRealtimeWebSocket] Connected (subprotocol: \(protocolName ?? "<none>"))")
        DispatchQueue.main.async { [weak self] in
            self?.handleSocketOpened()
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonText = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let suffix = reasonText.isEmpty ? "" : ": \(reasonText)"
        print("[OpenAIRealtimeWebSocket] Closed (code \(closeCode.rawValue))\(suffix)")
        DispatchQueue.main.async { [weak self] in
            self?.handleSocketClosed(code: closeCode, reason: reasonText)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let statusCode = (task.response as? HTTPURLResponse)?.statusCode
        let statusPrefix = statusCode.map { "HTTP \($0)" }
        if let error {
            let detail = statusPrefix.map { "\($0): \(error.localizedDescription)" } ?? error.localizedDescription
            print("[OpenAIRealtimeWebSocket] Task ended with error: \(detail)")
        } else if let statusCode, statusCode >= 400 {
            print("[OpenAIRealtimeWebSocket] Task ended with HTTP \(statusCode)")
        } else if let statusCode {
            print("[OpenAIRealtimeWebSocket] Task ended (HTTP \(statusCode))")
        }
        guard let error else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handleTaskFailed(error: error, statusCode: statusCode)
        }
    }

    // MARK: Internal

    private func receiveNext() {
        guard let task else { return }
        task.receive { [weak self] result in
            DispatchQueue.main.async {
                self?.handleReceive(result)
            }
        }
    }

    private func handleReceive(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case let .success(message):
            switch message {
            case let .string(json):
                onJSONMessage?(json)
            case let .data(data):
                if let json = String(data: data, encoding: .utf8) {
                    onJSONMessage?(json)
                }
            @unknown default:
                break
            }
            receiveNext()

        case let .failure(error):
            task = nil
            isOpen = false
            if !hasFinished {
                hasFinished = true
                emitFailure("Realtime receive failed: \(error.localizedDescription)")
                onDisconnected?()
            }
        }
    }

    private func handleSocketOpened() {
        isOpen = true
        let flushable = pendingOutbound
        pendingOutbound.removeAll()
        guard let task else { return }
        for json in flushable {
            deliver(json, on: task)
        }
    }

    private func handleSocketClosed(code: URLSessionWebSocketTask.CloseCode, reason: String) {
        isOpen = false
        task = nil
        if !hasFinished {
            hasFinished = true
            if code != .normalClosure || !reason.isEmpty {
                let suffix = reason.isEmpty ? "" : ": \(reason)"
                emitFailure("Realtime closed (code \(code.rawValue))\(suffix)")
            }
            onDisconnected?()
        }
    }

    private func handleTaskFailed(error: Error, statusCode: Int?) {
        isOpen = false
        task = nil
        if hasFinished { return }
        hasFinished = true
        var detail = error.localizedDescription
        if let statusCode {
            detail = "HTTP \(statusCode): \(detail)"
        }
        emitFailure("Realtime task failed: \(detail)")
        onDisconnected?()
    }

    private func deliver(_ json: String, on task: URLSessionWebSocketTask) {
        task.send(.string(json)) { [weak self] error in
            guard let self, let error else { return }
            DispatchQueue.main.async {
                guard !self.hasFinished else { return }
                self.emitFailure("Realtime send failed: \(error.localizedDescription)")
            }
        }
    }

    private func emitFailure(_ message: String) {
        print("[OpenAIRealtimeWebSocket] \(message)")
        onFailure?(message)
    }

    private func emitDisconnected() {
        onDisconnected?()
    }
}

final class StubOpenAIRealtimeConnection: OpenAIRealtimeConnectioning {
    var onJSONMessage: ((String) -> Void)?
    var onDisconnected: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private(set) var sentJSONMessages: [String] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    func connect() {
        connectCount += 1
    }

    func disconnect() {
        disconnectCount += 1
        onDisconnected?()
    }

    func sendJSON(_ json: String) {
        sentJSONMessages.append(json)
    }

    func receiveJSON(_ json: String) {
        onJSONMessage?(json)
    }

    func fail(_ message: String) {
        onFailure?(message)
    }
}
