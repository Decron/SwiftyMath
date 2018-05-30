//
//  GradedChainComplex.swift
//  Sample
//
//  Created by Taketo Sano on 2018/05/21.
//

import Foundation
import SwiftyMath

// TODO substitute for old ChainComplex.

public typealias  ChainComplex<A: BasisElementType, R: EuclideanRing> = MChainComplex<_1, A, R>
public typealias ChainComplex2<A: BasisElementType, R: EuclideanRing> = MChainComplex<_2, A, R>

public struct MChainComplex<Dim: _Int, A: BasisElementType, R: EuclideanRing>: CustomStringConvertible {
    public typealias Base = ModuleGrid<Dim, A, R>
    public typealias Differential = MChainMap<Dim, A, A, R>
    public var base: Base
    
    public let d: Differential
    internal let dMatrices: [IntList : Cache<Matrix<R>>]
    
    internal let _freePart = Cache<MChainComplex<Dim, A, R>>()
    internal let  _torPart = Cache<MChainComplex<Dim, A, R>>()

    public init(base: ModuleGrid<Dim, A, R>, differential d: Differential) {
        assert(base.defaultObject == nil || base.defaultObject == .some(.zeroModule))
        
        self.base = base
        self.d = d
        
        let degs = base.mDegrees.flatMap{ I in [I, I - d.mDegree] }.unique()
        self.dMatrices = Dictionary(pairs: degs.map{ I in (I, .empty) })
    }
    
    public subscript(I: IntList) -> Base.Object? {
        get {
            return base[I]
        } set {
            base[I] = newValue
        }
    }
    
    public var name: String {
        return base.name
    }
    
    private var dDegree: IntList {
        return d.mDegree
    }
    
    public func shifted(_ I: IntList) -> MChainComplex<Dim, A, R> {
        return MChainComplex(base: base.shifted(I), differential: d.shifted(I))
    }
    
    public var freePart: MChainComplex<Dim, A, R> {
        return _freePart.useCacheOrSet(
            MChainComplex<Dim, A, R>(base: base.freePart, differential: d)
        )
    }
    
    public var torsionPart: MChainComplex<Dim, A, R> {
        return _torPart.useCacheOrSet(
            MChainComplex(base: base.torsionPart, differential: d)
        )
    }
    
    internal func dMatrix(_ I: IntList) -> Matrix<R>? {
        if let c = dMatrices[I], let A = c.value {
            return A // cached.
        }

        let A = d.matrix(from: self, to: self, at: I)
        dMatrices[I]?.value = A
        return A
    }
    
    internal func kernel(_ I: IntList) -> Matrix<R>? {
        guard let from = base[I], from.isFree,
            let to = base[I + dDegree], to.isFree,
            let A = dMatrix(I) else {
                return nil // indeterminable.
        }
        
        let E = A.elimination(form: .Diagonal)
        return E.kernelMatrix
    }
    
    internal func kernelTransition(_ I: IntList) -> Matrix<R>? {
        guard let from = base[I], from.isFree,
            let to = base[I + dDegree], to.isFree,
            let A = dMatrix(I) else {
                return nil // indeterminable.
        }
        
        let E = A.elimination(form: .Diagonal)
        return E.kernelTransitionMatrix
    }
    
    internal func image(_ I: IntList) -> Matrix<R>? {
        guard let from = base[I], from.isFree,
            let to = base[I + dDegree], to.isFree,
            let A = dMatrix(I) else {
                return nil // indeterminable.
        }
        
        let E = A.elimination(form: .Diagonal)
        return E.imageMatrix
    }
    
    public func homology(_ I: IntList) -> SimpleModuleStructure<A, R>? {
        // case: indeterminable
        if self[I] == nil {
            return nil
        }
        
        // case: obviously isom
        if  let Ain = dMatrix(I - dDegree), Ain.isZero,
            let Aout = dMatrix(I), Aout.isZero {
            return self[I]
        }
        
        // case: obviously zero
        if let Z = kernel(I), Z.isZero {
            return .zeroModule
        }
        
        // case: free
        if  let basis = self[I]?.generators,
            let Z = kernel(I),
            let T = kernelTransition(I),
            let B = image(I - dDegree) {
            return SimpleModuleStructure(
                basis: basis,
                generatingMatrix: Z,
                transitionMatrix: T,
                relationMatrix: T * B
            )
        }
        
        if dSplits(I) && dSplits(I - dDegree) {
            // case: splits as 𝐙, 𝐙₂ summands
            if R.self == 𝐙.self && self[I]!.torsionCoeffs.forAll({ $0 as! 𝐙 == 2 }) {
                let free = (freePart.homology(I)! as! SimpleModuleStructure<A, 𝐙>)
                let tor = (self as! MChainComplex<Dim, A, 𝐙>).order2torsionPart.homology(I)!
                return .some( (free ⊕ tor) as! SimpleModuleStructure<A, R> )
            } else {
                // TODO
                print(I, ": split")
                describeMap(I)
                return nil
            }
        }
        
        return nil
    }
    
