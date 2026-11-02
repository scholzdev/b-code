# b-shell / Deploy: findings and design

Status of this document: written against `scholzdev/b-code` at `fa2aebd` (CodeEdit snapshot) and the B-Human
Code Release tag `coderelease2026` (`2e3374b`, 2026-10-10). File and line references are to those revisions.
Nothing in this document has been run on a Mac: the environment it was written in is Linux without a Swift
toolchain, so every statement about runtime behavior of CodeEdit is read from source, not observed.

This PR changes **no CodeEdit file**. It adds `Packages/BHumanKit` (Foundation-only models and services) and this
document. All hooks below are proposals.

## 1. What the B-Human Code Release contains (and where it differs from the brief)

The task description assumed that `bush` deploys code to NAO robots. The 2026 release does not match that:

| Assumption | What `coderelease2026` contains |
| --- | --- |
| A tool called `bush` | No `bush` anywhere (a case-insensitive search over the text files of the 5238-file checkout finds nothing). The equivalent is the **Deploy Dialog** (`Src/Apps/DeployDialog`, a Qt app) plus the shell script `Make/Common/deploy`. |
| NAO robots | **Booster K1 / T1** humanoids (`Config/Robots/robots.cfg` → `robotType = k1 \| t1`, `Make/Common/setupTarget` maps both to user `booster`, arch `Arm64`). `nao` appears in 7 files only. |
| A Code Release that is reachable | Reachable. `github.com/bhuman/BHumanCodeRelease` was cloned through the session's anonymous git lane. `docs.b-human.de` is denied by the environment's egress policy and was not used; everything below is read from the source. |

Tags `coderelease2013` … `coderelease2025` exist upstream. I did not inspect them, so I cannot say which older
release still ships `bush` or targets NAOs. If the team needs NAO support, that has to be checked against the
matching tag before BHumanKit's `RobotType` is extended.

**Decision for the owner:** BHumanKit and the proposals below follow the 2026 release (Deploy Dialog, Booster).
If the intended target is an older `bush`/NAO release, the models (`RobotType`, remote status command, `deploy`
flags) need re-basing on that tag.

### 1.1 How deployment works today

```
Xcode/VS Code "deploy" target
        │ builds DeployDialog (Qt), then runs Make/Common/deployDialog <Configuration>
        ▼
DeployDialog ── reads ──► Config/Robots/*/network.cfg   (name, lan, wlan per robot)
        │       reads ──► Config/teams.cfg              (presets: colors, scenario, players[], ...)
        │       pings lan + wlan of every robot every cycle, then over ssh asks for battery/temp/logs/...
        │ user picks preset, drags robots onto player numbers, presses Deploy
        ▼ prints ONE line to stdout:
   "<ip> -p <n> -k -nc -t .. -c .. -g .. -s .. -l .. -m .. -w .. -v .. [-d] [-b]"        (one robot)
   "-r <n> <ip> -r <n> <ip> ... -nc -t .. -c .. ..."                                        (several)
        ▼
Make/Common/deployDialog ── runs ──► Make/Common/deploy <Configuration> <that line>
        ▼
deploy: [compile unless -nc] → ping check → ssh stop bhuman → rsync Build + Config + Profiles →
        set wireless profile / volume → sed settings.cfg on the robot → [restart bhuman]
        (several robots: one background `copy` per robot, output prefixed "[<ip>] ")
```

Sources: `Make/Common/deployDialog`, `Make/Common/deploy`, `Src/Apps/DeployDialog/{DeployDialog,RobotsTable,SettingsArea}.cpp`.
The dialog always passes `-nc`; compiling happens before the dialog opens. On macOS, `Make/macOS/generate`
creates the Xcode schemes `Booster - Debug|Develop|Release`, which build `Booster` and have the Deploy Dialog as
runnable target, so Xcode's *Run* is "compile, then open the Deploy Dialog". On Windows/WSL the CMake target
`deploy` depends on `Booster` and `DeployDialog` (`Make/CMake/deploy.cmake`). b-code's Run/Deploy button for a
B-Human checkout replaces exactly that flow.

Compile commands, taken from `deploy`: macOS `Make/macOS/compile <target> <config>` (wraps `xcodebuild`),
Linux/WSL `cmake --build Build/Linux/CMake/<config> --target <target> --config <config>`; the target is `Booster`.

### 1.2 Mapping of the brief's concepts to BHumanKit

