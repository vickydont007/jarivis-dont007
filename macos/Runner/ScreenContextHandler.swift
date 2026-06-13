import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import Vision

class ScreenContextHandler: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    private var isMonitoring = false
    private var monitorTimer: Timer?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.nextron/screen_context",
            binaryMessenger: registrar.messenger
        )
        let instance = ScreenContextHandler()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkPermissions":
            checkPermissions(result: result)
        case "requestPermissions":
            requestPermissions(result: result)
        case "captureScreen":
            captureScreen(result: result)
        case "captureScreenWithOCR":
            captureScreenWithOCR(result: result)
        case "getAccessibilityInfo":
            getAccessibilityInfo(result: result)
        case "getActiveApplication":
            getActiveApplication(result: result)
        case "getRunningApplications":
            getRunningApplications(result: result)
        case "startMonitoring":
            startMonitoring(result: result)
        case "stopMonitoring":
            stopMonitoring(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkPermissions(result: @escaping FlutterResult) {
        let hasPermission = CGPreflightScreenCaptureAccess()
        result(hasPermission)
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        let granted = CGRequestScreenCaptureAccess()
        result(granted)
    }

    private func captureScreen(result: @escaping FlutterResult) {
        guard CGPreflightScreenCaptureAccess() else {
            result([
                "success": false,
                "error": "Screen capture permission not granted"
            ])
            return
        }

        guard let window = NSApp.keyWindow,
              let screen = window.screen ?? NSScreen.main else {
            result([
                "success": false,
                "error": "No screen available"
            ])
            return
        }

        let rect = screen.frame
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            result([
                "success": false,
                "error": "Failed to capture screen"
            ])
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "screen_capture_\(timestamp).png"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        guard let cgContext = CGContext(
            url: fileURL as CFURL,
            releaseType: .none
        ) else {
            result([
                "success": false,
                "error": "Failed to create image context"
            ])
            return
        }

        cgContext.draw(cgImage, in: CGRect(origin: .zero, size: rect.size))

        result([
            "success": true,
            "screenshotPath": fileURL.path
        ])
    }

    private func captureScreenWithOCR(result: @escaping FlutterResult) {
        captureScreen { [weak self] captureResult in
            guard let self = self,
                  let dict = captureResult as? [String: Any],
                  let success = dict["success"] as? Bool,
                  success,
                  let path = dict["screenshotPath"] as? String else {
                result(captureResult)
                return
            }

            self.performOCR(on: path) { ocrText in
                var finalResult = dict
                finalResult["ocrText"] = ocrText
                result(finalResult)
            }
        }
    }

    private func captureScreen(completion: @escaping FlutterResult) {
        guard CGPreflightScreenCaptureAccess() else {
            completion([
                "success": false,
                "error": "Screen capture permission not granted"
            ])
            return
        }

        guard let screen = NSScreen.main else {
            completion([
                "success": false,
                "error": "No screen available"
            ])
            return
        }

        let rect = screen.frame
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            completion([
                "success": false,
                "error": "Failed to capture screen"
            ])
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "screen_capture_\(timestamp).png"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        guard let cgContext = CGContext(
            url: fileURL as CFURL,
            releaseType: .none
        ) else {
            completion([
                "success": false,
                "error": "Failed to create image context"
            ])
            return
        }

        cgContext.draw(cgImage, in: CGRect(origin: .zero, size: rect.size))

        completion([
            "success": true,
            "screenshotPath": fileURL.path
        ])
    }

    private func performOCR(on imagePath: String, completion: @escaping (String?) -> Void) {
        let fileURL = URL(fileURLWithPath: imagePath)
        guard let image = NSImage(contentsOf: fileURL),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else {
                completion(nil)
                return
            }

            let text = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            completion(text)
        }

        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(nil)
        }
    }

    private func getAccessibilityInfo(result: @escaping FlutterResult) {
        let trusted = AXIsProcessTrusted()
        guard trusted else {
            result([
                "success": false,
                "error": "Accessibility permission not granted"
            ])
            return
        }

        guard let app = NSWorkspace.shared.frontmostApplication,
              let pid = app.processIdentifier as NSValue? else {
            result([
                "success": false,
                "error": "No active application found"
            ])
            return
        }

        var element: AXUIElement?
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        var focusedElement: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        var elementTitle: String?
        if let element = focusedElement {
            var title: AnyObject?
            AXUIElementCopyAttributeValue(element as! AXUIElement, kAXTitleAttribute as CFString, &title)
            elementTitle = title as? String
        }

        result([
            "success": true,
            "focusedElement": elementTitle ?? "Unknown",
            "app": app.localizedName ?? "Unknown"
        ])
    }

    private func getActiveApplication(result: @escaping FlutterResult) {
        if let app = NSWorkspace.shared.frontmostApplication {
            result([
                "name": app.localizedName ?? "Unknown",
                "bundleId": app.bundleIdentifier ?? "Unknown",
                "processId": app.processIdentifier
            ])
        } else {
            result(nil)
        }
    }

    private func getRunningApplications(result: @escaping FlutterResult) {
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> [String: Any]? in
            guard let name = app.localizedName else { return nil }
            return [
                "name": name,
                "bundleId": app.bundleIdentifier ?? "Unknown",
                "processId": app.processIdentifier,
                "isActive": app.isActive
            ]
        }
        result(apps)
    }

    private func startMonitoring(result: @escaping FlutterResult) {
        guard !isMonitoring else {
            result(nil)
            return
        }

        isMonitoring = true
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.captureScreen { [weak self] captureResult in
                if let dict = captureResult as? [String: Any],
                   let success = dict["success"] as? Bool,
                   success {
                    self?.channel?.invokeMethod("onScreenChanged", arguments: dict)
                }
            }
        }
        result(nil)
    }

    private func stopMonitoring(result: @escaping FlutterResult) {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
        result(nil)
    }
}
