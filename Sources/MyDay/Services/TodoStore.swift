import Foundation
import Combine

/// Manages daily todo lists, persistence, day navigation, and overdue rollover.
public final class TodoStore: ObservableObject {
    @Published public private(set) var tasksByDay: [String: [TodoItem]] = [:]
    @Published public var selectedDate: Date

    private let storageURL: URL
    private let calendar: Calendar
    private let nowProvider: () -> Date

    private lazy var keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private lazy var displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    public init(
        storageURL: URL? = nil,
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.selectedDate = calendar.startOfDay(for: nowProvider())
        self.storageURL = storageURL ?? Self.defaultStorageURL()

        load()
        rolloverOverdueTasks()
    }

    public static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("MyDay", isDirectory: true)
        return directory.appendingPathComponent("todos.json")
    }

    // MARK: - Computed Properties

    public var todayKey: String {
        dayKey(for: nowProvider())
    }

    public var selectedDayKey: String {
        dayKey(for: selectedDate)
    }

    public var isViewingToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: nowProvider())
    }

    public var currentDayTasks: [TodoItem] {
        sortedTasks(tasksByDay[selectedDayKey] ?? [])
    }

    public var todayTasks: [TodoItem] {
        sortedTasks(tasksByDay[todayKey] ?? [])
    }

    /// Number of unchecked tasks for today (shown in the menu bar).
    public var todayUncheckedCount: Int {
        todayTasks.filter { !$0.isCompleted }.count
    }

    /// True when today still has at least one unchecked overdue task.
    public var hasUncheckedOverdueTasks: Bool {
        todayTasks.contains { !$0.isCompleted && $0.isOverdue }
    }

    /// Number of unchecked overdue tasks for today.
    public var todayOverdueCount: Int {
        todayTasks.filter { !$0.isCompleted && $0.isOverdue }.count
    }

    public var relativeDayTitle: String {
        let today = calendar.startOfDay(for: nowProvider())
        if calendar.isDate(selectedDate, inSameDayAs: today) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(selectedDate, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(selectedDate, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return displayDateFormatter.string(from: selectedDate)
    }

    public var formattedDateSubtitle: String {
        displayDateFormatter.string(from: selectedDate)
    }

    // MARK: - Actions

    public func addTask(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let key = selectedDayKey
        var tasks = tasksByDay[key] ?? []
        tasks.append(TodoItem(title: trimmed, createdAt: nowProvider()))
        tasksByDay[key] = sortedTasks(tasks)
        save()
    }

    public func toggleTask(id: UUID) {
        let key = selectedDayKey
        guard var tasks = tasksByDay[key],
              let index = tasks.firstIndex(where: { $0.id == id }) else {
            return
        }

        tasks[index].isCompleted.toggle()
        tasksByDay[key] = sortedTasks(tasks)
        save()
    }

    public func deleteTask(id: UUID) {
        let key = selectedDayKey
        guard var tasks = tasksByDay[key] else { return }
        tasks.removeAll { $0.id == id }
        tasksByDay[key] = tasks.isEmpty ? nil : tasks
        save()
    }

    public func goToPreviousDay() {
        if let prev = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = calendar.startOfDay(for: prev)
        }
    }

    public func goToNextDay() {
        if let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = calendar.startOfDay(for: next)
        }
    }

    public func goToToday() {
        selectedDate = calendar.startOfDay(for: nowProvider())
    }

    /// Moves any incomplete tasks from previous days (including yesterday) into today's list as overdue.
    public func rolloverOverdueTasks() {
        let currentTodayKey = todayKey
        let pastKeys = tasksByDay.keys.filter { $0 < currentTodayKey }.sorted()

        var carriedOver: [TodoItem] = []

        for key in pastKeys {
            guard let dayTasks = tasksByDay[key] else { continue }
            let remaining = dayTasks.filter { !$0.isCompleted }
            guard !remaining.isEmpty else { continue }

            let completed = dayTasks.filter { $0.isCompleted }
            tasksByDay[key] = completed.isEmpty ? nil : completed

            for var item in remaining {
                item.isOverdue = true
                carriedOver.append(item)
            }
        }

        guard !carriedOver.isEmpty else { return }

        var currentTodayTasks = tasksByDay[currentTodayKey] ?? []
        let existingIDs = Set(currentTodayTasks.map(\.id))
        let uniqueCarriedOver = carriedOver.filter { !existingIDs.contains($0.id) }

        currentTodayTasks.insert(contentsOf: uniqueCarriedOver, at: 0)
        tasksByDay[currentTodayKey] = sortedTasks(currentTodayTasks)
        save()
    }

    // MARK: - Helpers

    public func dayKey(for date: Date) -> String {
        keyFormatter.string(from: calendar.startOfDay(for: date))
    }

    private func sortedTasks(_ tasks: [TodoItem]) -> [TodoItem] {
        let unchecked = tasks.filter { !$0.isCompleted }
        let completed = tasks.filter { $0.isCompleted }
        return unchecked + completed
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            tasksByDay = try JSONDecoder().decode([String: [TodoItem]].self, from: data)
        } catch {
            tasksByDay = [:]
        }
    }

    private func save() {
        do {
            let directory = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tasksByDay)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Keep in-memory state even if disk write fails.
        }
    }
}
