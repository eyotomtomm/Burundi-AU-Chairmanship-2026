import UserNotifications
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

        // FCM puts the image URL in userInfo["fcm_options"]["image"]
        guard let fcmOptions = bestAttemptContent.userInfo["fcm_options"] as? [String: Any],
              let imageURLString = fcmOptions["image"] as? String,
              let imageURL = URL(string: imageURLString) else {
            logger.info("No image URL in fcm_options — delivering text-only")
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
            let tmpFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            do {
                try FileManager.default.moveItem(at: location, to: tmpFile)

                // Provide a type hint so iOS can decode the image even if the extension is ambiguous
                var options: [String: Any] = [:]
                if let utType = UTType(filenameExtension: ext) {
                    options[UNNotificationAttachmentOptionsTypeHintKey] = utType.identifier
                }

                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: tmpFile,
                    options: options.isEmpty ? nil : options
                )
                bestAttemptContent.attachments = [attachment]
                logger.info("Image attached successfully (ext=\(ext, privacy: .public))")
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
