//
//  EditorTabsOverflowShadow.swift
//  BCode
//
//  Created by Austin Condiff on 8/22/23.
//

import SwiftUI

struct EditorTabsOverflowShadow: View {
    var width: CGFloat
    var startPoint: UnitPoint
    var endPoint: UnitPoint

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.controlActiveState)
    private var activeState

    /// The overall strength of the shadow, depending on the appearance and on whether the window is active.
    ///
    /// It is folded into the gradient stops instead of calling `.opacity(_:)` on the gradient, because that call is
    /// ambiguous between `View` and `ShapeStyle` in the macOS 27 SDK.
    private var shadowOpacity: Double {
        colorScheme == .dark
            ? activeState == .inactive ? 0.25882353 : 1
            : activeState == .inactive ? 0.09803922 : 0.25882353
    }

    var body: some View {
        Rectangle()
            .frame(maxHeight: .infinity)
            .frame(width: width)
            .foregroundColor(.clear)
            .background(
                LinearGradient(
                    gradient: Gradient(
                        stops: [
                            Gradient.Stop(color: .black.opacity(0.75 * shadowOpacity), location: 0),
                            Gradient.Stop(color: .black.opacity(0.25 * shadowOpacity), location: 0.5),
                            Gradient.Stop(color: .black.opacity(0), location: 1)
                        ]
                    ),
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
            .allowsHitTesting(false)
    }
}
