import XCTest

public enum MacContractRunner {
    @MainActor
    public static func run() throws {
        try run(AppModelTests()) { test in
            test.testStartsOnWelcomeWithPersistedPreferencesAndRecentAvailability()
            test.testOpenActionUsesNativePickerAndCancelPreservesCurrentState()
            test.testOpenURLsUsesOnlyFirstSupportedURLAndRemembersItAfterSuccess()
            test.testOpenFailureIsRecoverableAndDoesNotReplaceRecentDocument()
            test.testBookmarkPersistenceFailureDoesNotDiscardLoadedDocument()
            test.testHomeKeepsRecentAndContinueReadingReopensIt()
            test.testUnusableRecentIsClearedAndProducesRecoveryState()
            test.testThemeAndTypeCommandsPersistExactChoicesAndCycleAllScales()
            try test.testClipboardMemoRetainsExactSourceAndNeverChangesRecent()
            test.testCopyAndShareUseCurrentOriginalMarkdownWithoutChangingReaderState()
        }
        try run(OpenRequestBrokerTests()) { test in
            test.testEventsReceivedBeforeHandlerInstallationAreBufferedAndDeliveredExactlyOnce()
            test.testInstallingHandlerBeforeAnyEventRoutesEachEventDirectlyWithoutReplay()
        }
        try run(WebNavigationPolicyTests()) { test in
            test.testSameDocumentFragmentsStayInsideWebView()
            test.testHTTPHTTPSAndMailtoMainFrameLinksOpenExternally()
            test.testSafeLinkOpeningANewWindowUsesNativeExternalHandler()
            test.testUnsafeSchemesAreAlwaysBlocked()
            test.testCrossDocumentLocalNavigationAndSubframesAreBlocked()
        }
        try run(NativeServicesTests()) { test in
            try test.testClipboardReadAndCopyPreserveExactOriginalSource()
            try test.testShareSanitizesFilenameWritesExactSourceAndCleansUpOnCompletion()
            try test.testCleanupRemovesOnlyDedicatedShareDirectory()
        }
        try run(BundleContractTests()) { test in
            try test.testInfoPlistRegistersAllDocumentTypesAndMacOS13Minimum()
            try test.testEntitlementsAreExactReadOnlyLocalSandboxContract()
        }
        try run(WindowPresentationTests()) { test in
            test.testAdaptiveBorderlessPresentationKeepsNativeWindowCapabilities()
        }
        try run(ReaderDockViewTests()) { test in
            test.testPrimaryReaderDockExposesDedicatedOutlineButton()
        }
        print("LumaMDMacTests: 24 contracts passed")
    }

    @MainActor
    private static func run<T: XCTestCase>(
        _ test: T,
        body: (T) throws -> Void
    ) throws {
        try test.setUpWithError()
        do {
            try body(test)
            try test.runTeardownBlocks()
            try test.tearDownWithError()
        } catch {
            try? test.runTeardownBlocks()
            try? test.tearDownWithError()
            throw error
        }
    }
}