| Brief | BHumanKit | B-Human source of truth |
| --- | --- | --- |
| Team | `Team` | A *preset* in `Config/teams.cfg`: `name, number, fieldPlayerColor, goalkeeperColor, scenario, location, wlanConfig, volume, magicNumber, players[]` (`_` = no robot). |
| Robot (name, IP wired/wireless) | `Robot`, `RobotType` | `Config/Robots/<name>/network.cfg` (`name`, `lan`, `wlan`); model from `robots.cfg`. |
| Role playing / substitute / pool | `RobotRole`, `Team.assigningRoles(to:substitutes:)` | **Derived, not stored on the robot.** Playing = listed in the preset's `players` (index+1 = player number). Substitute = in the Deploy Dialog's ordered substitutes list (kept in Qt `QSettings`, not in the repo). Pool = any other known robot. This matches the dialog's table: a fixed block of player-number rows per preset, then a free-form block. |
| BuildConfiguration | `BuildConfiguration` | `Release`, `Develop`, `Debug`; `Develop` is the script default. |
| `settings.cfg` parser (team number) | `ConfigParser`, `BHumanSettings` | `Config/settings.cfg`: `teamNumber, fieldPlayerColor, goalkeeperColor, playerNumber, location, scenario, magicNumber`. |
| DeployService | `DeployService`, `DeployRequest`, `CommandRunner` | Mirrors the dialog→`deploy` contract above. |
| RobotStatus | `RobotStatus`, `RobotStatusParser`, `RobotStatusProviding` | Dialog columns: ping lan, ping wlan, battery, temperature, logs, calibration, service, crash dump. Thresholds copied from `DeployDialog.h` (ping 250/500 ms, 2000 ms = unreachable, battery < 70 %, 80/95 °C). |

### 1.3 Observations about upstream behavior

- `deploy` exits 0 even if copying to an individual robot fails when several robots are deployed in parallel
  (`copy … &` followed by a bare `wait`). A UI must look at the `[<ip>]`-prefixed output, not only the exit code.
  `DeployService` documents this; it does not parse the output yet.
- In `DeployDialog.cpp` the "new calibration present" highlight is computed from the *fifth* status field
  (`output[4] == "yes"`, which is the service state), so it can never trigger; the text of the *fourth* field is
  what is shown. `RobotStatusParser` reads the fourth field. This is a deliberate difference, covered by a test.
- Battery and temperature are only meaningful while the `bhuman` service is `active`; the log being written is
  not counted. Both rules are reproduced.

### 1.4 License

`License.md` of the Code Release is BSD-style with RoboCup-specific conditions (announcement on the HSL mailing
list one month before first use in a competition; "derived software" duties if major parts are used; an
acknowledgment in end-user documentation). BHumanKit contains **no copied C++ or shell sources**; it re-implements
file formats and command-line contracts. The one embedded fragment, the remote status command in
`ShellRobotStatusProvider`, is re-composed from the Deploy Dialog and carries an attribution comment. Whether the
team's use of the Deploy Dialog's behavior counts as use of "parts of this code release" for competition rules
is a question for the team, not something this document settles.

## 2. Where things live in CodeEdit

All paths relative to the repository root (`CodeEdit/…` is the app target).

