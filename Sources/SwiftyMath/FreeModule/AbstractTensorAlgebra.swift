//
//  AbstractTensorAlgebra.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2019/06/06.
//

import Foundation

public struct T<A: FreeModuleGenerator>: FreeModuleGenerator {
    public let factors: [A]
    init(_ a: A) {
        self.init([a])
    }
    
    init(_ factors: [A]) {
        self.factors = factors
    }
    
    init<S: Sequence>(_ factors: S) where S.Element == A {
        self.init(factors.toArray())
    }
    
    public subscript(i: Int) -> A {
        return factors[i]
    }
    
    public var degree: Int {
        return factors.sum { $0.degree }
    }
    
    public static var unit: T<A> {
        return T([])
    }
    
    public static func ⊗(t1: T<A>, t2: T<A>) -> T<A> {
        return T(t1.factors + t2.factors)
    }
    
    public static func < (t1: T<A>, t2: T<A>) -> Bool {
        return t1.degree < t2.degree || (t1.degree == t2.degree && t1.factors.lexicographicallyPrecedes(t2.factors))
    }
    
    public var description: String {
        return factors.map{ $0.description }.joined(separator: "⊗")
    }
}

extension T: Codable where A: Codable {}

public typealias AbstractTensorAlgebra<R: Ring> = FreeModule<T<AbstractGenerator>, R>

extension FreeModule where A == T<AbstractGenerator> {
    public static func wrap(_ z: AbstractFreeModule<R>) -> AbstractTensorAlgebra<R> {
        return z.convertGenerators{ a in T(a) }
    }
    
    public static func produceGenerators(from generators: [AbstractGenerator], power n: Int) -> [T<AbstractGenerator>] {
        if n == 0 {
            return []
        }
        
        let tGenerators = (0 ..< n - 1).reduce(generators.map{ [$0] }) { (result, _) -> [[AbstractGenerator]] in
            result.allCombinations(with: generators).map{ (list, e) in list.appended(e) }
        }
        return tGenerators.map{ factors in T(factors) }
    }
    
    public static var identity: FreeModule<T<AbstractGenerator>, R> {
        return .wrap(.unit)
    }
    
    public static func ⊗(a: AbstractTensorAlgebra<R>, b: AbstractTensorAlgebra<R>) -> AbstractTensorAlgebra<R> {
        return a.elements.sum { (t1, r1) in
            b.elements.sum { (t2, r2) in
                let r = r1 * r2
                let t = t1 ⊗ t2
                return r * .wrap(t)
            }
        }
    }
}

public struct AbstractTensorAlgebraHom<R: Ring>: ModuleHomType {
    public typealias CoeffRing = R
    public typealias Domain   = AbstractTensorAlgebra<R>
    public typealias Codomain = AbstractTensorAlgebra<R>

    public let  inputFactors: Int
    public let outputFactors: Int
    private let f: (Domain) -> Codomain
    
    public init(inputFactors: Int, outputFactors: Int, _ f: @escaping (Domain) -> Codomain) {
        self.inputFactors = inputFactors
        self.outputFactors = outputFactors
        self.f = f
    }
    
    public static func linearlyExtend(inputFactors: Int, outputFactors: Int, _ f: @escaping (T<AbstractGenerator>) -> Domain) -> AbstractTensorAlgebraHom<R> {
        return .init(inputFactors: inputFactors, outputFactors: outputFactors) {
            applyWithAssertion(inputFactors, outputFactors, $0) {
                $0.elements.map{ (t, r) in r * f(t) }.sumAll()
            }
        }
    }
    
    public static func fromMatrix(inputGenerators input: [T<AbstractGenerator>], outputGenerators output: [T<AbstractGenerator>], matrix: DMatrix<CoeffRing>) -> AbstractTensorAlgebraHom<R> {
        let  inputFactors =  input.first!.factors.count
        let outputFactors = output.first!.factors.count
        
        assert(  input.allSatisfy{ $0.factors.count ==  inputFactors } )
        assert( output.allSatisfy{ $0.factors.count == outputFactors } )
        
        let indexer = input.indexer()
        return .linearlyExtend(inputFactors: inputFactors, outputFactors: outputFactors) { t in
            guard let j = indexer(t) else { return .zero }
            return .init(generators: output, components: matrix.colVector(j).grid)
        }
    }
    
