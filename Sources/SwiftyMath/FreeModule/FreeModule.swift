import Foundation

public protocol FreeModuleGenerator: SetType, Comparable {
    var degree: Int { get }
}

public extension FreeModuleGenerator {
    var degree: Int { return 1 }
}

public protocol FreeModuleType: Module {
    associatedtype Generator: FreeModuleGenerator
    var elements: [Generator : CoeffRing] { get }
    init(generators: [Generator], components: [CoeffRing])
    static func wrap(_ a: Generator) -> Self
    func factorize(by: [Generator]) -> [CoeffRing]
}

public struct FreeModule<A: FreeModuleGenerator, R: Ring>: FreeModuleType {
    public typealias CoeffRing = R
    public typealias Generator = A
    
    public let elements: [A: R]
    
    // root initializer
    public init(_ elements: [A : R]) {
        self.elements = elements.filter{ $0.value != .zero }
    }
    
    public init<S: Sequence>(_ elements: S) where S.Element == (A, R) {
        let dict = Dictionary(pairs: elements)
        self.init(dict)
    }
    
    public init(generators: [A], components: [R]) {
        assert(generators.count == components.count)
        self.init(Dictionary(pairs: zip(generators, components)))
    }
    
    @_transparent
    public static func wrap(_ a: A) -> FreeModule<A, R> {
        return FreeModule([a : .identity])
    }

    @_transparent
    public func unwrap() -> A {
        assert(isSingle)
        return elements.anyElement!.key
    }
    
    public subscript(a: A) -> R {
        return elements[a] ?? .zero
    }
    
    public var degree: Int {
        return elements.anyElement?.0.degree ?? 0
    }
    
    public var generators: [A] {
        return elements.keys.sorted().toArray()
    }
    
    public var components: [R] {
        return elements.keys.sorted().map{ self[$0] }
    }
    
    public func factorize(by list: [A]) -> [R] {
        return list.map{ self[$0] }
    }
    
    public var isSingle: Bool {
        return elements.count == 1 && elements.anyElement!.value == .identity
    }
    
    public static var zero: FreeModule<A, R> {
        return FreeModule([])
    }
    
    public func convertGenerators<A2>(_ f: (A) -> A2) -> FreeModule<A2, R> {
        return FreeModule<A2, R>(elements.mapKeys(f))
    }
    
    public func convertComponents<R2>(_ f: (R) -> R2) -> FreeModule<A, R2> {
        return FreeModule<A, R2>(elements.mapValues(f))
    }
    
    public static func + (a: FreeModule<A, R>, b: FreeModule<A, R>) -> FreeModule<A, R> {
        var d = a.elements
        for (a, r) in b.elements {
            d[a] = d[a, default: .zero] + r
        }
        return FreeModule<A, R>(d)
    }
    
    public static prefix func - (a: FreeModule<A, R>) -> FreeModule<A, R> {
        return FreeModule<A, R>(a.elements.mapValues{ -$0 })
    }
    
    public static func * (r: R, a: FreeModule<A, R>) -> FreeModule<A, R> {
        return FreeModule<A, R>(a.elements.mapValues{ r * $0 })
    }
    
    public static func * (a: FreeModule<A, R>, r: R) -> FreeModule<A, R> {
        return FreeModule<A, R>(a.elements.mapValues{ $0 * r })
    }
    
    public static func sum(_ elements: [FreeModule<A, R>]) -> FreeModule<A, R> {
        var sum = [A : R]()
        elements.forEach{ x in
            sum.merge(x.elements) { (r1, r2) in r1 + r2 }
        }
        return FreeModule(sum)
    }
    
    public var description: String {
        return Format.terms("+", generators.map { a in (self[a], a.description, 1) })
    }
    
    public static var symbol: String {
        return "FreeMod(\(R.symbol))"
    }
}

public func *<A, R>(v: [FreeModule<A, R>], a: DMatrix<R>) -> [FreeModule<A, R>] {
    assert(v.count == a.rows)
    return (0 ..< a.cols).map{ j in
        a.nonZeroComponents(ofCol: j).sum{ c in
            v[c.row] * c.value
        }
    }
}

extension FreeModule: VectorSpace where R: Field {}

// MEMO: with parameterized extension, we would like to write:
// extension<A, B> ModuleHom where X == FreeModule<A, R>, Y == FreeModule<B, R>

extension ModuleHom where X: FreeModuleType, Y: FreeModuleType {
    public static func linearlyExtend(_ f: @escaping (X.Generator) -> Codomain) -> ModuleHom<X, Y> {
        return ModuleHom { (m: Domain) in
            m.elements.map{ (a, r) in r * f(a) }.sumAll()
        }
    }
    
    public static func generateFrom(inputBasis: [X.Generator], outputBasis: [Y.Generator], matrix: DMatrix<CoeffRing>) -> ModuleHom<X, Y> {
        let indexer = inputBasis.indexer()
        return ModuleHom.linearlyExtend { e in
            guard let j = indexer(e) else { return .zero }
            return Y(generators: outputBasis, components: matrix.colVector(j).grid)
        }
    }
    
    public func asMatrix(from: [X.Generator], to: [Y.Generator]) -> DMatrix<CoeffRing> {
        let comps = from.enumerated().flatMap { (j, a) -> [MatrixComponent<CoeffRing>] in
            let w = self.applied(to: .wrap(a))
            return w.factorize(by: to).enumerated().compactMap { (i, a) in
                a != .zero ? MatrixComponent(i, j, a) : nil
            }
        }
        return DMatrix(rows: to.count, cols: from.count, components: comps)
    }
}

extension FreeModule: Codable where A: Codable, R: Codable {}
