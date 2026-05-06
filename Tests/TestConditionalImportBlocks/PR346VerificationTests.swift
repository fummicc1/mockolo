import XCTest
@testable import MockoloFramework

/// Verification tests for PR #346 correctness checks (local only — not for upstream).
final class PR346VerificationTests: MockoloTestCase {

    // MARK: - C1: Same-name protocol in #if/#elseif (different bodies)

    func test_C1_sameNameProtocolInIfElseif() {
        let src = """
        #if os(iOS)
        /// @mockable
        public protocol Foo {
            func iosOnly()
        }
        #elseif os(macOS)
        /// @mockable
        public protocol Foo {
            func macOnly()
        }
        #endif
        """
        let expected = """
        #if os(iOS)
        public class FooMock: Foo {
            public init() { }


            public private(set) var iosOnlyCallCount = 0
            public var iosOnlyHandler: (() -> ())?
            public func iosOnly() {
                iosOnlyCallCount += 1
                if let iosOnlyHandler = iosOnlyHandler {
                    iosOnlyHandler()
                }
            }
        }
        #elseif os(macOS)
        public class FooMock: Foo {
            public init() { }


            public private(set) var macOnlyCallCount = 0
            public var macOnlyHandler: (() -> ())?
            public func macOnly() {
                macOnlyCallCount += 1
                if let macOnlyHandler = macOnlyHandler {
                    macOnlyHandler()
                }
            }
        }
        #endif
        """
        verify(srcContent: src, dstContent: expected)
    }

    // MARK: - C2: #if/#elseif/#else 3 branches

    func test_C2_threeBranchWithElse() {
        let src = """
        #if A
        /// @mockable
        public protocol PA { func a() }
        #elseif B
        /// @mockable
        public protocol PB { func b() }
        #else
        /// @mockable
        public protocol PR { func r() }
        #endif
        """
        let expected = """
        #if A
        public class PAMock: PA {
            public init() { }


            public private(set) var aCallCount = 0
            public var aHandler: (() -> ())?
            public func a() {
                aCallCount += 1
                if let aHandler = aHandler {
                    aHandler()
                }
            }
        }
        #elseif B
        public class PBMock: PB {
            public init() { }


            public private(set) var bCallCount = 0
            public var bHandler: (() -> ())?
            public func b() {
                bCallCount += 1
                if let bHandler = bHandler {
                    bHandler()
                }
            }
        }
        #else
        public class PRMock: PR {
            public init() { }


            public private(set) var rCallCount = 0
            public var rHandler: (() -> ())?
            public func r() {
                rCallCount += 1
                if let rHandler = rHandler {
                    rHandler()
                }
            }
        }
        #endif
        """
        verify(srcContent: src, dstContent: expected)
    }

    // MARK: - C5: Inheritance across #if boundary

    func test_C5_inheritanceAcrossIfBoundary() {
        let src = """
        /// @mockable
        public protocol Base {
            func baseMethod()
        }
        #if os(iOS)
        /// @mockable
        public protocol Sub: Base {
            func subMethod()
        }
        #endif
        """
        // Expect Sub mock to include both baseMethod and subMethod.
        // Order of mocks in output is by source offset: Base first, then Sub inside #if.
        let expected = """
        public class BaseMock: Base {
            public init() { }


            public private(set) var baseMethodCallCount = 0
            public var baseMethodHandler: (() -> ())?
            public func baseMethod() {
                baseMethodCallCount += 1
                if let baseMethodHandler = baseMethodHandler {
                    baseMethodHandler()
                }
            }
        }
        #if os(iOS)
        public class SubMock: Sub {
            public init() { }


            public private(set) var baseMethodCallCount = 0
            public var baseMethodHandler: (() -> ())?
            public func baseMethod() {
                baseMethodCallCount += 1
                if let baseMethodHandler = baseMethodHandler {
                    baseMethodHandler()
                }
            }

            public private(set) var subMethodCallCount = 0
            public var subMethodHandler: (() -> ())?
            public func subMethod() {
                subMethodCallCount += 1
                if let subMethodHandler = subMethodHandler {
                    subMethodHandler()
                }
            }
        }
        #endif
        """
        verify(srcContent: src, dstContent: expected)
    }

    // MARK: - C9: Empty #if block (no entities, no imports)

