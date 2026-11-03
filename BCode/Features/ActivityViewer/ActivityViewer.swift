//
//  ActivityViewer.swift
//  BCode
//
//  Created by Tommy Ludwig on 21.06.24.
//

import SwiftUI

/// The activity area in the toolbar: the selected task (the scheme) and where it runs (the destination).
struct ActivityViewer: View {
    @Environment(\.colorScheme)
    var colorScheme

    var workspaceFileManager: CEWorkspaceFileManager?

    @ObservedObject var workspaceSettingsManager: CEWorkspaceSettings

    // TODO: try to get this from the envrionment
    @ObservedObject var taskManager: TaskManager

    init(
        workspaceFileManager: CEWorkspaceFileManager?,
        workspaceSettingsManager: CEWorkspaceSettings,
        taskManager: TaskManager
    ) {
        self.workspaceFileManager = workspaceFileManager
        self.workspaceSettingsManager = workspaceSettingsManager
        self.taskManager = taskManager
    }
    var body: some View {
        Group {
            if #available(macOS 26, *) {
                // Compact like Xcode's "scheme › destination" capsule; the status is under the project name.
                content
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(5)
                    .clipShape(Capsule())
            } else {
                content
                    .fixedSize(horizontal: false, vertical: false)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .frame(height: 22)
                    .clipped()
                    .background {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 5)
                                .opacity(0.1)
                        } else {
                            RoundedRectangle(cornerRadius: 5)
                                .opacity(0.1)
                        }
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity Viewer")
    }

    @ViewBuilder private var content: some View {
        // b-code: like Xcode's activity area, "scheme › destination". The selected task acts as the scheme.
        // The project name and the status are in the title area (`ToolbarBranchPicker`), as in Xcode.
        HStack(spacing: 0) {
            TaskDropDownView(taskManager: taskManager)

            if taskManager.selectedTask != nil {
                DestinationView(taskManager: taskManager)
            }
        }
    }
}
