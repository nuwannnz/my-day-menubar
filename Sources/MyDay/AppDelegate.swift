import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let store = TodoStore()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
        observeStore()
        observeDayChange()
        updateStatusButton()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "MyDay")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item
    }

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: TodoPopoverView(
                store: store,
                onQuit: { NSApp.terminate(nil) }
            )
        )
        self.popover = popover
    }

    private func observeStore() {
        store.$tasksByDay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)
    }

    private func observeDayChange() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.store.rolloverOverdueTasks()
                self.store.goToToday()
                self.updateStatusButton()
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }

        let count = store.todayUncheckedCount
        let isOverdue = store.hasUncheckedOverdueTasks

        let color: NSColor = isOverdue ? .systemRed : .labelColor
        let weight: NSFont.Weight = isOverdue ? .semibold : .regular
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: weight)

        let title = NSAttributedString(
            string: " \(count)",
            attributes: [
                .foregroundColor: color,
                .font: font
            ]
        )
        button.attributedTitle = title
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
