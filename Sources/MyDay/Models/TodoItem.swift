import Foundation

/// Represents a single todo item for a specific day.
public struct TodoItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var isOverdue: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        isOverdue: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.isOverdue = isOverdue
        self.createdAt = createdAt
    }
}
