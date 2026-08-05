import Foundation

open class XCTestCase: NSObject {
    private var teardownBlocks: [() throws -> Void] = []

    public required override init() {
        super.init()
    }

    open func setUpWithError() throws {}

    open func tearDownWithError() throws {}

    public func addTeardownBlock(_ block: @escaping () throws -> Void) {
        teardownBlocks.append(block)
    }

    public func runTeardownBlocks() throws {
        for block in teardownBlocks.reversed() {
            try block()
        }
        teardownBlocks.removeAll()
    }
}

public func XCTAssertTrue(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    evaluate(expression, expected: true, message: message(), file: file, line: line)
}

public func XCTAssertFalse(
    _ expression: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    evaluate(expression, expected: false, message: message(), file: file, line: line)
}

public func XCTAssertEqual<T: Equatable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let first = try expression1()
        let second = try expression2()
        if first != second {
            fail(
                "XCTAssertEqual failed: \(String(describing: first)) is not equal to "
                    + "\(String(describing: second)). \(message())",
                file: file,
                line: line
            )
        }
    } catch {
        fail("XCTAssertEqual threw \(error). \(message())", file: file, line: line)
    }
}

public func XCTAssertEqual<T: FloatingPoint>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    accuracy: T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let first = try expression1()
        let second = try expression2()
        if abs(first - second) > accuracy {
            fail(
                "XCTAssertEqual failed: \(first) differs from \(second) by more than "
                    + "\(accuracy). \(message())",
                file: file,
                line: line
            )
        }
    } catch {
        fail("XCTAssertEqual threw \(error). \(message())", file: file, line: line)
    }
}

public func XCTAssertNil<T>(
    _ expression: @autoclosure () throws -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        if let value = try expression() {
            fail(
                "XCTAssertNil failed: \(String(describing: value)). \(message())",
                file: file,
                line: line
            )
        }
    } catch {
        fail("XCTAssertNil threw \(error). \(message())", file: file, line: line)
    }
}

public func XCTAssertNotNil<T>(
    _ expression: @autoclosure () throws -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        if try expression() == nil {
            fail("XCTAssertNotNil failed. \(message())", file: file, line: line)
        }
    } catch {
        fail("XCTAssertNotNil threw \(error). \(message())", file: file, line: line)
    }
}

public func XCTAssertGreaterThan<T: Comparable>(
    _ expression1: @autoclosure () throws -> T,
    _ expression2: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        let first = try expression1()
        let second = try expression2()
        if first <= second {
            fail(
                "XCTAssertGreaterThan failed: \(first) is not greater than \(second). \(message())",
                file: file,
                line: line
            )
        }
    } catch {
        fail("XCTAssertGreaterThan threw \(error). \(message())", file: file, line: line)
    }
}

public func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) {
    do {
        _ = try expression()
        fail("XCTAssertThrowsError failed: no error was thrown. \(message())", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}

public func XCTUnwrap<T>(
    _ expression: @autoclosure () throws -> T?,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> T {
    if let value = try expression() {
        return value
    }
    fail("XCTUnwrap failed. \(message())", file: file, line: line)
}

public func XCTFail(
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    fail("XCTFail: \(message())", file: file, line: line)
}

private func evaluate(
    _ expression: () throws -> Bool,
    expected: Bool,
    message: String,
    file: StaticString,
    line: UInt
) {
    do {
        if try expression() != expected {
            fail("XCTAssert\(expected ? "True" : "False") failed. \(message)", file: file, line: line)
        }
    } catch {
        fail("XCTAssert threw \(error). \(message)", file: file, line: line)
    }
}

private func fail(
    _ message: String,
    file: StaticString,
    line: UInt
) -> Never {
    fatalError("\(file):\(line): \(message)")
}
