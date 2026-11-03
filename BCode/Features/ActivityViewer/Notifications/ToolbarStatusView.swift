//
//  ToolbarStatusView.swift
//  BCode
//

import SwiftUI

/// The status line under the project name in the toolbar, like Xcode's "Indexing" or "Build Succeeded".
///
/// It shows the newest task notification and takes no room while there is none.
struct ToolbarStatusView: View {
    @ObservedObject var taskNotificationHandler: TaskNotificationHandler

    var body: some View {
        Group {
            if !taskNotificationHandler.notifications.isEmpty {
                TaskNotificationView(taskNotificationHandler: taskNotificationHandler)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: taskNotificationHandler.notifications.isEmpty)
    }
}
