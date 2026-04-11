import MockoloFramework

// MARK: - Single #if block wrapping a protocol

let protocolInIfBlock = """
#if os(iOS)
/// @mockable
public protocol PlatformProtocol {
    func platformFunction()
}
#endif
"""

let protocolInIfBlockMock = """
#if os(iOS)
public class PlatformProtocolMock: PlatformProtocol {
    public init() { }


    public private(set) var platformFunctionCallCount = 0
    public var platformFunctionHandler: (() -> ())?
    public func platformFunction() {
        platformFunctionCallCount += 1
        if let platformFunctionHandler = platformFunctionHandler {
            platformFunctionHandler()
        }

    }
}
#endif
"""

// MARK: - #if/#elseif with a protocol in each branch

let protocolsInIfElseIf = """
#if os(iOS)
/// @mockable
public protocol IOSProtocol {
    func iosMethod()
}
#elseif os(macOS)
/// @mockable
public protocol MacOSProtocol {
    func macosMethod()
}
#endif
"""

let protocolsInIfElseIfMock = """
#if os(iOS)
public class IOSProtocolMock: IOSProtocol {
    public init() { }


    public private(set) var iosMethodCallCount = 0
    public var iosMethodHandler: (() -> ())?
    public func iosMethod() {
        iosMethodCallCount += 1
        if let iosMethodHandler = iosMethodHandler {
            iosMethodHandler()
        }

    }
}
#elseif os(macOS)
public class MacOSProtocolMock: MacOSProtocol {
    public init() { }


    public private(set) var macosMethodCallCount = 0
    public var macosMethodHandler: (() -> ())?
    public func macosMethod() {
        macosMethodCallCount += 1
        if let macosMethodHandler = macosMethodHandler {
            macosMethodHandler()
        }

    }
}
#endif
"""

// MARK: - #if block containing both imports and a protocol

let protocolAndImportInIfBlock = """
#if DEBUG
import XCTest
/// @mockable
public protocol DebugProtocol {
    func debugFunction()
}
#endif
"""

// Expected: imports in the header use the `#if DEBUG` block from the source,
// and the mock for `DebugProtocol` is also wrapped in its own `#if DEBUG`
// block at the entity's position.
let protocolAndImportInIfBlockMock = """
#if DEBUG
import XCTest
#endif


#if DEBUG
public class DebugProtocolMock: DebugProtocol {
    public init() { }


    public private(set) var debugFunctionCallCount = 0
    public var debugFunctionHandler: (() -> ())?
    public func debugFunction() {
        debugFunctionCallCount += 1
        if let debugFunctionHandler = debugFunctionHandler {
            debugFunctionHandler()
        }

    }
}
#endif
"""

// MARK: - Nested #if: outer #if wraps a protocol + a nested import-only #if

let nestedIfWithProtocol = """
#if os(iOS)
#if DEBUG
import XCTest
#endif
/// @mockable
public protocol NestedProtocol {
    func nestedMethod()
}
#endif
"""

let nestedIfWithProtocolMock = """
#if os(iOS)
#if DEBUG
import XCTest
#endif
#endif


#if os(iOS)
public class NestedProtocolMock: NestedProtocol {
    public init() { }


    public private(set) var nestedMethodCallCount = 0
    public var nestedMethodHandler: (() -> ())?
    public func nestedMethod() {
        nestedMethodCallCount += 1
        if let nestedMethodHandler = nestedMethodHandler {
            nestedMethodHandler()
        }

    }
}
#endif
"""

// MARK: - Doubly-nested #if wrapping a protocol
// This case is the one PR #346's flat IfConfigContext approach cannot preserve
// (the comment in that PR explicitly notes "only the immediate #if context is
// preserved"). With the tree-ownership model, both nesting levels are kept.

let doublyNestedIfWithProtocol = """
#if os(iOS)
#if DEBUG
/// @mockable
public protocol DoublyNestedProtocol {
    func doublyNestedMethod()
}
#endif
#endif
"""

let doublyNestedIfWithProtocolMock = """
#if os(iOS)
#if DEBUG
public class DoublyNestedProtocolMock: DoublyNestedProtocol {
    public init() { }


    public private(set) var doublyNestedMethodCallCount = 0
    public var doublyNestedMethodHandler: (() -> ())?
    public func doublyNestedMethod() {
        doublyNestedMethodCallCount += 1
        if let doublyNestedMethodHandler = doublyNestedMethodHandler {
            doublyNestedMethodHandler()
        }

    }
}
#endif
#endif
"""

// MARK: - Standalone protocol + #if-wrapped protocol in the same file

let mixedStandaloneAndWrapped = """
/// @mockable
public protocol StandaloneProtocol {
    func standaloneMethod()
}

#if os(iOS)
/// @mockable
public protocol WrappedProtocol {
    func wrappedMethod()
}
#endif
"""

let mixedStandaloneAndWrappedMock = """
public class StandaloneProtocolMock: StandaloneProtocol {
    public init() { }


    public private(set) var standaloneMethodCallCount = 0
    public var standaloneMethodHandler: (() -> ())?
    public func standaloneMethod() {
        standaloneMethodCallCount += 1
        if let standaloneMethodHandler = standaloneMethodHandler {
            standaloneMethodHandler()
        }

    }
}

#if os(iOS)
public class WrappedProtocolMock: WrappedProtocol {
    public init() { }


    public private(set) var wrappedMethodCallCount = 0
    public var wrappedMethodHandler: (() -> ())?
    public func wrappedMethod() {
        wrappedMethodCallCount += 1
        if let wrappedMethodHandler = wrappedMethodHandler {
            wrappedMethodHandler()
        }

    }
}
#endif
"""
