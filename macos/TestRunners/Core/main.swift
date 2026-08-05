import LumaMDCoreTests

do {
    try CoreContractRunner.run()
} catch {
    fatalError("LumaMDCoreTests failed: \(error)")
}
