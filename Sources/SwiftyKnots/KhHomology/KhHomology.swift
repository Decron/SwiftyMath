//
//  KhHomology.swift
//  SwiftyKnots
//
//  Created by Taketo Sano on 2018/04/04.
//

import Foundation
import SwiftyMath

public extension Link {
    public func KhHomology<R: EuclideanRing>(_ type: R.Type) -> SwiftyKnots.KhHomology<R> {
        return SwiftyKnots.KhHomology<R>(self)
    }
    
    public func KhHomology<R: EuclideanRing & Codable>(_ type: R.Type, useCache: Bool) -> SwiftyKnots.KhHomology<R> {
        if useCache {
            let id = "Kh_\(name)_\(R.symbol)"
            return Storage.useCache(id) { self.KhHomology(R.self) }
        } else {
            return self.KhHomology(R.self)
        }
    }
}

public struct KhHomology<R: EuclideanRing> {
    public typealias Inner = Cohomology<KhTensorElement, R>
    public typealias Summand = Inner.Summand
    
    public let link: Link
    
    internal let cube: KhCube
    internal let H: Inner
    
    public init(_ link: Link) {
        let name = "Kh(\(link.name); \(R.symbol))"
        let cube = link.KhCube
        let C = link.KhChainComplex(cube, R.self)
        let H = Inner(name: name, chainComplex: C)
        
        self.init(link, cube, H)
    }
    
    internal init(_ link: Link, _ cube: KhCube, _ H: Inner) {
        self.link = link
        self.cube = cube
        self.H = H
    }
    
    public subscript(i: Int) -> Summand {
        return H[i]
    }

    public subscript(i: Int, j: Int) -> Summand {
        let s = self[i]
        let filtered = s.summands.enumerated().compactMap{ (k, s) in
            (s.degree == j) ? k : nil
        }
        
        return s.subSummands(indices: filtered)
    }
    
    public var offset: Int {
        return H.offset
    }
    
    public var topDegree: Int {
        return H.topDegree
    }
    
    public var validDegrees: [(Int, Int)] {
        return (H.offset ... H.topDegree).flatMap { i in
            self[i].summands.map{ $0.generator.degree }.unique().sorted().map{ j in (i, j) }
        }
    }
    
    public var bandWidth: Int {
        return validDegrees.map{ (i, j) in j - 2 * i }.unique().count
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
    
    public var freePart: KhHomology<R> {
        let name = "Kh(\(link.name); \(R.symbol))_free"
        return filtered(name) { s in s.isFree }
    }
    
    public var torsionPart: KhHomology<R> {
        let name = "Kh(\(link.name); \(R.symbol))_tor"
        return filtered(name) { s in !s.isFree }
    }
    
    private func filtered(_ name: String, _ condition: (Summand.Summand) -> Bool) -> KhHomology<R> {
        let summands = (H.offset ... H.topDegree).map { i -> Summand in
            let s = H[i]
            let indices = s.summands.enumerated().compactMap { (k, s) in
                condition(s) ? k : nil
            }
            return s.subSummands(indices: indices)
        }
        let Hf = Inner(name: name, offset: H.offset, summands: summands)
        
        return KhHomology(link, cube, Hf)
    }
    
    public var eulerCharacteristic: Int {
        return H.eulerCharacteristic
    }
    
    public var gradedEulerCharacteristic: LaurentPolynomial_x<R> {
        return H.gradedEulerCharacteristic
    }
    
    public var KhLee: KhLeeHomology<R> {
        return KhLeeHomology(self)
    }
    
    public var table: Table<Summand> {
        return Table(components: validDegrees.map{ (i, j) in (i, j, self[i, j]) })
    }
    
    public var structureCode: String {
        return validDegrees.map{ (i, j) in
            let s = self[i, j]
            let f = (s.rank > 0) ? "0\(Format.sup(s.rank))₍\(Format.sub(i)),\(Format.sub(j))₎" : ""
            let t = s.torsionCoeffs.countMultiplicities().map{ (d, r) in
                "\(d)\(Format.sup(r))₍\(Format.sub(i)),\(Format.sub(j))₎"
            }.joined()
            return f + t
        }.joined()
    }
    
    public struct Table<E>: CustomStringConvertible {
        private let components: [IntList : E]
        
        internal init(components: [(Int, Int, E)]) {
            self.components = Dictionary(pairs: components.map{ (IntList($0, $1), $2) })
        }
        
        public subscript(i: Int, j: Int) -> E? {
            return components[IntList(i, j)]
        }
        
        public var description: String {
            guard !components.isEmpty else {
                return ""
            }
            
            let keys = components.keys
            let (I, J) = (keys.map{$0[0]}.unique(), keys.map{$0[1]}.unique())
            let (i0, i1) = (I.min()!, I.max()!)
            let (j0, j1) = (J.min()!, J.max()!)
            
            let cols = (i0 ... i1).toArray()
            let rows = (j0 ... j1).filter{ ($0 - j0).isEven }.reversed().toArray()
            
            return Format.table("j\\i", rows: rows, cols: cols) { (j, i) -> String in
                let s = self[i, j]
                return s.map{ "\($0)" } ?? ""
            }
        }
    }
}

public extension KhHomology where R == 𝐙 {
    public var order2torsionPart: KhHomology<𝐙₂> {
        typealias T = KhHomology<𝐙₂>
        let name = "Kh(\(link.name); \(R.symbol))_𝐙₂"
        let summands = (H.offset ... H.topDegree).map { i -> T.Summand in
            H[i].subSummands(torsion: 2)
        }
        let Hf = T.Inner(name: name, offset: H.offset, summands: summands)
        
        return T(link, cube, Hf)
    }
    
}

extension KhHomology: Codable where R: Codable {
    enum CodingKeys: String, CodingKey {
        case link, H
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.link = try c.decode(Link.self, forKey: .link)
        self.cube = KhCube(link)
        self.H = try c.decode(Inner.self, forKey: .H)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(link, forKey: .link)
        try c.encode(H, forKey: .H)
    }
}
