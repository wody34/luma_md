import LumaMDMacTests

do {
    try await MainActor.run {
        try MacContractRunner.run()
    }
} catch {
    fatalError("LumaMDMacTests failed: \(error)")
}