    func test_C9_emptyIfBlock() {
        let src = """
        #if NONEMPTY_FLAG
        #endif

        /// @mockable
        public protocol Foo { func m() }
        """
        let expected = """
        public class FooMock: Foo {
            public init() { }


            public private(set) var mCallCount = 0
            public var mHandler: (() -> ())?
            public func m() {
                mCallCount += 1
                if let mHandler = mHandler {
                    mHandler()
                }
            }
        }
        """
        verify(srcContent: src, dstContent: expected)
    }

    // MARK: - C12: Mixed non-conditional + conditional protocols

    func test_C12_mixedNonConditionalAndConditional() {
        let src = """
        /// @mockable
        public protocol TopLevel {
            func topMethod()
        }

        #if os(iOS)
        /// @mockable
        public protocol Inside {
            func insideMethod()
        }
        #endif
        """
        let expected = """
        public class TopLevelMock: TopLevel {
            public init() { }


            public private(set) var topMethodCallCount = 0
            public var topMethodHandler: (() -> ())?
            public func topMethod() {
                topMethodCallCount += 1
                if let topMethodHandler = topMethodHandler {
                    topMethodHandler()
                }
            }
        }
        #if os(iOS)
        public class InsideMock: Inside {
            public init() { }


            public private(set) var insideMethodCallCount = 0
            public var insideMethodHandler: (() -> ())?
            public func insideMethod() {
                insideMethodCallCount += 1
                if let insideMethodHandler = insideMethodHandler {
                    insideMethodHandler()
                }
            }
        }
        #endif
        """
        verify(srcContent: src, dstContent: expected)
    }

    // MARK: - NESTED: nested top-level #if with entities at both levels

    /// Reproduces a duplicate-output suspicion: outer and inner #if both contain entities.
    /// `Generator.collectEntityBlocks` recursively walks `clause.imports` and appends any
    /// `block.containsEntities == true` block. `renderBlock(outer)` already renders the
    /// nested block via its own recursion, so the inner block being processed AGAIN at the
    /// top level may emit the inner protocol mock twice.
    func test_NESTED_outerInnerBothHaveEntities() {
        let src = """
        #if os(iOS)
        /// @mockable
        public protocol Outer {
            func outerMethod()
        }
        #if DEBUG
        /// @mockable
        public protocol Inner {
            func innerMethod()
        }
        #endif
        #endif
        """
        let expected = """
        #if os(iOS)
        public class OuterMock: Outer {
            public init() { }


            public private(set) var outerMethodCallCount = 0
            public var outerMethodHandler: (() -> ())?
            public func outerMethod() {
                outerMethodCallCount += 1
                if let outerMethodHandler = outerMethodHandler {
                    outerMethodHandler()
                }
            }
        }
        #if DEBUG
        public class InnerMock: Inner {
            public init() { }


            public private(set) var innerMethodCallCount = 0
            public var innerMethodHandler: (() -> ())?
            public func innerMethod() {
                innerMethodCallCount += 1
                if let innerMethodHandler = innerMethodHandler {
                    innerMethodHandler()
                }
            }
        }
        #endif
        #endif
        """
        verify(srcContent: src, dstContent: expected)
    }

    // MARK: - C3: Compound conditions

    func test_C3_compoundConditions() {
        let src = """
        #if !DEBUG
        /// @mockable
        public protocol A { func a() }
        #endif

        #if FOO || BAR
        /// @mockable
        public protocol B { func b() }
        #endif

        #if FOO && BAR
        /// @mockable
        public protocol C { func c() }
        #endif
        """
        let expected = """
        #if !DEBUG
        public class AMock: A {
            public init() { }


            public private(set) var aCallCount = 0
            public var aHandler: (() -> ())?
            public func a() {
                aCallCount += 1
                if let aHandler = aHandler {
                    aHandler()
                }
            }
        }
        #endif
        #if FOO || BAR
        public class BMock: B {
            public init() { }


            public private(set) var bCallCount = 0
            public var bHandler: (() -> ())?
            public func b() {
                bCallCount += 1
                if let bHandler = bHandler {
                    bHandler()
                }
            }
        }
        #endif
        #if FOO && BAR
        public class CMock: C {
            public init() { }


            public private(set) var cCallCount = 0
            public var cHandler: (() -> ())?
            public func c() {
                cCallCount += 1
                if let cHandler = cHandler {
                    cHandler()
                }
            }
        }
        #endif
        """
        verify(srcContent: src, dstContent: expected)
    }
}