| Concern | Location | Notes |
| --- | --- | --- |
| Window, owns the toolbar and split view | `CodeEdit/Features/Documents/Controllers/CodeEditWindowController.swift` | `init` at ~L40–77 calls `setupSplitView` (L91), `setupToolbar()` (L76), `registerCommands()`. `navigatorSidebarViewModel` (L31). |
| Toolbar construction | `…/Controllers/CodeEditWindowController+Toolbar.swift` | AppKit `NSToolbar`. `setupToolbar` L13; default items L31–74; allowed items L76–100; `itemForItemIdentifier` switch L120–198. Two layouts: macOS 26 (`.taskSidebarItem` group of stop+start, L178–194) and older (`.stopTaskSidebarItem` / `.startTaskSidebarItem`, L200–226). |
| Toolbar identifiers | `…/Controllers/CodeEditWindowControllerExtensions.swift` L115–125 | `extension NSToolbarItem.Identifier`. |
| Start / Stop buttons | `CodeEdit/Features/Tasks/ToolbarItems/StartTaskToolbarItem.swift` (macOS 26, `startTask()` L33–43), `…/Tasks/Views/StartTaskToolbarButton.swift` (older) | `startTask` calls `taskManager.executeActiveTask()`, opens the utility area and selects `.debugConsole`. |
| **Run action** | `CodeEdit/Features/Tasks/TaskManager.swift` | `executeActiveTask()` L63, `runTask(task:)` L70, `terminateActiveTask()` L90, `selectedTask` L34. `@MainActor`. |
| Run menu / ⌘R / ⌘. | `CodeEdit/Features/WindowCommands/TasksCommands.swift` | `CommandMenu("Tasks")`; "Run \"<task>\"" with `⌘R`. Registered in `CodeEditCommands.swift` L18–22. |
| What a "task" is | `CodeEdit/Features/CEWorkspaceSettings/Models/CETask.swift`, `…/Tasks/Models/CEActiveTask.swift` (`run` L47) | `CETask`: `name, target, workingDirectory, command, environmentVariables`; `fullCommand` = `cd <dir> && <command>`. Executed through a shell in a terminal-backed view; output, status notification and Stop come for free. |
| Per-workspace objects | `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift` | Properties L37–45 (`utilityAreaModel`, `sourceControlManager`, `taskManager`, `workspaceSettingsManager`); created in `initWorkspaceState` (~L131–170; `TaskManager` at ~L160–167); released at ~L194–199. |
| Persistent per-workspace UI state | `…/WorkspaceDocument/WorkspaceStateKey.swift` | `enum WorkspaceStateKey: String`; used via `addToWorkspaceState(key:value:)`. |
| **Sheets** | `CodeEdit/WorkspaceSheets.swift` | A view that is `EmptyView()` carrying `.sheet`/`.alert` modifiers bound to `SourceControlManager` `@Published` flags (`pushSheetIsPresented`, … in `SourceControlManager.swift` L47–73). Mounted at `CodeEdit/WorkspaceView.swift` L122: `.background(WorkspaceSheets().environmentObject(sourceControlManager))`. Triggers: e.g. `SourceControlCommands.swift` L28. |
| **Navigator tabs** | `CodeEdit/Features/NavigatorArea/Models/NavigatorTab.swift` | `enum NavigatorTab` (L12): `project`, `sourceControl`, `search`, `uiExtension`. Exhaustive `switch`es in `systemImage` (L18), `title` (L38), `body` (L51), `bottomView(workspace:)` (L64–79); `id` (L31) falls back to `title`. |
| Tab registration | `CodeEdit/Features/NavigatorArea/Views/NavigatorAreaView.swift` L22–33 | `viewModel.tabItems = [.project, .sourceControl, .search] + extensions…`. |
| Tab selection / shortcuts | `…/NavigatorArea/ViewModels/NavigatorAreaViewModel.swift`, `…/WindowCommands/ViewCommands.swift` L157–171 | `selectedTab`, `tabItems`, `setNavigatorTab(tab:)`. The "Navigators" menu gives `⌘1`…`⌘9` to the first nine `tabItems`, so a new tab gets its shortcut automatically. Programmatic selection example: `CodeEditWindowController.swift` L147–159 (`openSearchNavigator`). |
| Navigator view needing a manager | `…/SourceControlNavigator/Views/SourceControlNavigatorView.swift` L11–20 | Reads `workspace.sourceControlManager` from `@EnvironmentObject workspace` and re-injects it with `.environmentObject(...)`. This is the pattern to copy. |
| Bottom bar of a navigator | `NavigatorTab.bottomView(workspace:)` | e.g. `SourceControlNavigatorToolbarBottom`. |
| Utility area (console panel) | `CodeEdit/Features/UtilityArea/Models/UtilityAreaTab.swift` | `terminal`, `debugConsole`, `output`. |
| Command palette | `…/Controllers/CodeEditWindowControllerExtensions.swift` L13+ (`registerCommands`) | `CommandManager.shared.addCommand(name:title:id:command:)`. |
| Entitlements | `CodeEdit/CodeEdit.entitlements`; `CodeEdit.xcodeproj/project.pbxproj` (`ENABLE_APP_SANDBOX = YES`, among others at L1151/L1424/L1468; `CODE_SIGN_ENTITLEMENTS` L1142/L1415) | See §4.1. |

## 3. Proposed hook points

### 3.1 Principles

