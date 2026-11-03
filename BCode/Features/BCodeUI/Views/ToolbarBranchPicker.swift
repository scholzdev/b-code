//
//  ToolbarBranchPicker.swift
//  BCodeModules/BCodeUI
//
//  Created by Lukas Pistrol on 21.04.22.
//

import SwiftUI
import BCSymbols
import Combine

/// The title area of the toolbar, like Xcode's: the project's icon and name, with the current status below it.
///
/// Clicking the name opens the branch picker; the current branch is in the name's tooltip.
struct ToolbarBranchPicker: View {
    private weak var workspaceFileManager: CEWorkspaceFileManager?
    private weak var sourceControlManager: SourceControlManager?
    private let taskNotificationHandler: TaskNotificationHandler?
    private let projectIcon: NSImage?

    @Environment(\.controlActiveState)
    private var controlActive

    @State private var currentBranch: GitBranch?

    /// Initializes the ``ToolbarBranchPicker`` with an instance of a `WorkspaceClient`
    /// - Parameters:
    ///   - workspaceFileManager: The file manager of the current workspace.
    ///   - taskNotificationHandler: Supplies the status shown under the project name.
    init(
        workspaceFileManager: CEWorkspaceFileManager?,
        taskNotificationHandler: TaskNotificationHandler? = nil
    ) {
        self.workspaceFileManager = workspaceFileManager
        self.sourceControlManager = workspaceFileManager?.sourceControlManager
        self.taskNotificationHandler = taskNotificationHandler
        self.projectIcon = workspaceFileManager.map {
            NSWorkspace.shared.icon(forFile: $0.folderUrl.path(percentEncoded: false))
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                titleView
                if let taskNotificationHandler {
                    ToolbarStatusView(taskNotificationHandler: taskNotificationHandler)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { (_) in
            if self.currentBranch != nil {
                Task {
                    await sourceControlManager?.refreshCurrentBranch()
                }
            }
        }
        .onReceive(
            self.sourceControlManager?.$currentBranch.eraseToAnyPublisher() ??
            Empty().eraseToAnyPublisher()
        ) { branch in
            self.currentBranch = branch
        }
        .task {
            if Settings.shared.preferences.sourceControl.general.sourceControlIsEnabled {
                await self.sourceControlManager?.refreshCurrentBranch()
                await self.sourceControlManager?.refreshBranches()
            }
        }
        .if(.tahoe) {
            $0.padding(.leading, 10).frame(minWidth: 140, alignment: .leading)
        }
    }

    @ViewBuilder private var icon: some View {
        if let projectIcon {
            Image(nsImage: projectIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 20, height: 20)
                .opacity(controlActive == .inactive ? 0.5 : 1.0)
        } else {
            Image(systemName: "folder.fill.badge.gearshape")
                .foregroundColor(controlActive == .inactive ? inactiveColor : .secondary)
                .font(.system(size: 14))
                .imageScale(.medium)
                .frame(width: 17, height: 17)
        }
    }

    /// The project name. In a git repository it opens the branch picker, like the subtitle used to.
    @ViewBuilder private var titleView: some View {
        if let currentBranch, let sourceControlManager {
            Menu {
                PopoverView(sourceControlManager: sourceControlManager)
            } label: {
                titleText
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("\(title) – Branch: \(currentBranch.name)")
            .accessibilityValue(currentBranch.name)
        } else {
            titleText
                .help(title)
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundColor(controlActive == .inactive ? inactiveColor : .primary)
            .lineLimit(1)
    }

    private var inactiveColor: Color {
        Color(nsColor: .disabledControlTextColor)
    }

    private var title: String {
        workspaceFileManager?.folderUrl.lastPathComponent ?? "Empty"
    }

    // MARK: Popover View

    /// A popover view that appears once the branch picker is tapped.
    ///
    /// It displays the currently checked-out branch and all other local branches.
    private struct PopoverView: View {
        @ObservedObject var sourceControlManager: SourceControlManager

        var body: some View {
            VStack(alignment: .leading) {
                if let currentBranch = sourceControlManager.currentBranch {
                    Section {
                        headerLabel("Current Branch")
                        BranchCell(sourceControlManager: sourceControlManager, branch: currentBranch, active: true)
                    }
                }

                let branches = sourceControlManager.orderedLocalBranches
                    .filter({ $0 != sourceControlManager.currentBranch })
                let branchesGroups = branches.reduce(into: [String: GitBranchesGroup]()) { result, branch in
                    guard let branchPrefix = branch.name.components(separatedBy: "/").first else {
                        return
                    }

                    result[
                        branchPrefix.lowercased(),
                        default: GitBranchesGroup(name: branchPrefix, branches: [])
                    ].branches.append(branch)
                }

                if !branches.isEmpty {
                    Section {
                        headerLabel("Branches")
                        ForEach(branchesGroups.keys.sorted(), id: \.self) { branchGroupPrefix in
                            if let group = branchesGroups[branchGroupPrefix] {
                                if !group.shouldNest {
                                    BranchCell(
                                        sourceControlManager: sourceControlManager,
                                        branch: group.branches.first!
                                    )
                                } else {
                                    Menu(content: {
                                        ForEach(group.branches, id: \.self) { branch in
                                            BranchCell(
                                                sourceControlManager: sourceControlManager,
                                                branch: branch,
                                                title: String(
                                                    branch.name.suffix(branch.name.count - branchGroupPrefix.count - 1)
                                                )
                                            )
                                        }
                                    }, label: {
                                        HStack {
                                            Image(systemName: "folder")
                                            Text(group.name)
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 10)
            .padding(5)
            .frame(width: 340)
        }

        func headerLabel(_ title: String) -> some View {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 5)
        }

        // MARK: Branch Cell

        /// A Button Cell that represents a branch in the branch picker
        struct BranchCell: View {
            let sourceControlManager: SourceControlManager
            let branch: GitBranch
            let active: Bool
            let title: String?

            init(
                sourceControlManager: SourceControlManager,
                branch: GitBranch,
                active: Bool = false,
                title: String? = nil
            ) {
                self.sourceControlManager = sourceControlManager
                self.branch = branch
                self.active = active
                self.title = title
            }

            var body: some View {
                Button {
                    switchBranch()
                } label: {
                    HStack {
                        if active {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Image.branch
                        }
                        Text(self.title ?? branch.name)
                    }
                }
            }

            func switchBranch() {
                Task {
                    do {
                        try await sourceControlManager.checkoutBranch(branch: branch)
                    } catch {
                        await sourceControlManager.showAlertForError(title: "Failed to checkout", error: error)
                    }
                }
            }
        }
    }
}
