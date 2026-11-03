//
//  DestinationView.swift
//  BCode
//

import SwiftUI

/// The destination half of the activity viewer, like Xcode's run destination next to the scheme:
/// where the selected task runs, for example "My Mac" or "Robots".
///
/// It shows the selected task's `target`. It is not interactive yet; choosing robots comes with the robot picker.
struct DestinationView: View {
    @Environment(\.controlActiveState)
    private var activeState

    @ObservedObject var taskManager: TaskManager

    /// The destination shown when a task does not name one.
    static let defaultDestination = "My Mac"

    private var destination: String {
        guard let target = taskManager.selectedTask?.target, !target.isEmpty else {
            return Self.defaultDestination
        }
        return target
    }

    private var iconName: String {
        destination == Self.defaultDestination ? "desktopcomputer" : "antenna.radiowaves.left.and.right"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.compact.right")
                .font(.system(size: 9, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .scaleEffect(x: 1.30, y: 1.0, anchor: .center)
                .imageScale(.large)
            Image(systemName: iconName)
            Text(destination)
                .frame(minWidth: 0)
        }
        .font(.subheadline)
        .padding(.vertical, 6)
        .padding(.trailing, 6)
        .opacity(activeState == .inactive ? 0.4 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run Destination")
        .accessibilityValue(destination)
    }
}
