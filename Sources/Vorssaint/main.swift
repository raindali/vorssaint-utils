// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

// Select backup mode before cleanup and diagnostic arguments can act. Invalid
// backup commands must leave files, input mappings and recovery journals alone.
if let command = SettingsBackupSupport.command(in: CommandLine.arguments) {
    SettingsBackup.runCommandAndExit(command)
}

SuperKeyMappingGuard.runIfRequestedAndExit()
Defaults.register()
let configuredFeatureKeys = SettingsBackup.applyConfigFileAtLaunch()
NotchControlItem.keyboardLightIsSupported = { BrightnessService.keyboardLightIsSupported }
MouseAccelerationGuard.runIfRequestedAndExit()
MouseAccelerationService.recoverPendingAtLaunch()

if CommandLine.arguments.contains("--selftest") {
    SelfTest.runAndExit()
}
if CommandLine.arguments.contains("--sensors") {
    SensorDump.runAndExit()
}
if CommandLine.arguments.contains("--capture-test") {
    Task {
        let result = await MacOS13Diagnostics.captureMainDisplay()
        print(result)
        exit(result.hasPrefix("capture ") ? 0 : 1)
    }
    RunLoop.main.run()
}
if CommandLine.arguments.contains("--clipboard-test") {
    FeatureRuntime.shared.syncAtLaunch()
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString("vorssaint-clipboard-test", forType: .string)
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        let path = PrivateFileStore.containerURL?
            .appendingPathComponent("ClipboardHistory.json").path ?? "-"
        print("clipboard running=\(ClipboardHistoryService.shared.isRunning) "
              + "entries=\(ClipboardHistoryService.shared.entries.count) "
              + "store=\(path) exists=\(FileManager.default.fileExists(atPath: path))")
        exit(0)
    }
    RunLoop.main.run()
}
if CommandLine.arguments.contains("--uninstall") {
    Uninstaller.runAndExit()
}

#if VORSSAINT_DEVELOPMENT
// A probe mode on its own would otherwise launch the whole app, and TCC kills
// that from a shell whose host app lacks a Bluetooth usage description. The
// commands above come first, so `--selftest` beside a probe mode runs the
// selftest, not the probe.
if NotchPresentationProbe.isRequested(by: CommandLine.arguments) {
    NotchPresentationProbe.runAndExit()
}
#endif

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.configuredFeatureKeys = configuredFeatureKeys
app.delegate = delegate
app.run()
