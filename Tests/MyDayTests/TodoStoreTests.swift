import XCTest
@testable import MyDay

final class TodoStoreTests: XCTestCase {
    private var tempDir: URL!
    private var storageURL: URL!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storageURL = tempDir.appendingPathComponent("todos.json")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
    }

    func testAddAndToggleMovesCompletedTaskToBottom() {
        let today = makeDate(year: 2026, month: 11, day: 16)
        let store = TodoStore(storageURL: storageURL, calendar: calendar, nowProvider: { today })

        store.addTask(title: "First")
        store.addTask(title: "Second")
        store.addTask(title: "Third")

        XCTAssertEqual(store.currentDayTasks.map(\.title), ["First", "Second", "Third"])
        XCTAssertEqual(store.todayUncheckedCount, 3)

        let firstID = store.currentDayTasks[0].id
        store.toggleTask(id: firstID)

        XCTAssertEqual(store.currentDayTasks.map(\.title), ["Second", "Third", "First"])
        XCTAssertTrue(store.currentDayTasks.last?.isCompleted == true)
        XCTAssertEqual(store.todayUncheckedCount, 2)

        // Unticking moves it back into unchecked tasks.
        store.toggleTask(id: firstID)
        XCTAssertEqual(store.currentDayTasks.map(\.title), ["Second", "Third", "First"])
        XCTAssertFalse(store.currentDayTasks.last?.isCompleted == true)
        XCTAssertEqual(store.todayUncheckedCount, 3)
    }

    func testDayNavigation() {
        let today = makeDate(year: 2026, month: 11, day: 16)
        let store = TodoStore(storageURL: storageURL, calendar: calendar, nowProvider: { today })

        XCTAssertTrue(store.isViewingToday)
        XCTAssertEqual(store.relativeDayTitle, "Today")

        store.goToPreviousDay()
        XCTAssertFalse(store.isViewingToday)
        XCTAssertEqual(store.relativeDayTitle, "Yesterday")
        store.addTask(title: "Yesterday task")
        XCTAssertEqual(store.currentDayTasks.map(\.title), ["Yesterday task"])

        store.goToNextDay()
        XCTAssertTrue(store.isViewingToday)
        XCTAssertEqual(store.currentDayTasks, [])

        store.goToNextDay()
        XCTAssertEqual(store.relativeDayTitle, "Tomorrow")

        store.goToToday()
        XCTAssertTrue(store.isViewingToday)
    }

    func testStartupRolloverCarriesYesterdayRemainingTasksAsOverdue() {
        let yesterday = makeDate(year: 2026, month: 11, day: 15)
        let today = makeDate(year: 2026, month: 11, day: 16)

        // Create tasks on yesterday.
        let yesterdayStore = TodoStore(storageURL: storageURL, calendar: calendar, nowProvider: { yesterday })
        yesterdayStore.addTask(title: "Done yesterday")
        yesterdayStore.addTask(title: "Unfinished yesterday")

        let doneID = yesterdayStore.currentDayTasks[0].id
        yesterdayStore.toggleTask(id: doneID)

        // Launch store on today.
        let todayStore = TodoStore(storageURL: storageURL, calendar: calendar, nowProvider: { today })

        XCTAssertEqual(todayStore.todayTasks.count, 1)
        XCTAssertEqual(todayStore.todayTasks[0].title, "Unfinished yesterday")
        XCTAssertTrue(todayStore.todayTasks[0].isOverdue)
        XCTAssertFalse(todayStore.todayTasks[0].isCompleted)
        XCTAssertEqual(todayStore.todayUncheckedCount, 1)
        XCTAssertTrue(todayStore.hasUncheckedOverdueTasks)

        // Yesterday should still retain its completed task.
        todayStore.goToPreviousDay()
        XCTAssertEqual(todayStore.currentDayTasks.map(\.title), ["Done yesterday"])
        XCTAssertTrue(todayStore.currentDayTasks[0].isCompleted)

        // Completing the overdue task clears the overdue flag for the menu bar count.
        todayStore.goToToday()
        todayStore.toggleTask(id: todayStore.todayTasks[0].id)
        XCTAssertEqual(todayStore.todayUncheckedCount, 0)
        XCTAssertFalse(todayStore.hasUncheckedOverdueTasks)

        // Relaunching should not duplicate anything.
        let relaunchedStore = TodoStore(storageURL: storageURL, calendar: calendar, nowProvider: { today })
        XCTAssertEqual(relaunchedStore.todayTasks.count, 1)
        XCTAssertEqual(relaunchedStore.todayUncheckedCount, 0)
        XCTAssertFalse(relaunchedStore.hasUncheckedOverdueTasks)
    }
}
