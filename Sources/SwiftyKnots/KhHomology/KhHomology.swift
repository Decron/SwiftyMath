//
//  KhHomology.swift
//  SwiftyKnots
//
//  Created by Taketo Sano on 2018/04/04.
//

import Foundation
import SwiftyMath
import SwiftyHomology

public extension Link {
    internal func KhCube<R>(_ μ: KhBasisElement.Product<R>, _ Δ: KhBasisElement.Coproduct<R>, reduced: Bool = false) -> ModuleCube<KhBasisElement, R> {
        typealias A = KhBasisElement
        
        let n = self.crossingNumber
        let states = self.allStates
        let Ls = Dictionary(keys: states){ s in self.spliced(by: s) }
        
        let objects = Dictionary(keys: states){ s -> ModuleObject<A, R> in
            let comps = Ls[s]!.components
            let basis = A.generateBasis(state: s, power: comps.count)
            
            if !reduced {
                return ModuleObject(basis: basis)
            } else {
                let rBasis = basis.filter{ $0.tensor[0] == .I }
                return ModuleObject(basis: rBasis)
            }
        }
        
        let edgeMaps = { (s0: IntList, s1: IntList) -> FreeModuleHom<A, A, R> in
            let (L0, L1) = (Ls[s0]!, Ls[s1]!)
            let (c1, c2) = (L0.components, L1.components)
            let (d1, d2) = (c1.filter{ !c2.contains($0) }, c2.filter{ !c1.contains($0) })
            switch (d1.count, d2.count) {
            case (2, 1):
                let (i1, i2) = (c1.index(of: d1[0])!, c1.index(of: d1[1])!)
                let j = c2.index(of: d2[0])!
                return FreeModuleHom{ (x: A) in x.applied(μ, at: (i1, i2), to: j, state: s1) }
                
            case (1, 2):
                let i = c1.index(of: d1[0])!
                let (j1, j2) = (c2.index(of: d2[0])!, c2.index(of: d2[1])!)
                return FreeModuleHom{ (x: A) in x.applied(Δ, at: i, to: (j1, j2), state: s1) }

            default: fatalError()
            }
        }
        
        return ModuleCube(dim: n, objects: objects, edgeMaps: edgeMaps)
    }
    
    internal func KhChainComplex<R: EuclideanRing>(_ μ: KhBasisElement.Product<R>, _ Δ: KhBasisElement.Coproduct<R>, reduced: Bool = false, normalized: Bool = true) -> ChainComplex2<KhBasisElement, R> {
        
        let name = "CKh(\(self.name)\( R.self == 𝐙.self ? "" : "; \(R.symbol)"))"
        let (n⁺, n⁻) = (crossingNumber⁺, crossingNumber⁻)
        
        let cube = self.KhCube(μ, Δ, reduced: reduced)
        let j0 = cube.bottom.generators.map{ $0.degree }.min() ?? 0
        let j1 =    cube.top.generators.map{ $0.degree }.max() ?? 0
        let js = (j0 ... j1).filter{ j in (j - j0) % 2 == 0 }
        
        let subcubes = Dictionary(keys: js) { j in
            cube.subCube{ s in s.generator.degree == j }
        }
        
        typealias Object = ModuleObject<KhBasisElement, R>
        let list = js.flatMap{ j -> [(Int, Int, Object?)] in
            let c = subcubes[j]!.fold()
            return c.degrees.map{ i in (i, j, c[i]) }
        }
        
        let base = ModuleGrid2(name: name, list: list, default: .zeroModule)
        let d = ChainMap2(bidegree: (1, 0)) { (_, _) -> FreeModuleHom<KhBasisElement, KhBasisElement, R> in
            return FreeModuleHom{ (x: KhBasisElement) in
                cube.d(x.state).applied(to: x)
            }
        }
        
        let CKh = ChainComplex2(base: base, differential: d)
        return normalized ? CKh.shifted(-n⁻, n⁺ - 2 * n⁻) : CKh
    }
    
    public func KhChainComplex<R: EuclideanRing>(_ type: R.Type, reduced: Bool = false, normalized: Bool = true) -> ChainComplex2<KhBasisElement, R> {
        let (μ, Δ) = (KhBasisElement.μ(R.self), KhBasisElement.Δ(R.self))
        return KhChainComplex(μ, Δ, reduced: reduced, normalized: normalized)
    }
    
    public func KhHomology<R: EuclideanRing>(_ type: R.Type, reduced: Bool = false, normalized: Bool = true) -> ModuleGrid2<KhBasisElement, R> {
        let name = "Kh(\(self.name)\( R.self == 𝐙.self ? "" : "; \(R.symbol)"))"
        let C = self.KhChainComplex(R.self, reduced: reduced, normalized: normalized)
        return C.homology(name: name)
    }
    
    public func KhHomology<R: EuclideanRing & Codable>(_ type: R.Type, useCache: Bool) -> ModuleGrid2<KhBasisElement, R> {
        if useCache {
            let id = "Kh_\(name)_\(R.symbol)"
            return Storage.useCache(id) { KhHomology(R.self) }
        } else {
            return KhHomology(R.self)
        }
    }
    
