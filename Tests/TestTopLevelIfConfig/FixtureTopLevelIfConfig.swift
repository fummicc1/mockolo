import MockoloFramework

// 1. Single annotated protocol wrapped in a top-level `#if`. Regression
//    fixture for the bug where the protocol body was never visited.
let topLevelIfProtocol = """
#if DEBUG
/// @mockable
public protocol DebugOnly {
    func run()
}
#endif
"""

let topLevelIfProtocolMock = """
#if DEBUG
public class DebugOnlyMock: DebugOnly {
    public init() { }


    public private(set) var runCallCount = 0
    public var runHandler: (() -> ())?
    public func run() {
        runCallCount += 1
        if let runHandler = runHandler {
            runHandler()
        }

    }
}
#endif
"""

// 2. Distinct protocols in `#if`/`#elseif`/`#else`. All three branches
//    should retain their directive in the output.
let topLevelIfElseIfElseProtocols = """
#if A
/// @mockable
public protocol AOnly {
    func runA()
}
#elseif B
/// @mockable
public protocol BOnly {
    func runB()
}
#else
/// @mockable
public protocol Fallback {
    func runFallback()
}
#endif
"""

let topLevelIfElseIfElseProtocolsMock = """
#if A
public class AOnlyMock: AOnly {
    public init() { }


    public private(set) var runACallCount = 0
    public var runAHandler: (() -> ())?
    public func runA() {
        runACallCount += 1
        if let runAHandler = runAHandler {
            runAHandler()
        }

    }
}
#elseif B
public class BOnlyMock: BOnly {
    public init() { }


    public private(set) var runBCallCount = 0
    public var runBHandler: (() -> ())?
    public func runB() {
        runBCallCount += 1
        if let runBHandler = runBHandler {
            runBHandler()
        }

    }
}
#else
public class FallbackMock: Fallback {
    public init() { }


    public private(set) var runFallbackCallCount = 0
    public var runFallbackHandler: (() -> ())?
    public func runFallback() {
        runFallbackCallCount += 1
        if let runFallbackHandler = runFallbackHandler {
            runFallbackHandler()
        }

    }
}
#endif
"""

// 3. Nested top-level `#if`. The renderer recurses into the inner block
//    and preserves the nested directive structure.
let topLevelNestedIf = """
#if Outer
#if Inner
/// @mockable
public protocol Nested {
    func runNested()
}
#endif
#endif
"""

let topLevelNestedIfMock = """
#if Outer
#if Inner
public class NestedMock: Nested {
    public init() { }


    public private(set) var runNestedCallCount = 0
    public var runNestedHandler: (() -> ())?
    public func runNested() {
        runNestedCallCount += 1
        if let runNestedHandler = runNestedHandler {
            runNestedHandler()
        }

    }
}
#endif
#endif
"""

// 4. Imports and a mockable protocol share the same `#if`. The import
//    flows to the imports section while the mock stays wrapped in the
//    same directive.
let topLevelIfWithImportAndProtocol = """
#if FEATURE
import Foo
/// @mockable
public protocol Mixed {
    func runMixed()
}
#endif
"""

let topLevelIfWithImportAndProtocolMock = """
#if FEATURE
import Foo
#endif

#if FEATURE
public class MixedMock: Mixed {
    public init() { }


    public private(set) var runMixedCallCount = 0
    public var runMixedHandler: (() -> ())?
    public func runMixed() {
        runMixedCallCount += 1
        if let runMixedHandler = runMixedHandler {
            runMixedHandler()
        }

    }
}
#endif
"""

// 5. Unannotated protocol inside `#if`. Without `@mockable` there's
//    nothing to render, so the directive must not leak as an empty block.
let topLevelIfWithUnannotatedProtocol = """
#if X
public protocol Untouched {
    func untouchedFunc()
}
#endif

/// @mockable
public protocol StillRendered {
    func go()
}
"""

let topLevelIfWithUnannotatedProtocolMock = """
public class StillRenderedMock: StillRendered {
    public init() { }


    public private(set) var goCallCount = 0
    public var goHandler: (() -> ())?
    public func go() {
        goCallCount += 1
        if let goHandler = goHandler {
            goHandler()
        }

    }
}
"""

// 6. Standalone protocol followed by an `#if`-wrapped protocol followed
//    by another standalone. Source order must survive the offset sort
//    that merges block candidates with bare entity candidates.
let topLevelIfMixedWithStandalone = """
/// @mockable
public protocol AlphaProto {
    func alpha()
}

#if FLAG
/// @mockable
public protocol BetaProto {
    func beta()
}
#endif

/// @mockable
public protocol GammaProto {
    func gamma()
}
"""

let topLevelIfMixedWithStandaloneMock = """
public class AlphaProtoMock: AlphaProto {
    public init() { }


    public private(set) var alphaCallCount = 0
    public var alphaHandler: (() -> ())?
    public func alpha() {
        alphaCallCount += 1
        if let alphaHandler = alphaHandler {
            alphaHandler()
        }

    }
}
#if FLAG
public class BetaProtoMock: BetaProto {
    public init() { }


    public private(set) var betaCallCount = 0
    public var betaHandler: (() -> ())?
    public func beta() {
        betaCallCount += 1
        if let betaHandler = betaHandler {
            betaHandler()
        }

    }
}
#endif
public class GammaProtoMock: GammaProto {
    public init() { }


    public private(set) var gammaCallCount = 0
    public var gammaHandler: (() -> ())?
    public func gamma() {
        gammaCallCount += 1
        if let gammaHandler = gammaHandler {
            gammaHandler()
        }

    }
}
"""

// 7. Top-level `#if` containing a protocol whose member body has its own
//    `#if`. The two `#if` paths are independent — top-level via the new
//    code path, member-level via the existing IfMacroModel — and they
//    must compose without interference.
let topLevelAndMemberIf = """
#if Outer
/// @mockable
public protocol Composed {
    #if Inner
    func innerOnly()
    #endif
    func always()
}
#endif
"""

let topLevelAndMemberIfMock = """
#if Outer
public class ComposedMock: Composed {
    public init() { }

    #if Inner
    public private(set) var innerOnlyCallCount = 0
    public var innerOnlyHandler: (() -> ())?
    public func innerOnly() {
        innerOnlyCallCount += 1
        if let innerOnlyHandler = innerOnlyHandler {
            innerOnlyHandler()
        }

    }
    #endif

    public private(set) var alwaysCallCount = 0
    public var alwaysHandler: (() -> ())?
    public func always() {
        alwaysCallCount += 1
        if let alwaysHandler = alwaysHandler {
            alwaysHandler()
        }

    }
}
#endif
"""
