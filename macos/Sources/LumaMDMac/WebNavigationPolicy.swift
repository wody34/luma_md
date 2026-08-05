import Foundation

public struct WebNavigationPolicy {
    public enum Decision: Equatable {
        case allow
        case openExternal(URL)
        case cancel
    }

    private let documentURL: URL

    public init(documentURL: URL) {
        self.documentURL = documentURL
    }

    public func decision(for url: URL, isMainFrame: Bool?) -> Decision {
        guard isMainFrame != false else {
            return .cancel
        }

        if isSameDocumentFragment(url) {
            return .allow
        }

        switch url.scheme?.lowercased() {
        case "http", "https", "mailto":
            guard !sharesDocumentOrigin(with: url) else {
                return .cancel
            }
            return .openExternal(url)
        default:
            return .cancel
        }
    }

    private func isSameDocumentFragment(_ url: URL) -> Bool {
        guard url.fragment != nil else {
            return false
        }

        return withoutFragment(url) == withoutFragment(documentURL)
    }

    private func sharesDocumentOrigin(with url: URL) -> Bool {
        guard
            let destination = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let document = URLComponents(url: documentURL, resolvingAgainstBaseURL: true)
        else {
            return false
        }

        return destination.scheme?.lowercased() == document.scheme?.lowercased()
            && destination.host?.lowercased() == document.host?.lowercased()
            && destination.port == document.port
    }

    private func withoutFragment(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        components.fragment = nil
        return components.url
    }
}