1. All new code lives under `CodeEdit/Features/BShell/` plus the `BHumanKit` package. Core files only receive
   one- to five-line hooks, each prefixed with `// b-code hook:` so they are greppable and easy to carry across
   upstream merges.
2. Follow the pattern CodeEdit already uses for source control: a per-workspace `ObservableObject` manager
   created in `WorkspaceDocument`, `@Published` presentation flags, sheets in a dedicated host view.
3. The b-shell UI only appears for workspaces that look like a B-Human checkout
   (`Make/Common/deploy` and `Config/teams.cfg` exist), so ordinary projects are unaffected.
4. Config files stay the source of truth. Robots and presets are read from `Config/Robots/*/network.cfg` and
   `Config/teams.cfg`, so the existing shell tooling and the app agree.

### 3.2 The state holder: `BShellManager`

New file `CodeEdit/Features/BShell/BShellManager.swift`, `@MainActor final class BShellManager: ObservableObject`:

- inputs: `repositoryRoot: URL`, `any RobotStatusProviding`, `DeployService`
- published: `teams: [Team]`, `robots: [Robot]` (roles applied for `selectedTeam`), `statuses: [String: RobotStatus]`,
  `selectedTeamID`, `substitutes: [String]`, `isDeploySheetPresented`, `deployProgress`
- `reload()` reads the config files via `Team.parseTeamsConfig`, `Robot.parseNetworkConfig`,
  `RobotType.parseRobotsConfig`