    public func KhLeeChainComplex<R: EuclideanRing>(_ type: R.Type, reduced: Bool = false, normalized: Bool = true) -> ChainComplex2<KhBasisElement, R> {
        typealias C = ChainComplex2<KhBasisElement, R>
        let base = KhHomology(type, reduced: reduced, normalized: normalized)
        let cube = self.KhCube(KhBasisElement.μ_Lee(R.self), KhBasisElement.Δ_Lee(R.self))
        let d = ChainMap2(bidegree: (1, 4)) { (_, _) in
            FreeModuleHom{ (x: KhBasisElement) in cube.d(x.state).applied(to: x) }
        }
        return ChainComplex2(base: base, differential: d)
    }

    public func KhLeeHomology<R: EuclideanRing>(_ type: R.Type, reduced: Bool = false, normalized: Bool = true) -> ModuleGrid2<KhBasisElement, R> {
        let name = "KhLee(\(self.name); \(R.symbol))"
        let Kh = KhLeeChainComplex(type, reduced: reduced, normalized: normalized)
        return Kh.homology(name: name)
    }
    
    public func LeeChainComplex<R: EuclideanRing>(_ type: R.Type, normalized: Bool = true) -> ChainComplex<KhBasisElement, R> {
        let name = "Lee(\(self.name); \(R.symbol))"
        let (μ, Δ) = (KhBasisElement.μ(R.self), KhBasisElement.Δ(R.self))
        let (μL, ΔL) = (KhBasisElement.μ_Lee(R.self), KhBasisElement.Δ_Lee(R.self))
        let cube = KhCube(μ + μL, Δ + ΔL)
        let base = cube.fold().shifted(normalized ? -crossingNumber⁻ : 0)
        let d = ChainMap(degree: 1) { _ in
            FreeModuleHom{ (x: KhBasisElement) in
                cube.d(x.state).applied(to: x)
            }
        }
        return ChainComplex(base: base, differential: d)
    }
    
    public func LeeHomology<R: EuclideanRing>(_ type: R.Type, normalized: Bool = true) -> ModuleGrid1<KhBasisElement, R> {
        return LeeChainComplex(type, normalized: normalized).homology()
    }
    
    public var orientationPreservingState: IntList {
        return IntList(crossings.map{ $0.crossingSign == 1 ? 0 : 1 })
    }
    
    public func LeeHomologyGenerators<R: EuclideanRing>(_ type: R.Type) -> [FreeModule<KhBasisElement, R>] {
        assert(self.components.count == 1) // currently supports only knots.
        
        let s0 = orientationPreservingState
        let L0 = self.spliced(by: s0)
        let comps = L0.components
        
        // splits comps into two groups.
        var queue:  [(Component, Int)] = [(comps[0], 0)]
        var result:  [Component : Int] = [:]
        
        while !queue.isEmpty {
            let (c, i) = queue.removeFirst()
            
            // crossings that touches c
            let xs = crossings.filter{ x in
                x.edges.contains{ e in c.edges.contains(e) }
            }
            
            // circles that are connected to c by xs
            let cs = xs.map{ x -> Component in
                let e = x.edges.first{ e in !c.edges.contains(e) }!
                return comps.first{ c1 in c1.edges.contains(e) }!
            }.unique()
            
            // queue circles with opposite color.
            for c1 in cs where !result.contains(key: c1) {
                queue.append((c1, 1 - i))
            }
            
            // append result.
            result[c] = i
        }
        
        assert(result.count == comps.count)
        
        typealias A = FreeModule<FreeTensor<KhBasisElement.E>, R>
        
        let (X, I) = (A.wrap(FreeTensor(.X)), A.wrap(FreeTensor(.I)))
        let (a, b) = (X + I, X - I)
        var (z0, z1) = (A.wrap(.identity), A.wrap(.identity))
        
        for c in comps {
            switch result[c]! {
            case 0:
                z0 = z0 ⊗ a
                z1 = z1 ⊗ b
            default:
                z0 = z0 ⊗ b
                z1 = z1 ⊗ a
            }
        }
        
        return [z0, z1].map { z in
            z.mapBasis{ t in KhBasisElement(s0, t) }
        }
    }
}

public extension GridN where n == _2, Object: _ModuleObject, Object.A == KhBasisElement {
    public var bandWidth: Int {
        return bidegrees.map{ (i, j) in j - 2 * i }.unique().count
    }
    
    public var isDiagonal: Bool {
        return bandWidth == 1
    }
    
    public var isHThin: Bool {
        return bandWidth <= 2
    }
    
    public var isHThick: Bool {
        return !isHThin
    }
    
    public var qEulerCharacteristic: LaurentPolynomial<R, JonesPolynomial_q> {
        let q = LaurentPolynomial<R, JonesPolynomial_q>.indeterminate
        return bidegrees.sum { (i, j) -> LaurentPolynomial<R, JonesPolynomial_q> in
            let s = self[i, j]!
            let a = R(from: (-1).pow(i) * s.entity.rank )
            return a * q.pow(j)
        }
    }
}
