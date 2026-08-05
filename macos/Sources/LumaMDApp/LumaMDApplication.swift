import LumaMDMac
import SwiftUI

@main
struct LumaMDApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let preferences = CorePreferencesAdapter()
        let recentDocuments = CoreRecentDocuments()
        _model = StateObject(
            wrappedValue: AppModel(
                loader: CoreNoteLoader(),
                recentDocuments: recentDocuments,
                preferences: preferences,
                nativeServices: NativeServices()
            )
        )
    }

    var body: some Scene {
        Window("Luma MD", id: "main") {
            ContentView(model: model)
                .frame(
                    idealWidth: DesignTokens.windowDefault.width,
                    idealHeight: DesignTokens.windowDefault.height
                )
                .onAppear {
                    appDelegate.openRequestBroker.installHandler(model.open(urls:))
                }
        }
        .defaultSize(
            width: DesignTokens.windowDefault.width,
            height: DesignTokens.windowDefault.height
        )
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            LumaCommands(model: model)
        }
    }
}

private struct LumaCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…", action: model.openDocument)
                .keyboardShortcut("o", modifiers: .command)

            Menu("Open Recent") {
                Button("Continue Reading", action: model.openRecent)
                    .disabled(!model.hasRecentDocument)
                Divider()
                Button("Clear Menu", action: model.clearRecent)
                    .disabled(!model.hasRecentDocument)
            }

            Divider()
            Button("Home", action: model.goHome)
                .keyboardShortcut("1", modifiers: .command)
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Markdown", action: model.copyMarkdown)
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Button("Share Markdown…", action: model.shareMarkdown)
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Create Clipboard Memo", action: model.createClipboardMemo)
                .keyboardShortcut("v", modifiers: [.command, .shift])
        }

        CommandMenu("Appearance") {
            Button("System") {
                model.setTheme(.system)
            }
            Button("Light") {
                model.setTheme(.light)
            }
            Button("Dark") {
                model.setTheme(.dark)
            }
        }

        CommandMenu("Reading") {
            Button("Small Text") {
                model.setTypeScale(.small)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Default Text") {
                model.setTypeScale(.standard)
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("Large Text") {
                model.setTypeScale(.large)
            }
            .keyboardShortcut("=", modifiers: .command)
        }
    }
}
