import Foundation
import Combine
import UserNotifications

@MainActor protocol LocalReminderGateway {
    func allowed() async -> Bool
    func authorize() async throws -> Bool
    func pendingIDs() async -> [String]
    func remove(_ ids: [String])
    func clearDelivered() async
    func add(_ reminder: NativeReminder) async throws
}
@MainActor final class NativeReminderGateway: LocalReminderGateway {
    let center = UNUserNotificationCenter.current()
    func allowed() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }
    func authorize() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
    func pendingIDs() async -> [String] { await center.pendingNotificationRequests().map(\.identifier) }
    func remove(_ ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }
    func clearDelivered() async {
        let ids = await center.deliveredNotifications().map { $0.request.identifier }.filter { $0.hasPrefix(NativeReminder.prefix) }
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
    func add(_ reminder: NativeReminder) async throws {
        let content = UNMutableNotificationContent(); content.title = reminder.title; content.body = reminder.body; content.sound = .default
        content.userInfo = ["kind": reminder.kind, "userId": reminder.owner.uuidString.lowercased()]
        // No fixed time zone: iOS schedules this local wall-clock time, including DST.
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: reminder.hour, minute: reminder.minute), repeats: true)
        try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }
}

@MainActor final class LocalReminderService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var permission = false
    @Published private(set) var message: String?
    @Published var programRequest: UUID?
    private let gateway: any LocalReminderGateway
    private var owner: UUID?
    private var settings = ReminderSettings()
    private var generation = 0
    private var pending = false
    private var clearDelivered = false
    private var worker: Task<Void, Never>?
    private var requestedAccount: String?
    init(gateway: (any LocalReminderGateway)? = nil) {
        let selected = gateway ?? NativeReminderGateway()
        self.gateway = selected; super.init()
        if let native = selected as? NativeReminderGateway { native.center.delegate = self }
    }
    func update(owner: UUID?, settings: ReminderSettings, force: Bool = false) {
        guard force || owner != self.owner || settings != self.settings else { return }
        if owner != self.owner { clearDelivered = true; programRequest = nil; message = nil }
        self.owner = owner; self.settings = settings; generation += 1; pending = true
        if let user = requestedAccount, let owner { requestedAccount = nil; if user == owner.uuidString.lowercased() { programRequest = UUID() } }
        guard worker == nil else { return }
        worker = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.pending { self.pending = false; await self.reconcile() }
            self.worker = nil
        }
    }
    private func reconcile() async {
        let token = generation, account = owner, preferences = settings
        let ids = await gateway.pendingIDs().filter { $0.hasPrefix(NativeReminder.prefix) }
        guard token == generation else { return }
        gateway.remove(ids)
        if clearDelivered { clearDelivered = false; await gateway.clearDelivered() }
        guard token == generation else { return }
        permission = await gateway.allowed()
        guard token == generation, permission, let account else { return }
        do {
            for reminder in NativeReminder.plan(owner: account, settings: preferences) {
                guard token == generation else { return }
                try await gateway.add(reminder)
                guard token == generation else { gateway.remove([reminder.id]); return }
            }
            message = nil
        } catch { if token == generation { message = "Les rappels n’ont pas pu être programmés sur cet iPhone." } }
    }
    func authorize() async {
        do { permission = try await gateway.authorize(); message = permission ? nil : "Autorise les notifications dans les réglages iOS pour recevoir les rappels." }
        catch { message = "L’autorisation des notifications n’a pas pu être demandée." }
        update(owner: owner, settings: settings, force: true)
    }
    func waitForUpdates() async { await worker?.value }
    func openReminder(user: String?, kind: String?) {
        guard let user, UUID(uuidString: user) != nil, ["learning-reminder", "revision-reminder"].contains(kind ?? "") else { return }
        if let owner { if user.lowercased() == owner.uuidString.lowercased() { programRequest = UUID() } }
        else { requestedAccount = user.lowercased() }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let user = notification.request.content.userInfo["userId"] as? String
        Task { @MainActor [weak self] in
            guard let owner = self?.owner, user == owner.uuidString.lowercased() else { completionHandler([]); return }
            completionHandler([.banner, .sound])
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let data = response.notification.request.content.userInfo
        let user = data["userId"] as? String, kind = data["kind"] as? String
        Task { @MainActor [weak self] in
            defer { completionHandler() }
            self?.openReminder(user: user, kind: kind)
        }
    }
}
