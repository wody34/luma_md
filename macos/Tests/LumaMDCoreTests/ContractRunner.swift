import XCTest

public enum CoreContractRunner {
    public static func run() throws {
        try run(MarkdownRendererTests()) { test in
            test.testRetainsOriginalSourceDerivesTitleAndBuildsUniqueOutlineSlugs()
            test.testUsesCleanedFallbackTitleWhenDocumentHasNoH1()
            test.testRendersParagraphEmphasisAndSafeLinksWhileEscapingNoteAuthoredHTML()
            test.testPreservesFormulaLikeUnderscoresWithoutBreakingDelimitedEmphasis()
            test.testParsesSoftWrappedInlineMathBeforeJoiningParagraphProse()
            test.testKeepsMarkdownLookingLinesInsideOpenInlineMath()
            test.testRendersLearningPaperNotationCommandsWithoutTextFallback()
            test.testFallsBackWhenMathExceedsDepthOrNodeBudgets()
            test.testAlignsUnbracedArgumentsAndNamedOperatorsAcrossEditions()
            test.testRendersListsTasksTablesQuotesAndRulesSemantically()
            test.testLabelsAndHighlightsRecognizedFencedCodeAndEscapesUnknownCode()
            test.testRendersAccessibleInlineAndBlockMathWithoutNetworkDependencies()
            try test.testRendersAdvancedTeXSubsetAsSemanticMathML()
            test.testPreservesMalformedMathSourceWithoutExecutableMarkup()
            test.testBuildsFootnotesWithRepeatedReferencesAndBacklinks()
            test.testHandlesNilEmptyAndMalformedInputWithoutEmittingExecutableMarkup()
            try test.testReleaseNotesFixtureCoversTheCoreReadingPrimitives()
            try test.testFormulaCodeFixtureCoversMathHighlightingAndUnicodeText()
            try test.testDenseFootnotesFixtureUsesStableDuplicateSlugsAndFootnoteNavigation()
            try test.testEmptyFixtureRemainsAnExactEmptyDocument()
        }
        try run(ReaderHTMLBuilderTests()) { test in
            test.testBuildsACompleteDocumentWithEscapedMetadataAndSemanticReaderSurface()
            test.testEmitsBothThemeTokenSetsAndAllSupportedTypeScales()
            test.testAdaptsReaderMeasureAcrossViewportWidthsAndRestrictsSelectionToDocumentContent()
            test.testCSPAndRenderedMarkupForbidScriptsAndRemoteSubresources()
            test.testSafeExternalLinksPreserveNavigationMarkupWithoutOpeningUnsafeSchemes()
            test.testStylesFractionsRadicalsAndMathBlocksAsReadableLayout()
        }
        try run(DocumentLoaderTests()) { test in
            try test.testExactlyFiveMiBLoadsSuccessfully()
            try test.testFiveMiBPlusOneByteThrowsTypedTooLargeError()
            try test.testOversizedMetadataWinsBeforeUnreadableContent()
            try test.testMalformedUTF8UsesDeterministicReplacementCharacters()
            try test.testFilenameAndOriginalByteSizeAreRetained()
            try test.testUnreadableURLThrowsTypedUnreadableError()
        }
        try run(ReaderPreferencesTests()) { test in
            test.testMissingValuesNormalizeToSystemAndStandardScale()
            test.testEveryThemeChoicePersistsAcrossInstances()
            test.testEverySupportedTypeScalePersistsAcrossInstances()
            test.testUnsupportedPersistedValuesNormalizeWithoutLeakingInvalidState()
        }
        try run(RecentDocumentStoreTests()) { test in
            try test.testStorePersistsEncodedBookmarkAndResolveUsesIt()
            try test.testFreshResolutionDoesNotRewriteBookmark()
            try test.testStaleResolutionRefreshesPersistedBookmarkUsingResolvedURL()
            try test.testClearRemovesRecentWithoutInvokingCodec()
            try test.testBookmarkPresenceCheckDoesNotResolveStoredBookmark()
        }
        print("LumaMDCoreTests: 41 contracts passed")
    }

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
