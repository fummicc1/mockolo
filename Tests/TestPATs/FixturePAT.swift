import MockoloFramework

let patNameCollision = """
/// @mockable
protocol Foo {
associatedtype T
}

/// @mockable
protocol Bar {
associatedtype T: String
}

/// @mockable(typealias: T = Hashable & Codable)
protocol Cat {
associatedtype T
}

/// @mockable
protocol Baz: Foo, Bar, Cat {
}
"""

let patNameCollisionMock = """
class FooMock: Foo {
    init() { }
    typealias T = Any
}

class BarMock: Bar {
    init() { }
    typealias T = String
}

class CatMock: Cat {
    init() { }
    typealias T = Hashable & Codable
}

class BazMock: Baz {
    typealias T = Any & Hashable & Codable & String
    
    init() { }
}
"""

let simplePat =
"""
/// @mockable(typealias: T = String)
public protocol FooBar: Foo {
    associatedtype T
}
"""
let parentPatMock =
"""
public class FooMock: Foo {
    public init() { }

    public typealias T = String
}
"""
let patWithParentMock =
"""
public class FooBarMock: FooBar {
    public init() { }

    public typealias T = String
}
"""


let patOverride = """
/// @mockable(typealias: T = Any; U = Bar; R = (String, Int); S = AnyObject)
protocol Foo {
    associatedtype T
    associatedtype U: Collection where U.Element == T
    associatedtype R where Self.T == Hashable
    associatedtype S: ExpressibleByNilLiteral
    func update(x: T, y: U) -> (U, R)
}
"""

let patOverrideMock = """
class FooMock: Foo {
    init() { }

    typealias T = Any
    typealias U = Bar
    typealias R = (String, Int)
    typealias S = AnyObject

    private(set) var updateCallCount = 0
    var updateHandler: ((T, U) -> (U, R))?
    func update(x: T, y: U) -> (U, R) {
        updateCallCount += 1
        if let updateHandler = updateHandler {
            return updateHandler(x, y)
        }
        fatalError("updateHandler returns can't have a default value thus its handler must be set")
    }
}

"""

let protocolWithTypealias = """
/// @mockable
public protocol SomeType {
    typealias Key = String
    var key: Key { get }
}
"""

let protocolWithTypealiasMock = """
public class SomeTypeMock: SomeType {
    public init() { }
    public init(key: Key) {
        self._key = key
    }
    public typealias Key = String
    
    private var _key: Key!
    public var key: Key {
        get { return _key }
        set { _key = newValue }
    }
}

"""

let patDefaultType = """
/// @mockable
protocol Foo {
    associatedtype T
    associatedtype U: Collection where U.Element == T
}
"""

let patDefaultTypeMock = """
class FooMock: Foo {
    init() { }

    typealias T = Any
    typealias U = Collection where U.Element == T
}
"""

let patPartialOverride = """
/// @mockable(typealias: U = AnyObject)
protocol Foo {
    associatedtype T
    associatedtype U: Collection where U.Element == T
}
"""


let patPartialOverrideMock = """
class FooMock: Foo {
    init() { }
    typealias T = Any
    typealias U = AnyObject
}
"""
