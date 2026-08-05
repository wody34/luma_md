import AppKit
import SwiftUI
@preconcurrency import WebKit

public struct ReaderScrollTarget: Equatable, Sendable {
    public let headingID: String
    public let requestID: UUID

    public init(headingID: String, requestID: UUID = UUID()) {
        self.headingID = headingID
        self.requestID = requestID
    }
}

public struct ReaderWebView: NSViewRepresentable {
    public let html: String
    public let scrollTarget: ReaderScrollTarget?
    public let onExternalURL: (URL) -> Void

    public init(
        html: String,
        scrollTarget: ReaderScrollTarget?,
        onExternalURL: @escaping (URL) -> Void
    ) {
        self.html = html
        self.scrollTarget = scrollTarget
        self.onExternalURL = onExternalURL
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onExternalURL: onExternalURL)
    }

    public func makeNSView(context: Context) -> WKWebView {
        NativeQACapture.log("webview=make")
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = true
        context.coordinator.webView = webView
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onExternalURL = onExternalURL
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            context.coordinator.pendingScrollTarget = scrollTarget
            let navigation = webView.loadHTMLString(html, baseURL: nil)
            NativeQACapture.log(
                "webview=load-html bytes=\(html.utf8.count) navigation=\(navigation == nil ? "nil" : "created")"
            )
            return
        }

        guard context.coordinator.lastScrollTarget != scrollTarget else {
            return
        }
        context.coordinator.scroll(to: scrollTarget)
    }

    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate {
        static let documentURL = URL(string: "about:blank")!

        weak var webView: WKWebView?
        var loadedHTML: String?
        var lastScrollTarget: ReaderScrollTarget?
        var pendingScrollTarget: ReaderScrollTarget?
        var onExternalURL: (URL) -> Void

        init(onExternalURL: @escaping (URL) -> Void) {
            self.onExternalURL = onExternalURL
        }

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            let decision = WebNavigationPolicy(documentURL: Self.documentURL).decision(
                for: url,
                isMainFrame: navigationAction.targetFrame?.isMainFrame
            )
            switch decision {
            case .allow:
                NativeQACapture.log(
                    "navigation scheme=\(url.scheme ?? "none") decision=allow"
                )
                decisionHandler(.allow)
            case let .openExternal(url):
                NativeQACapture.log(
                    "navigation scheme=\(url.scheme ?? "none") decision=open-external"
                )
                onExternalURL(url)
                decisionHandler(.cancel)
            case .cancel:
                NativeQACapture.log(
                    "navigation scheme=\(url.scheme ?? "none") decision=cancel"
                )
                decisionHandler(.cancel)
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let target = pendingScrollTarget
            pendingScrollTarget = nil
            DispatchQueue.main.async {
                self.scroll(to: target)
            }
            NativeQACapture.log("webview=did-finish")
            NativeQACapture.captureWebView(webView, named: "reader-web")
            NativeQACapture.captureWindow(named: "reader-ready")
            copyRenderedSelectionIfRequested(in: webView)
            auditDocumentIfRequested(in: webView)
            activateSafeLinkIfRequested(in: webView)
            NativeQACapture.captureBottomIfRequested(webView)
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            NativeQACapture.log("webview=did-start url=\(webView.url?.absoluteString ?? "nil")")
        }

        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            NativeQACapture.log("webview=did-commit url=\(webView.url?.absoluteString ?? "nil")")
        }

        public func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            NativeQACapture.log(
                "webview=did-fail-provisional code=\((error as NSError).code) detail=\(error.localizedDescription)"
            )
        }

        public func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            NativeQACapture.log(
                "webview=did-fail code=\((error as NSError).code) detail=\(error.localizedDescription)"
            )
        }

        public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            NativeQACapture.log("webview=process-terminated")
        }

        func scroll(to target: ReaderScrollTarget?) {
            lastScrollTarget = target
            guard let target, !target.headingID.isEmpty, let webView else {
                return
            }
            guard let data = try? JSONEncoder().encode(target.headingID),
                  let literal = String(data: data, encoding: .utf8)
            else {
                return
            }
            let source = """
            (() => {
              const heading = document.getElementById(\(literal));
              if (!heading) return {found:false};
              const root = document.scrollingElement || document.documentElement;
              const targetY = heading.getBoundingClientRect().top + root.scrollTop;
              const priorBehavior = root.style.scrollBehavior;
              root.style.scrollBehavior = "auto";
              heading.scrollIntoView({block:"start"});
              const result = {
                found:true,
                targetY:targetY,
                scrollY:root.scrollTop,
                top:heading.getBoundingClientRect().top
              };
              root.style.scrollBehavior = priorBehavior;
              return result;
            })();
            """
            webView.evaluateJavaScript(source) { result, error in
                if let error {
                    NativeQACapture.log(
                        "outline-scroll id=\(target.headingID) result=error detail=\(error.localizedDescription)"
                    )
                    return
                }
                guard let values = result as? [String: Any],
                      values["found"] as? Bool == true else {
                    NativeQACapture.log(
                        "outline-scroll id=\(target.headingID) result=missing dom=\(String(describing: result))"
                    )
                    return
                }
                NativeQACapture.log(
                    "outline-scroll id=\(target.headingID) result=PASS dom=\(values)"
                )
                NativeQACapture.captureWebView(webView, named: "outline-scroll")
            }
        }

        private func copyRenderedSelectionIfRequested(in webView: WKWebView) {
            guard QAEnvironment[.renderedSelect] == "1"
            else {
                return
            }
            let source = """
            (() => {
              const article = document.querySelector(".reader-surface");
              if (!article) return null;
              const range = document.createRange();
              range.selectNodeContents(article);
              const selection = window.getSelection();
              selection.removeAllRanges();
              selection.addRange(range);
              return selection.toString();
            })();
            """
            webView.evaluateJavaScript(source) { result, error in
                guard error == nil, let selectedText = result as? String else {
                    NativeQACapture.log(
                        "rendered-selection result=error detail=\(error?.localizedDescription ?? "missing text")"
                    )
                    return
                }
                DispatchQueue.main.async {
                    if #available(macOS 14.0, *) {
                        NSApp.activate()
                    } else {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    webView.window?.makeKeyAndOrderFront(nil)
                    webView.window?.makeFirstResponder(webView)
                    DispatchQueue.main.async {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            "LUMA_MD_QA_COPY_SENTINEL",
                            forType: .string
                        )
                        let event = NSEvent.keyEvent(
                            with: .keyDown,
                            location: .zero,
                            modifierFlags: .command,
                            timestamp: ProcessInfo.processInfo.systemUptime,
                            windowNumber: webView.window?.windowNumber ?? 0,
                            context: nil,
                            characters: "c",
                            charactersIgnoringModifiers: "c",
                            isARepeat: false,
                            keyCode: 8
                        )
                        let delivered = event.map(webView.performKeyEquivalent(with:)) ?? false
                        let copiedText = NSPasteboard.general.string(forType: .string) ?? ""
                        let selectedEncoded = Data(selectedText.utf8).base64EncodedString()
                        let copiedEncoded = Data(copiedText.utf8).base64EncodedString()
                        NativeQACapture.log(
                            "rendered-selection result=\(selectedText.isEmpty ? "EMPTY" : "PASS") selectedBytes=\(selectedText.utf8.count) selectedBase64=\(selectedEncoded) nativeCopyAction=\(delivered) copiedBytes=\(copiedText.utf8.count) copiedBase64=\(copiedEncoded) copiedSelection=\(copiedText == selectedText)"
                        )
                        NativeQACapture.captureWebView(webView, named: "rendered-selection")
                    }
                }
            }
        }

        private func auditDocumentIfRequested(in webView: WKWebView) {
            guard QAEnvironment[.webAudit] == "1"
            else {
                return
            }
            let source = """
            (() => {
              const reader = document.querySelector(".reader-surface");
              const styles = Array.from(document.styleSheets).flatMap(sheet => {
                try { return Array.from(sheet.cssRules).map(rule => rule.cssText); }
                catch (_) { return []; }
              }).join("\\n");
              const nestedVertical = Array.from(document.querySelectorAll("*")).filter(node => {
                if (node === document.documentElement || node === document.body) return false;
                const style = getComputedStyle(node);
                return /(auto|scroll)/.test(style.overflowY)
                  && node.scrollHeight > node.clientHeight + 1;
              }).length;
              const anchors = Array.from(document.querySelectorAll("a[href]"));
              const forbidden = anchors.filter(anchor =>
                /^(javascript|data|file):/i.test(anchor.getAttribute("href") || "")
              ).length;
              const resources = performance.getEntriesByType("resource").map(entry => entry.name);
              const csp = document.querySelector('meta[http-equiv="Content-Security-Policy"]')
                ?.getAttribute("content") || "";
              const root = document.scrollingElement || document.documentElement;
              const mathElements = Array.from(document.querySelectorAll("math"));
              const mathBlock = document.querySelector(".math-block");
              return {
                csp: csp,
                documentScrollable: root.scrollHeight > root.clientHeight,
                mathElementCount: mathElements.length,
                mathNamespaceCount: mathElements.filter(node =>
                  node.namespaceURI === "http://www.w3.org/1998/Math/MathML"
                ).length,
                mathVisibleCount: mathElements.filter(node => {
                  const bounds = node.getBoundingClientRect();
                  return bounds.width > 0 && bounds.height > 0;
                }).length,
                fractionCount: document.querySelectorAll("mfrac").length,
                indexedRootCount: document.querySelectorAll("mroot").length,
                squareRootCount: document.querySelectorAll("msqrt").length,
                limitCount: document.querySelectorAll("munderover,munder").length,
                matrixCount: document.querySelectorAll("mtable").length,
                fenceCount: document.querySelectorAll('mo[fence="true"]').length,
                accentCount: document.querySelectorAll('mover[accent="true"]').length,
                styleCount: document.querySelectorAll("mstyle[mathvariant]").length,
                forbiddenAnchors: forbidden,
                focusableCount: document.querySelectorAll(
                  'a[href],button,input,select,textarea,[tabindex]:not([tabindex="-1"])'
                ).length,
                headingCount: document.querySelectorAll(
                  ".reader-surface h1,.reader-surface h2,.reader-surface h3,.reader-surface h4,.reader-surface h5,.reader-surface h6"
                ).length,
                mathBlockCount: document.querySelectorAll(".math-block").length,
                mathBlockDisplay: mathBlock ? getComputedStyle(mathBlock).display : "",
                mathInlineCount: document.querySelectorAll(".math-inline").length,
                nestedVerticalScrollers: nestedVertical,
                readerWidth: reader ? reader.getBoundingClientRect().width : 0,
                reducedMotionRule: styles.includes("prefers-reduced-motion"),
                remoteResourceCount: resources.length,
                safeExternalAnchors: anchors.filter(anchor =>
                  /^(https?|mailto):/i.test(anchor.href)
                ).length,
                scriptElementCount: document.querySelectorAll("script").length,
                unsafeLinkCount: document.querySelectorAll(".unsafe-link").length
                ,viewportWidth: document.documentElement.clientWidth
              };
            })();
            """
            webView.evaluateJavaScript(source) { result, error in
                guard error == nil, let values = result as? [String: Any] else {
                    NativeQACapture.log(
                        "web-audit result=error detail=\(error?.localizedDescription ?? "missing result")"
                    )
                    return
                }
                let csp = values["csp"] as? String ?? ""
                let nested = values["nestedVerticalScrollers"] as? Int ?? -1
                let forbidden = values["forbiddenAnchors"] as? Int ?? -1
                let resources = values["remoteResourceCount"] as? Int ?? -1
                let scripts = values["scriptElementCount"] as? Int ?? -1
                let readerWidth = values["readerWidth"] as? Double ?? .infinity
                let viewportWidth = values["viewportWidth"] as? Double ?? 0
                let readerWidthLimit: Double
                if viewportWidth >= 1_600 {
                    readerWidthLimit = 1_089
                } else if viewportWidth >= 1_200 {
                    readerWidthLimit = 961
                } else {
                    readerWidthLimit = 721
                }
                let expandedReaderPassed = viewportWidth < 1_200
                    || readerWidth >= readerWidthLimit - 2
                let reducedMotion = values["reducedMotionRule"] as? Bool ?? false
                let mathCount = (values["mathInlineCount"] as? Int ?? 0)
                    + (values["mathBlockCount"] as? Int ?? 0)
                let mathElementCount = values["mathElementCount"] as? Int ?? 0
                let blockMathPassed = (values["mathBlockCount"] as? Int ?? 0) == 0
                    || (values["mathBlockDisplay"] as? String) == "flex"
                let semanticMathPassed = mathCount == 0
                    || (
                        mathElementCount == mathCount
                        && (values["mathNamespaceCount"] as? Int) == mathElementCount
                        && (values["mathVisibleCount"] as? Int) == mathElementCount
                        && blockMathPassed
                    )
                let requiresAdvancedMath =
                    QAEnvironment[.advancedMathML] == "1"
                let advancedMathPassed = !requiresAdvancedMath
                    || (
                        (values["fractionCount"] as? Int ?? 0) > 0
                        && (values["indexedRootCount"] as? Int ?? 0) > 0
                        && (values["squareRootCount"] as? Int ?? 0) > 0
                        && (values["limitCount"] as? Int ?? 0) >= 3
                        && (values["matrixCount"] as? Int ?? 0) >= 3
                        && (values["fenceCount"] as? Int ?? 0) > 0
                        && (values["accentCount"] as? Int ?? 0) >= 3
                        && (values["styleCount"] as? Int ?? 0) >= 2
                    )
                let mathPassed = semanticMathPassed && advancedMathPassed
                let passed = csp.contains("connect-src 'none'")
                    && csp.contains("img-src 'none'")
                    && nested == 0
                    && forbidden == 0
                    && resources == 0
                    && scripts == 0
                    && readerWidth <= readerWidthLimit
                    && expandedReaderPassed
                    && reducedMotion
                    && mathPassed
                NativeQACapture.log(
                    "web-audit result=\(passed ? "PASS" : "FAIL") dom=\(values)"
                )
            }
        }

        private func activateSafeLinkIfRequested(in webView: WKWebView) {
            guard QAEnvironment[.activateSafeLink] == "1"
            else {
                return
            }
            let source = """
            (() => {
              const anchor = Array.from(document.querySelectorAll("a[href]"))
                .find(node => /^https:\\/\\//i.test(node.href));
              if (!anchor) return {found:false};
              const href = anchor.href;
              anchor.click();
              return {found:true, href:href};
            })();
            """
            webView.evaluateJavaScript(source) { result, error in
                guard error == nil,
                      let values = result as? [String: Any],
                      values["found"] as? Bool == true
                else {
                    NativeQACapture.log(
                        "safe-link-activation result=missing detail=\(error?.localizedDescription ?? String(describing: result))"
                    )
                    return
                }
                NativeQACapture.log(
                    "safe-link-activation result=PASS href=\(values["href"] ?? "")"
                )
            }
        }
    }
}