- `startPolling()` / `stopPolling()`: one `Task` that asks the provider for every robot, roughly every 5 s (the
  dialog's `statusUpdateTime`). Started from the navigator's `.task`, cancelled when the tab disappears, so
  nothing pings the network while b-shell is not visible.

Hook H1 (in `WorkspaceDocument.swift`): one property next to L44, one construction block after the `TaskManager`
block (~L167), and `bShellManager = nil` in the cleanup list (~L199).

### 3.3 Deploy sheet

**Triggers** (all just set `workspace.bShellManager?.isDeploySheetPresented = true`):

| Trigger | Hook |
| --- | --- |
| Toolbar button | H2: add `static let deployItem` to the identifier extension (`…WindowControllerExtensions.swift` L115–125); add `.deployItem` to the default list (after the task items, L36–44) and the allowed list (L76–100) in `…+Toolbar.swift`; add a `case .deployItem:` in the `itemForItemIdentifier` switch (L125–197) returning an `NSToolbarItem` with an SF Symbol and `action` → `toggle`. On macOS 26 it can be a third `subitem` of `.taskSidebarItem` (L192). The item should only be inserted when `workspace.bShellManager != nil`. |
| Menu | H3: new `CodeEdit/Features/WindowCommands/BShellCommands.swift` (copy of the `TasksCommands` structure: `@UpdatingWindowController`, "Deploy…" with e.g. `⇧⌘D`; check the shortcut for collisions) and one line `BShellCommands()` in `CodeEditCommands.swift` next to `TasksCommands()` (L21). |
| Command palette | H4: one `CommandManager.shared.addCommand(...)` in `registerCommands()` (`…WindowControllerExtensions.swift` L13+). |

**Host.** Do not edit `WorkspaceSheets` (it takes only `SourceControlManager`). Add a sibling:

```swift
// CodeEdit/Features/BShell/BShellSheets.swift
struct BShellSheets: View {
    @EnvironmentObject private var workspace: WorkspaceDocument   // already in the environment
    var body: some View {
        if let manager = workspace.bShellManager { BShellSheetsContent(manager: manager) } else { EmptyView() }
    }
}
```

Hook H5 (`WorkspaceView.swift` L122): add `.background(BShellSheets()) // b-code hook` directly after
`.background(WorkspaceSheets()…)`. `BShellSheetsContent` holds `@ObservedObject var manager` and the
`.sheet(isPresented: $manager.isDeploySheetPresented) { DeploySheet(manager: manager) }`. (A wrapper view is
needed because `workspace.bShellManager` is an optional that is not `@Published`.)

**Content of `DeploySheet`** (the analogue of the Deploy Dialog): team picker (`teams`), configuration picker
(`BuildConfiguration.allCases`, default `.develop`), a list of robots with role, wired/wireless ping and battery
from `statuses`, drag or picker for the player number, toggles for compile / delete logs / restart, a "Deploy"
button. "Deploy" builds a `DeployRequest` from the selected `Team` and the robots whose role is
`.playing(playerNumber:)`; `keepRemoteAddress` is set when exactly one robot is selected (as the dialog does).

**Execution, two options.**

- *Option 0, no code:* a `CETask` named "Deploy" whose command is `Make/Common/deploy Develop <ip> -p 1`. Works
  today with the existing Run button; useful as a smoke test of §4.1.
- *Option A (recommended for v1):* `BShellManager` turns `DeployService.compileInvocation` /
  `deployInvocation` into `CETask`s using `CommandInvocation.shellCommandLine` and `workingDirectory`, runs them
  with `taskManager.runTask(task:)` (L70) one after the other, and reads the result from
  `taskManager.activeTasks[id]?.status`. The user gets live output in the debug console, the notification, and
  the existing Stop button. This needs a small `CommandRunner` adapter (`TaskManagerCommandRunner`) because
  `runTask` returns when the task *starts*, not when it ends.
- *Option B:* a `Process`-based `CommandRunner` for headless calls (pings, status queries) where output would be
  noise. It is the right tool for `ShellRobotStatusProvider` and is not part of this PR (see §6).

### 3.4 b-shell navigator tab

| Hook | File | Change |
| --- | --- | --- |
| H6 | `NavigatorTab.swift` | add `case bShell`; the compiler then flags the four exhaustive switches to extend: `systemImage` (e.g. `"antenna.radiowaves.left.and.right"`), `title` (`"b-shell"`; `id` falls back to `title`), `body` → `BShellNavigatorView()`, `bottomView` → `BShellNavigatorToolbarBottom()` (a "Deploy…" button and a refresh button). |
| H7 | `NavigatorAreaView.swift` L22 | `viewModel.tabItems = [.project, .sourceControl, .search] + (workspace.bShellManager != nil ? [.bShell] : []) + extensions…`. `workspace` is available in that `init`. Position 4 gets `⌘4` from `ViewCommands` L163–167 without further work. |
| H8 | `WorkspaceStateKey.swift` | add `bShellSubstitutes` (and optionally `bShellSelectedTeam`); persists the substitutes order like the dialog's `QSettings`. |

`BShellNavigatorView` mirrors `SourceControlNavigatorView`: read `workspace.bShellManager`, re-inject it, show
one row per robot (name, role, wired/wireless ping with `StatusSeverity` colors, battery, log count, service
state), `.task { manager.startPolling() }`. The context menu reproduces the Deploy Dialog's: Login, Show Crash
Log, Download Calibration, Start/Restart, Stop, Shutdown (they call `Make/Common/robotTerminal`,
`downloadCalibration`, and `robotSSH <ip> systemctl --user …`), plus logs (`Make/Common/downloadLogs`).

### 3.5 Hook inventory

| # | File | Size | Purpose |
| --- | --- | --- | --- |
| H1 | `WorkspaceDocument.swift` | ~6 lines | create / release `BShellManager` |
| H2 | `…WindowControllerExtensions.swift`, `…+Toolbar.swift` | ~15 lines | Deploy toolbar item |
| H3 | `CodeEditCommands.swift` (+ new `BShellCommands.swift`) | 1 line | menu |
| H4 | `…WindowControllerExtensions.swift` | ~6 lines | command palette |
| H5 | `WorkspaceView.swift` | 1 line | sheet host |
| H6 | `NavigatorTab.swift` | ~12 lines | new tab |
| H7 | `NavigatorAreaView.swift` | 1–2 lines | register tab |
| H8 | `WorkspaceStateKey.swift` | 1–2 lines | persistence key |
| H9 | `CodeEdit.xcodeproj` | Xcode-generated | local package `Packages/BHumanKit` and new files in the target |

H9: the project only has *remote* package references today (`XCRemoteSwiftPackageReference`, e.g. CodeEditSymbols,
Sparkle). Adding the local package must be done in Xcode (*File ▸ Add Package Dependencies ▸ Add Local…*); I did not
hand-edit `project.pbxproj`. New app files must be added to the CodeEdit target in the same session.

## 4. Risks and open questions

### 4.1 App Sandbox (most important)

`CodeEdit/CodeEdit.entitlements` enables `com.apple.security.app-sandbox` with only user-selected-files
(read/write), app-scoped bookmarks and `network.client`; the build settings carry `ENABLE_APP_SANDBOX = YES`. This
was introduced by upstream commit `78c3be9` ("Fix/deprecations memory leak entitlements (#2147)").

Deploying needs `ssh`, `rsync`, `ping`, `cmake`/`xcodebuild`, and write access to `Build/`. From how App Sandbox
works, I expect these to be blocked or crippled (child processes inherit the sandbox; no access to `~/.ssh`,
Xcode toolchain paths, or outside the opened folder). I **could not test this**. Before building any UI, run
*Option 0* from §3.3 on a Mac with the sandbox on. If it fails, b-code needs a decision that is not mine to make
here: drop the sandbox for b-code (as Xcode itself is not sandboxed; this changes a core file and signing),
or add targeted temporary-exception entitlements, or move process execution into a helper outside the sandbox.

### 4.2 Other points

- **bush/NAO vs Deploy Dialog/Booster** (§1): confirm which release the team actually deploys.
- **Qt Deploy Dialog stays authoritative for the CLI contract.** If B-Human changes `deploy`'s flags in a new
  release, `DeployService.deployArguments` must follow; its tests pin the current order.
- **Build requirements.** `Make/macOS/compile` runs `Make/macOS/generate` (CMake → Xcode project) before
  `xcodebuild`; compiling needs the toolchain the Code Release's own docs ask for. Not checked here.
- **Concurrency.** `TaskManager` is `@MainActor`; `BShellManager` should be too. `BHumanKit` types are `Sendable`
  value types and the protocols are `Sendable`, so they can cross to a background polling task.
- **Two toolbar code paths** (macOS 26 vs earlier) must both get the Deploy item (H2).
- **Polling cost.** Each cycle is two pings plus one SSH round-trip per reachable robot; SSH key handling is whatever
  `Make/Common/robotSSH`/`setupSSH` do (`Install/Keys`). Keep polling tied to the tab being visible.

## 5. Suggested order of work

1. Verify the sandbox question (§4.1) with Option 0, and verify `BHumanKit` builds and its tests pass on macOS and
   Linux (see §6).
2. H9, H1, H6, H7: package linked, `BShellManager.reload()`, a static roster in the new tab.
3. `ShellRobotStatusProvider` behind a `Process`-based runner: live status in the tab.
4. H5 + `DeploySheet` with Option A execution; H2/H3 triggers.
5. Context-menu actions, logs download, substitutes persistence (H8).

## 6. `BHumanKit` status

Location: `Packages/BHumanKit` (Swift tools 5.9, macOS 14+, Foundation only, XCTest).

| Area | Types | Tests |
| --- | --- | --- |
| Models | `BuildConfiguration`, `Robot`, `RobotType`, `RobotRole`, `Team` (+ role assignment) | `BuildConfigurationTests`, `ConfigDecodingTests` |
| Config parsing | `ConfigParser`, `ConfigValue`, `BHumanSettings`, `Team.parseTeamsConfig`, `Robot.parseNetworkConfig`, `RobotType.parseRobotsConfig` | `ConfigParserTests`, `BHumanSettingsTests`, `ConfigDecodingTests` |
| Deploy | `CommandRunner`, `CommandInvocation` (+ `shellCommandLine`), `DeployService`, `DeployRequest`, `DeployError` | `DeployServiceTests` (fake runner) |
| Status | `RobotStatus`, `PingResult`, `StatusSeverity`, `RobotStatusParser`, `RobotStatusProviding`, `MockRobotStatusProvider`, `ShellRobotStatusProvider` | `RobotStatusTests` (fake runner) |

**Verification state: not compiled, not executed.** The authoring environment has no Swift toolchain (`apt` has
none, `download.swift.org` is denied by the egress policy), and an attempt to unpack one from the official Docker
image was stopped by the session's permission classifier, so I did not run it. What was done instead: a tree-sitter Swift grammar parsed
all 19 `.swift` files without syntax errors, and the code was reviewed by hand for type errors. That catches
syntax mistakes only. Expect some compile errors on the first real build, most likely in the tests'
generic/closure-heavy spots (`FakeCommandRunner` trailing closures, `any RobotStatusProviding` existential).

Not implemented on purpose: a real `Process`-based `CommandRunner`, writing `teams.cfg`, parsing `deploy`'s
`[<ip>]` output per robot, log download, any UI, any CodeEdit change.

To verify on a Mac or Linux box with Swift 5.9+:

```bash
cd Packages/BHumanKit
swift build
swift test
```
