import Foundation
import OSLog

enum AppLogger {
    static let persistence = Logger(subsystem: "com.kv.veera", category: "persistence")
    static let progression = Logger(subsystem: "com.kv.veera", category: "progression")
    static let notifications = Logger(subsystem: "com.kv.veera", category: "notifications")
    static let questActions = Logger(subsystem: "com.kv.veera", category: "quest_actions")
}
