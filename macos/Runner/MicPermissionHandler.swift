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
        case "requestPermission":
            requestPermission(result: result)
        case "checkPermission":
            checkPermission(result: result)
        case "startListening":
            startListening(result: result)
        case "stopListening":
            stopListening(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        result(status == .authorized ? "authorized" : "denied")
                    }
                }
            } else {
                DispatchQueue.main.async { result("denied") }
            }
        }
    }

    private func checkPermission(result: @escaping FlutterResult) {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        let speech = SFSpeechRecognizer.authorizationStatus()
        if mic == .authorized && speech == .authorized {
            result("authorized")
        } else if mic == .denied || speech == .denied {
            result("denied")
        } else {
            result("not_determined")
        }
    }

    private func startListening(result: @escaping FlutterResult) {
        recognitionTask?.cancel()
        recognitionTask = nil

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            result("error: speech recognizer not available")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            result("error: could not create request")
            return
        }
        recognitionRequest.shouldReportPartialResults = false

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            result("error: could not create audio engine")
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let self = self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.channel?.invokeMethod("onSpeechResult", arguments: ["text": text, "isFinal": result.isFinal])
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening(result: { _ in })
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            try audioEngine.start()
            result("started")
        } catch {
            result("error: \(error.localizedDescription)")
        }
    }

    private func stopListening(result: @escaping FlutterResult) {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        result("stopped")
    }
}
