import Foundation
import WebKit

/// Connects to the OpenAI Realtime API v2 via WebRTC using a hidden WKWebView.
///
/// The WKWebView handles SDP negotiation, ICE, and audio tracks natively.
/// JSON events flow through the `oai-events` data channel. Audio buffer append
/// messages are silently dropped — audio reaches OpenAI through the WebRTC
/// audio track, not the data channel.
@MainActor
final class OpenAIRealtimeWebRTCConnection: NSObject, OpenAIRealtimeConnectioning {

    var onJSONMessage: ((String) -> Void)?
    var onDisconnected: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private let configuration: OpenAIRealtimeSessionConfiguration
    private let credential: RealtimeVoiceCredential
    private var webView: WKWebView?
    private var pendingMessages: [String] = []
    private var isDataChannelOpen = false
    private var isInputAudioEnabled = false

    init(
        configuration: OpenAIRealtimeSessionConfiguration,
        credential: RealtimeVoiceCredential
    ) {
        self.configuration = configuration
        self.credential = credential
    }

    func connect() {
        isInputAudioEnabled = false
        let webConfig = WKWebViewConfiguration()
        webConfig.allowsInlineMediaPlayback = true
        webConfig.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.add(self, name: "rtcOpen")
        controller.add(self, name: "rtcClose")
        controller.add(self, name: "rtcEvent")
        controller.add(self, name: "rtcError")
        webConfig.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: webConfig)
        webView = wv

        // Must be in the view hierarchy for WebRTC audio capture/playback to work.
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first {
            window.addSubview(wv)
        }

        wv.loadHTMLString(buildHTML(), baseURL: URL(string: "https://localhost"))
    }

    func disconnect() {
        webView?.evaluateJavaScript("window.__rtcPc?.close()")
        webView?.removeFromSuperview()
        webView = nil
        isDataChannelOpen = false
        pendingMessages.removeAll()
    }

    func sendJSON(_ json: String) {
        // Audio travels through the WebRTC track — drop data-channel audio appends.
        if json.contains("\"input_audio_buffer.append\"") { return }

        if isDataChannelOpen {
            dispatch(json)
        } else {
            pendingMessages.append(json)
        }
    }

    func setInputAudioEnabled(_ enabled: Bool) {
        isInputAudioEnabled = enabled
        applyInputAudioEnabled()
    }

    // MARK: - Private

    private func applyInputAudioEnabled() {
        let enabled = isInputAudioEnabled ? "true" : "false"
        webView?.evaluateJavaScript("window.__setInputAudioEnabled?.(\(enabled))", completionHandler: nil)
    }

    private func dispatch(_ json: String) {
        let safe = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        webView?.evaluateJavaScript("window.__rtcSend?.(`\(safe)`)", completionHandler: nil)
    }

    private func initialSessionJSON() -> String {
        let sessionObject: [String: Any] = [
            "type": "realtime",
            "model": configuration.model,
            "instructions": configuration.instructions,
            "tool_choice": "auto",
            "tools": HostCaddieSession.VoiceSessionBridge.openAIFunctionTools().map { tool in
                [
                    "type": tool.type,
                    "name": tool.name,
                    "description": tool.description,
                    "parameters": [
                        "type": tool.parameters.type,
                        "properties": tool.parameters.properties.mapValues { property in
                            var propertyObject: [String: Any] = [
                                "type": property.type,
                                "description": property.description
                            ]
                            if let enumValues = property.enumValues {
                                propertyObject["enum"] = enumValues
                            }
                            return propertyObject
                        },
                        "required": tool.parameters.required,
                        "additionalProperties": tool.parameters.additionalProperties
                    ],
                    "strict": tool.strict
                ]
            },
            "audio": [
                "input": [
                    "turn_detection": [
                        "type": OpenAIRealtimeSessionUpdateTurnDetection.defaultServerVAD.type,
                        "create_response": OpenAIRealtimeSessionUpdateTurnDetection.defaultServerVAD.createResponse,
                        "interrupt_response": OpenAIRealtimeSessionUpdateTurnDetection.defaultServerVAD.interruptResponse
                    ]
                ],
                "output": [
                    "voice": configuration.voice
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: sessionObject),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"type":"realtime","model":"gpt-realtime-2"}"#
        }

        return json
    }

    private func buildHTML() -> String {
        let apiKey = credential.apiKey
        let sessionJSON = initialSessionJSON()

        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"></head>
        <body>
        <audio id="a" autoplay playsinline></audio>
        <script>
        (async () => {
          try {
            const pc = new RTCPeerConnection();
            window.__rtcPc = pc;

            pc.ontrack = e => { document.getElementById('a').srcObject = e.streams[0]; };

            const dc = pc.createDataChannel('oai-events');
            dc.onmessage = e => webkit.messageHandlers.rtcEvent.postMessage(e.data);
            dc.onopen  = () => webkit.messageHandlers.rtcOpen.postMessage('');
            dc.onclose = () => webkit.messageHandlers.rtcClose.postMessage('');
            window.__rtcSend = j => { if (dc.readyState === 'open') dc.send(j); };

            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            stream.getAudioTracks().forEach(t => { t.enabled = false; });
            window.__setInputAudioEnabled = enabled => {
              stream.getAudioTracks().forEach(t => { t.enabled = !!enabled; });
            };
            stream.getTracks().forEach(t => pc.addTrack(t, stream));

            const offer = await pc.createOffer();
            await pc.setLocalDescription(offer);

            const fd = new FormData();
            fd.set('session', JSON.stringify(\(sessionJSON)));
            fd.set('sdp', offer.sdp);

            const r = await fetch('https://api.openai.com/v1/realtime/calls', {
              method: 'POST',
              headers: { Authorization: 'Bearer \(apiKey)' },
              body: fd
            });

            if (!r.ok) {
              webkit.messageHandlers.rtcError.postMessage(await r.text());
              return;
            }

            await pc.setRemoteDescription({ type: 'answer', sdp: await r.text() });
          } catch (e) {
            webkit.messageHandlers.rtcError.postMessage(String(e));
          }
        })();
        </script>
        </body></html>
        """
    }
}

extension OpenAIRealtimeWebRTCConnection: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch message.name {
            case "rtcOpen":
                isDataChannelOpen = true
                let queued = pendingMessages
                pendingMessages.removeAll()
                queued.forEach { self.dispatch($0) }
                applyInputAudioEnabled()
            case "rtcClose":
                isDataChannelOpen = false
                onDisconnected?()
            case "rtcEvent":
                if let json = message.body as? String {
                    onJSONMessage?(json)
                }
            case "rtcError":
                let msg = (message.body as? String) ?? "WebRTC error"
                onFailure?(msg)
            default:
                break
            }
        }
    }
}
