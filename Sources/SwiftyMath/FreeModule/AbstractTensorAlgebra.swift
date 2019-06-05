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
    
    public subscript(i: Int) -> A {
        return factors[i]
    }
    
    public var degree: Int {
        return factors.sum { $0.degree }
    }
    
    public static var unit: T<A> {
        return T([])
    }
    
    public static func *(t1: T<A>, t2: T<A>) -> T<A> {
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

extension FreeModule: Monoid where A == T<AbstractGenerator> {
    public static func wrap(_ z: AbstractFreeModule<R>) -> AbstractTensorAlgebra<R> {
        return z.convertGenerators{ a in T(a) }
    }
    
    public static func generateBasis(from: [AbstractFreeModule<R>], power n: Int) -> [AbstractTensorAlgebra<R>] {
        assert( from.allSatisfy{$0.isSingle} )
        if n == 0 {
            return []
        }
        
        let basis = from.map{ $0.unwrap() }
        let tensorBasis = (0 ..< n - 1).reduce(basis.map{ [$0] }) { (result, _) -> [[AbstractGenerator]] in
            result.allCombinations(with: basis).map{ (list, e) in list.appended(e) }
        }
        return tensorBasis.map{ factors in .wrap(T(factors)) }
    }
    
    public static var identity: FreeModule<T<AbstractGenerator>, R> {
        return .wrap(.unit)
    }
    
    public static func *(a: AbstractTensorAlgebra<R>, b: AbstractTensorAlgebra<R>) -> AbstractTensorAlgebra<R> {
        return a.elements.sum { (t1, r1) in
            b.elements.sum { (t2, r2) in
                let r = r1 * r2
                let t = t1 * t2
                return r * .wrap(t)
            }
        }
    }
}
