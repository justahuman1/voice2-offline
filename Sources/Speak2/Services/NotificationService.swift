import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private var authorized = false

    private init() {}

    private func ensureAuthorized(completion: @escaping (Bool) -> Void) {
        guard Bundle.main.bundleIdentifier != nil else {
            completion(false)
            return
        }
        if authorized {
            completion(true)
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
            completion(granted)
        }
    }

    func showTranscriptionComplete(text: String) {
        sendNotification(title: "Transcription Complete", body: text)
    }

    func showError(message: String) {
        sendNotification(title: "Speak2 Error", body: message)
    }

    func showCancelled() {
        sendNotification(title: "Recording Cancelled", body: "Recording was cancelled.")
    }

    func showSkipped() {
        sendNotification(title: "Recording Skipped", body: "No speech was detected.")
    }

    private func sendNotification(title: String, body: String) {
        ensureAuthorized { granted in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}
