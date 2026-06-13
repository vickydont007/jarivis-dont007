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
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            // Already authorized
            result("authorized")
        case .notDetermined:
            // Need to request
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    result(granted ? "authorized" : "denied")
                }
            }
        case .denied:
            // User denied - tell them to go to settings
            result("denied")
        case .restricted:
            // Restricted by MDM or parental controls
            result("restricted")
        @unknown default:
            result("unknown")
        }
    }

    private func checkMicPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
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