    internal func dSplits(_ I: IntList) -> Bool {
        guard let from = self[I],
            let to = self[I + dDegree],
            let A = dMatrix(I) else {
                return false
        }
        
        // MEMO summands are assumed to be ordered as:
        // (R/d_0 ⊕ ... ⊕ R/d_k) ⊕ R^r
        
        func t(_ s: SimpleModuleStructure<A, R>) -> [(R, Int)] {
            return s.summands.reduce([]) { (res, s) in
                if let l = res.last, l.0 == s.divisor {
                    return res[0 ..< res.count - 1] + [(l.0, l.1 + 1)]
                } else {
                    return res + [(s.divisor, 1)]
                }
            }
        }
        
        let t0 = t(from)
        let t1 = t(to)
        
        let blocks = A.blocks(rowSizes: t1.map{ $0.1 }, colSizes: t0.map{ $0.1 })
        return blocks.enumerated().forAll { (i, Bs) in
            Bs.enumerated().forAll { (j, B) in
                return (t0[j].0 == t1[i].0) || B.isZero
            }
        }
    }
    
    public func homology(name: String? = nil) -> ModuleGrid<Dim, A, R> {
        let list = base.mDegrees.map{ I in (I, homology(I)) }
        let exList = (base.defaultObject == .zeroModule)
            ? list.exclude { (_, s) in s?.isTrivial ?? false }
            : list
            
        return ModuleGrid(
            name: name ?? "H(\(base.name))",
            default: base.defaultObject,
            list: exList
        )
    }
    
    public var isExact: Bool {
        return homology().isTrivial
    }
    
    // MEMO works only when each generator is a single basis-element.
    
    public func dual(name: String? = nil) -> MChainComplex<Dim, Dual<A>, R> {
        typealias D = MChainComplex<Dim, Dual<A>, R>
        
        let dName = name ?? "\(base.name)^*"
        let dDef = (base.defaultObject == .zeroModule) ? D.Base.Object.zeroModule : nil
        let dList: [(IntList, [Dual<A>]?)] = base.mDegrees.map { I -> (IntList, [Dual<A>]?) in
            guard let o = self[I] else {
                return (I, nil)
            }
            guard o.isFree, o.generators.forAll({ $0.basis.count == 1 }) else {
                fatalError("inavailable")
            }
            return (I, o.generators.map{ $0.basis.first!.dual })
        }
        
        let dBase = D.Base(name: dName, default: dDef, list: dList)
        let dDiff = d.dual(from: self, to: self)
        
        return D(base: dBase, differential: dDiff)
    }
    
    public func assertChainComplex(debug: Bool = false) {
        func print(_ msg: @autoclosure () -> String) {
            Swift.print(msg())
        }
        
        for I0 in base.mDegrees {
            let I1 = I0 + dDegree
            let I2 = I1 + dDegree
            
            guard let s0 = self[I0],
                  let s1 = self[I1],
                  let s2 = self[I2] else {
                    print("\(I0): undeterminable.")
                    continue
            }
            
            print("\(I0): \(s0) -> \(s1) -> \(s2)")
            
            for x in s0.generators {
                let y = d[I0].applied(to: x)
                let z = d[I1].applied(to: y)
                print("\t\(x) ->\t\(y) ->\t\(z)")
                
                assert(s2.elementIsZero(z))
            }
        }
    }
    
    public func describe(_ I: IntList) {
        base.describe(I)
    }
    
    public func describeMap(_ I: IntList) {
        print("\(I) \(self[I]?.description ?? "?") -> \(self[I + dDegree]?.description ?? "?")")
        if let A = dMatrix(I) {
            print(A.detailDescription)
        }
    }
    
    public var description: String {
        return base.description
    }
}

public extension MChainComplex where Dim == _1 {
    public subscript(i: Int) -> Base.Object? {
        get {
            return base[i]
        } set {
            base[i] = newValue
        }
    }
    
    public var bottomDegree: Int {
        return base.bottomDegree
    }
    
    public var topDegree: Int {
        return base.topDegree
    }
    
    public func shifted(_ i: Int) -> ChainComplex<A, R> {
        return shifted(IntList(i))
    }
    
    public func homology(_ i: Int) -> SimpleModuleStructure<A, R>? {
        return homology(IntList(i))
    }
    
    public func describe(_ i: Int) {
        describe(IntList(i))
    }
    
    public func describeMap(_ i: Int) {
        describeMap(IntList(i))
    }
}

public extension MChainComplex where Dim == _2 {
    public subscript(i: Int, j: Int) -> Base.Object? {
        get {
            return base[i, j]
        } set {
            base[i, j] = newValue
        }
    }
    
    public func shifted(_ i: Int, _ j: Int) -> ChainComplex2<A, R> {
        return shifted(IntList(i, j))
    }
    
    public func homology(_ i: Int, _ j: Int) -> SimpleModuleStructure<A, R>? {
        return homology(IntList(i, j))
    }
    
    public func describe(_ i: Int, _ j: Int) {
        describe(IntList(i, j))
    }
    
    public func describeMap(_ i: Int, _ j: Int) {
        describeMap(IntList(i, j))
    }
    
    public func printTable() {
        base.printTable()
    }
}

public extension MChainComplex where R == 𝐙 {
    public var order2torsionPart: MChainComplex<Dim, A, 𝐙₂> {
        return MChainComplex<Dim, A, 𝐙₂>(base: base.order2torsionPart, differential: d.tensor2)
    }
}