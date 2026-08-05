import Foundation

@MainActor
public final class OpenRequestBroker {
    public typealias Handler = ([URL]) -> Void

    private var handler: Handler?
    private var pendingBatches: [[URL]] = []
    private var deliveringPendingBatches = false

    public init() {}

    public func receive(_ urls: [URL]) {
        guard let handler, !deliveringPendingBatches else {
            pendingBatches.append(urls)
            return
        }

        handler(urls)
    }

    public func installHandler(_ handler: @escaping Handler) {
        self.handler = handler
        deliveringPendingBatches = true

        while !pendingBatches.isEmpty {
            let batch = pendingBatches.removeFirst()
            handler(batch)
        }

        deliveringPendingBatches = false
    }
}
