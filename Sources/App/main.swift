import AppKit

let cliArgs = Array(CommandLine.arguments.dropFirst())
if CLI.wantsHelp(cliArgs) {
    let text = L.t("cli.help") + "\n"
    FileHandle.standardOutput.write(Data(text.utf8))
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.delegate = AppDelegate.shared
withExtendedLifetime(AppDelegate.shared) {
    app.run()
}
