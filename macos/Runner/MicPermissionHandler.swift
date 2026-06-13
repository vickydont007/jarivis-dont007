import FlutterMacOS
import AVFoundation

public class MicPermissionHandler: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.nextron.ai/mic_permission", binaryMessenger: registrar.messenger)
        let instance = MicPermissionHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermission":
            requestMicPermission(result: result)
        case "checkPermission":
            checkMicPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestMicPermission(result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            result(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }
        case .denied, .restricted:
            result(false)
        @unknown default:
            result(false)
        }
    }

    private func checkMicPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        result(status == .authorized || status == .notDetermined)
    }
}
