import FlutterMacOS
import AVFoundation
import Speech

public class MicPermissionHandler: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.nextron.ai/mic_permission", binaryMessenger: registrar.messenger)
        let instance = MicPermissionHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            requestPermission(result: result)
        case "checkPermission":
            checkPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        // Request both microphone AND speech recognition
        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            if micGranted {
                // Now request speech recognition
                SFSpeechRecognizer.requestAuthorization { speechStatus in
                    DispatchQueue.main.async {
                        switch speechStatus {
                        case .authorized:
                            result("authorized")
                        case .denied:
                            result("denied")
                        case .restricted:
                            result("restricted")
                        case .notDetermined:
                            result("not_determined")
                        @unknown default:
                            result("unknown")
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    result("denied")
                }
            }
        }
    }

    private func checkPermission(result: @escaping FlutterResult) {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        if micStatus == .authorized && speechStatus == .authorized {
            result("authorized")
        } else if micStatus == .denied || speechStatus == .denied {
            result("denied")
        } else if micStatus == .restricted || speechStatus == .restricted {
            result("restricted")
        } else {
            result("not_determined")
        }
    }
}
