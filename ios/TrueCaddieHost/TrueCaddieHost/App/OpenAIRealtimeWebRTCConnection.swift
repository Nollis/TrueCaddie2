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

    init(
        configuration: OpenAIRealtimeSessionConfiguration = .default,
        credential: RealtimeVoiceCredential
    ) {
        self.configuration = configuration
        self.credential = credential
    }

    func connect() {
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

    // MARK: - Private

    private func dispatch(_ json: String) {
        let safe = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        webView?.evaluateJavaScript("window.__rtcSend?.(`\(safe)`)", completionHandler: nil)
    }

    private func buildHTML() -> String {
        let model = configuration.model
        let voice = configuration.voice
        let apiKey = credential.apiKey
        let sessionJSON = #"{"type":"realtime","model":"\#(model)","audio":{"output":{"voice":"\#(voice)"}}}"#

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
                queued.forEach { dispatch($0) }
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
