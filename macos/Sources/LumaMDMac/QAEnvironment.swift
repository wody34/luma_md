import Foundation

enum QAEnvironmentKey {
    case share
    case cancelShare
    case outlineID
    case showActions
    case interceptExternal
    case theme
    case typeScale
    case copyMarkdown
    case forceUnreadable
    case forceBookmarkFailure
    case captureChrome
    case clearRecent
    case clipboardMemo
    case openRecent
    case renderedSelect
    case webAudit
    case advancedMathML
    case activateSafeLink
}

enum QAEnvironment {
    static subscript(key: QAEnvironmentKey) -> String? {
        #if LUMA_MD_QA
        let name: String
        switch key {
        case .share: name = "LUMA_MD_QA_SHARE"
        case .cancelShare: name = "LUMA_MD_QA_CANCEL_SHARE"
        case .outlineID: name = "LUMA_MD_QA_OUTLINE_ID"
        case .showActions: name = "LUMA_MD_QA_SHOW_ACTIONS"
        case .interceptExternal: name = "LUMA_MD_QA_INTERCEPT_EXTERNAL"
        case .theme: name = "LUMA_MD_QA_THEME"
        case .typeScale: name = "LUMA_MD_QA_TYPE_SCALE"
        case .copyMarkdown: name = "LUMA_MD_QA_COPY_MARKDOWN"
        case .forceUnreadable: name = "LUMA_MD_QA_FORCE_UNREADABLE"
        case .forceBookmarkFailure: name = "LUMA_MD_QA_FORCE_BOOKMARK_FAILURE"
        case .captureChrome: name = "LUMA_MD_QA_CAPTURE_CHROME"
        case .clearRecent: name = "LUMA_MD_QA_CLEAR_RECENT"
        case .clipboardMemo: name = "LUMA_MD_QA_CLIPBOARD_MEMO"
        case .openRecent: name = "LUMA_MD_QA_OPEN_RECENT"
        case .renderedSelect: name = "LUMA_MD_QA_RENDERED_SELECT"
        case .webAudit: name = "LUMA_MD_QA_WEB_AUDIT"
        case .advancedMathML: name = "LUMA_MD_QA_MATHML_ADVANCED"
        case .activateSafeLink: name = "LUMA_MD_QA_ACTIVATE_SAFE_LINK"
        }
        return ProcessInfo.processInfo.environment[name]
        #else
        return nil
        #endif
    }
}
