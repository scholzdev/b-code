//
//  CEWorkspaceSettingsTests.swift
//  BCodeTests
//
//  Created by Khan Winter on 4/21/25.
//

import Foundation
import Testing
@testable import BCode

struct CEWorkspaceSettingsTests {
    let settings: CEWorkspaceSettings = CEWorkspaceSettings(workspaceURL: URL(filePath: "/"))

    @Test
    func settingsURLNoSpace() async throws {
        #expect(settings.folderURL.lastPathComponent == ".bcode")
        #expect(settings.settingsURL.lastPathComponent == "settings.json")
    }
}
