import FlutterMacOS
import AVFoundation
import Speech

public class MicPermissionHandler: NSObject, FlutterPlugin, SFSpeechRecognizerDelegate {
    private var channel: FlutterMethodChannel?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.nextron.ai/mic_permission", binaryMessenger: registrar.messenger)
        let instance = MicPermissionHandler()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission": requestPermission(result: result)
        case "checkPermission": checkPermission(result: result)
        case "startListening": startListening(result: result)
        case "stopListening": stopListening(result: result)
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async { result(status == .authorized ? "authorized" : "denied") }
                }
            } else {
                DispatchQueue.main.async { result("denied") }
            }
        }
    }

    private func checkPermission(result: @escaping FlutterResult) {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        let speech = SFSpeechRecognizer.authorizationStatus()
        if mic == .authorized && speech == .authorized { result("authorized") }
        else if mic == .denied || speech == .denied { result("denied") }
        else { result("not_determined") }
    }

    private func cleanupSession() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func startListening(result: @escaping FlutterResult) {
        // Fully stop old session
        cleanupSession()

        // Delay to let old session fully teardown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Create FRESH recognizer every time
            let locale = Locale(identifier: "en-US")
            let recognizer = SFSpeechRecognizer(locale: locale)
            guard let recognizer = recognizer, recognizer.isAvailable else {
                result("error: speech recognizer not available")
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.recognitionRequest = request

            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (res, error) in
                guard let self = self else { return }
                if let res = res {
                    let text = res.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("onSpeechResult", arguments: [
                            "text": text,
                            "isFinal": res.isFinal
                        ])
                    }
                }
                if error != nil || (res?.isFinal ?? false) {
                    self.cleanupSession()
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("onSpeechResult", arguments: [
                            "text": "",
                            "isFinal": true
                        ])
                    }
                }
            }

            self.audioEngine = AVAudioEngine()
            guard let audioEngine = self.audioEngine else {
                result("error: could not create audio engine")
                return
            }

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
                self?.recognitionRequest?.append(buffer)
            }

            do {
                try audioEngine.start()
                result("started")
            } catch {
                result("error: \(error.localizedDescription)")
            }
        }
    }

    private func stopListening(result: @escaping FlutterResult) {
        cleanupSession()
        result("stopped")
    }
}
