//
//  KeyWindowControllerObserver.swift
//  BCode
//
//  Created by Khan Winter on 7/2/24.
//

import SwiftUI

struct KeyWindowControllerObserver: ViewModifier {
    @Binding var windowController: BCodeWindowController?

    func body(content: Content) -> some View {
        content.onReceive(NSApp.publisher(for: \.keyWindow)) { window in
            windowController = window?.windowController as? BCodeWindowController
        }
    }
}

extension View {
    @ViewBuilder
    func observeWindowController(_ binding: Binding<BCodeWindowController?>) -> some View {
        self.modifier(KeyWindowControllerObserver(windowController: binding))
    }
}
