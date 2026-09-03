import UserNotifications
import UIKit
import os.log
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "com.b4africa.app.ImageNotificationService", category: "NotificationService")

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Try to find the image URL. FCM may place it in different locations
        // depending on whether FirebaseAppDelegateProxyEnabled is on or off:
        //   1. fcm_options.image  (when proxy swizzling is enabled)
        //   2. image_url          (data payload — always delivered)
        let imageURLString: String? = {
            if let fcmOptions = bestAttemptContent.userInfo["fcm_options"] as? [String: Any],
               let url = fcmOptions["image"] as? String, !url.isEmpty {
                return url
            }
            if let url = bestAttemptContent.userInfo["image_url"] as? String, !url.isEmpty {
                return url
            }
            return nil
        }()

        guard let imageURLString = imageURLString,
              let imageURL = URL(string: imageURLString) else {
            logger.info("No image URL found in fcm_options or data payload — delivering text-only")
            contentHandler(bestAttemptContent)
            return
        }

        logger.info("Downloading notification image: \(imageURLString, privacy: .public)")

        var request = URLRequest(url: imageURL)
        request.timeoutInterval = 25  // Leave headroom before the 30s extension limit

        let task = URLSession.shared.downloadTask(with: request) { location, response, error in
            defer { contentHandler(bestAttemptContent) }

            if let error = error {
                logger.error("Image download failed: \(error.localizedDescription, privacy: .public)")
                return
            }

            guard let location = location else {
                logger.error("Image download returned nil location")
                return
            }

            // Determine file extension from URL path, response MIME type, or default to jpg
            let ext = Self.fileExtension(from: imageURL, response: response)
            // UNNotificationAttachment only accepts JPEG/PNG/GIF. The backend
            // auto-converts every uploaded image to WebP (see _auto_optimize_image),
            // which iOS rejects outright — so anything else gets transcoded to JPEG.
            let attachExt = Self.attachableExtensions.contains(ext) ? ext : "jpg"
            let tmpFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(attachExt)

            do {
                if attachExt == ext {
                    try FileManager.default.moveItem(at: location, to: tmpFile)
                } else {
                    guard let data = try? Data(contentsOf: location),
                          let image = UIImage(data: data),
                          let jpeg = image.jpegData(compressionQuality: 0.9) else {
                        logger.error("Could not transcode \(ext, privacy: .public) image to JPEG")
                        return
                    }
                    try jpeg.write(to: tmpFile)
                    logger.info("Transcoded \(ext, privacy: .public) → jpg for attachment")
                }

                // Provide a type hint so iOS can decode the image even if the extension is ambiguous
                var options: [String: Any] = [:]
                if let utType = UTType(filenameExtension: attachExt) {
                    options[UNNotificationAttachmentOptionsTypeHintKey] = utType.identifier
                }

                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: tmpFile,
                    options: options.isEmpty ? nil : options
                )
                bestAttemptContent.attachments = [attachment]
                logger.info("Image attached successfully (ext=\(attachExt, privacy: .public))")
            } catch {
                logger.error("Failed to attach image: \(error.localizedDescription, privacy: .public)")
                // Clean up temp file on failure
                try? FileManager.default.removeItem(at: tmpFile)
            }
        }
        task.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        logger.warning("Extension time expired — delivering without image")
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    /// Image formats iOS will accept directly as a notification attachment.
    private static let attachableExtensions: Set<String> = ["jpg", "jpeg", "png", "gif"]

    /// Determine the best file extension for the downloaded image.
    /// Priority: response Content-Type → URL path extension → fallback "jpg"
    private static func fileExtension(from url: URL, response: URLResponse?) -> String {
        // 1. Try MIME type from the HTTP response
        if let mimeType = response?.mimeType,
           let utType = UTType(mimeType: mimeType),
           let ext = utType.preferredFilenameExtension {
            return ext
        }
        // 2. Try URL path extension
        let pathExt = url.pathExtension.lowercased()
        if !pathExt.isEmpty && ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(pathExt) {
            return pathExt
        }
        // 3. Fallback
        return "jpg"
    }
}
