import UserNotifications

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
            contentHandler(bestAttemptContent)
            return
        }

        let task = URLSession.shared.downloadTask(with: imageURL) { location, _, error in
            defer { contentHandler(bestAttemptContent) }

            guard let location = location, error == nil else { return }

            let ext = imageURL.pathExtension.isEmpty ? "jpg" : imageURL.pathExtension
            let tmpFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            do {
                try FileManager.default.moveItem(at: location, to: tmpFile)
                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: tmpFile,
                    options: nil
                )
                bestAttemptContent.attachments = [attachment]
            } catch {
                // Silently fail — deliver notification without image
            }
        }
        task.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
