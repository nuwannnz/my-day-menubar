import SwiftUI

struct TodoPopoverView: View {
    @ObservedObject var store: TodoStore
    let onQuit: () -> Void

    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @State private var newTaskTitle: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            addTaskBar
            Divider()
            taskListView
            Divider()
            footerView
        }
        .frame(width: 320, height: 420)
        .onAppear {
            isInputFocused = true
            launchAtLogin.refresh()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Button(action: store.goToPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Previous Day")

            VStack(spacing: 1) {
                Text(store.relativeDayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if store.relativeDayTitle != store.formattedDateSubtitle {
                    Text(store.formattedDateSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            if !store.isViewingToday {
                Button("Today") {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.goToToday()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button(action: store.goToNextDay) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Next Day")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Add Task

    private var addTaskBar: some View {
        HStack(spacing: 8) {
            TextField("Add a task...", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .onSubmit(submitNewTask)

            Button(action: submitNewTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.borderless)
            .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Add Task")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Task List

    private var taskListView: some View {
        let tasks = store.currentDayTasks

        return Group {
            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No tasks for \(store.relativeDayTitle.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(tasks) { task in
                            TaskRowView(
                                item: task,
                                onToggle: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        store.toggleTask(id: task.id)
                                    }
                                },
                                onDelete: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        store.deleteTask(id: task.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        let remaining = store.currentDayTasks.filter { !$0.isCompleted }.count
        let overdue = store.currentDayTasks.filter { !$0.isCompleted && $0.isOverdue }.count

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(remaining) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if overdue > 0 {
                    Text("• \(overdue) overdue")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }

                Spacer()
            }

            HStack {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Quit") {
                    onQuit()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let errorMessage = launchAtLogin.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func submitNewTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            store.addTask(title: trimmed)
        }
        newTaskTitle = ""
        isInputFocused = true
    }
}

private struct TaskRowView: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(isOn: Binding(
                get: { item.isCompleted },
                set: { _ in onToggle() }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text(item.title)
                .font(.system(size: 13))
                .strikethrough(item.isCompleted, color: .secondary)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggle)

            if item.isOverdue && !item.isCompleted {
                Text("Overdue")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.12), in: Capsule())
            }

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .help("Delete Task")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
