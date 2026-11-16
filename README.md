# MyDay

A lightweight, native macOS menu bar todo app built with Swift, AppKit, and SwiftUI.

## Features

- **Menu Bar Status**: Displays the `checklist` icon and today's remaining (unchecked) task count directly in the macOS top menu bar.
- **Overdue Rollover**: On startup (and at midnight), unfinished tasks from previous days are automatically carried over to today's list marked as **Overdue**, and the menu bar count turns **red** until all overdue tasks are checked off.
- **Native Task List**:
  - Displays today's date at the top.
  - Add tasks with a native input field (press Return or click `+`).
  - Native macOS checkboxes — checking a task strikes it out and moves it to the bottom of the list.
  - Hover over a task to delete it.
- **Day Navigation**: Navigate between previous and next days, with a quick **Today** button to jump back.
- **Launch at Login**: Built-in **Launch at Login** checkbox in the popover footer powered by `SMAppService.mainApp`.
- **Local Persistence**: Tasks are saved to `~/Library/Application Support/MyDay/todos.json`.

## Requirements

- macOS 13.0 or later
- Xcode / Swift 5.9+

## Build & Run

Run unit tests:

```bash
swift test
```

Build the standalone `MyDay.app` bundle:

```bash
./scripts/build_app.sh
```

Launch the app:

```bash
open dist/MyDay.app
```

To keep it permanently, drag `dist/MyDay.app` into `/Applications`.