    public static func wrap(_ f: ModuleEnd<AbstractFreeModule<R>>) -> AbstractTensorAlgebraHom<R> {
        return .init(inputFactors: 1, outputFactors: 1) {
            applyWithAssertion(1, 1, $0) {
                // unwrap -> apply -> wrap
                f.applied(to: $0.convertGenerators{ $0.factors[0] } ).convertGenerators{ T($0) }
            }
        }
    }
    
    public static var zero: AbstractTensorAlgebraHom<R> {
        fatalError()
    }
    
    public static func identityMap(factors: Int) -> AbstractTensorAlgebraHom {
        return .init(inputFactors: factors, outputFactors: factors) { $0 }
    }
    
    public static func + (f: AbstractTensorAlgebraHom<R>, g: AbstractTensorAlgebraHom<R>) -> AbstractTensorAlgebraHom<R> {
        assert(f.inputFactors == g.inputFactors)
        assert(f.outputFactors == g.outputFactors)
        return .init(inputFactors: f.inputFactors, outputFactors: f.outputFactors) {
            x in f.applied(to: x) + g.applied(to: x)
        }
    }
    
    public static prefix func - (f: AbstractTensorAlgebraHom<R>) -> AbstractTensorAlgebraHom<R> {
        return .init(inputFactors: f.inputFactors, outputFactors: f.outputFactors) {
            x in -f.applied(to: x)
        }
    }
    
    public static func * (r: R, f: AbstractTensorAlgebraHom<R>) -> AbstractTensorAlgebraHom<R> {
        return .init(inputFactors: f.inputFactors, outputFactors: f.outputFactors) {
            x in r * f.applied(to: x)
        }
    }
    
    public static func * (f: AbstractTensorAlgebraHom<R>, r: R) -> AbstractTensorAlgebraHom<R> {
        return .init(inputFactors: f.inputFactors, outputFactors: f.outputFactors) {
            x in f.applied(to: x) * r
        }
    }
    
    public static func ⊗ (f: AbstractTensorAlgebraHom<R>, g: AbstractTensorAlgebraHom<R>) -> AbstractTensorAlgebraHom<R> {
        return .linearlyExtend(inputFactors: f.inputFactors + g.inputFactors, outputFactors: f.outputFactors + g.outputFactors) {
            (x: T<AbstractGenerator>) in
            let x1 = T(x.factors[0 ..< f.inputFactors])
            let x2 = T(x.factors[f.inputFactors ..< x.factors.count])
            return f.applied(to: .wrap(x1)) ⊗ g.applied(to: .wrap(x2))
        }
    }
    
    public func applied(to x: AbstractTensorAlgebra<R>) -> AbstractTensorAlgebra<R> {
        return applyWithAssertion(x, f)
    }
    
    public func composed(with f: AbstractTensorAlgebraHom<R>) -> AbstractTensorAlgebraHom<R> {
        assert(f.outputFactors == self.inputFactors)
        return .init(inputFactors: f.inputFactors, outputFactors: self.outputFactors) {
            x in self.applied( to: f.applied(to: x) )
        }
    }
    
    public static func ∘(g: AbstractTensorAlgebraHom<R>, f: AbstractTensorAlgebraHom<R>) -> AbstractTensorAlgebraHom<R> {
        return g.composed(with: f)
    }
    
    private static func assertFactors(_ factors: Int, _ x: Domain) {
        assert(x.generators.allSatisfy{ $0.factors.count == factors } )
    }
    
    private static func applyWithAssertion(_ inputFactors: Int, _ outputFactors: Int, _ x: Domain, _ f: (Domain) -> Codomain) -> Codomain {
        assertFactors(inputFactors, x)
        let y = f(x)
        assertFactors(outputFactors, y)
        return y
    }
    
    private func applyWithAssertion(_ x: Domain, _ f: (Domain) -> Codomain) -> Codomain {
        return AbstractTensorAlgebraHom<R>.applyWithAssertion(inputFactors, outputFactors, x, f)
    }
}
