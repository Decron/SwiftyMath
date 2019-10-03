//
//  Permutation.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2018/03/12.
//  Copyright © 2018年 Taketo Sano. All rights reserved.
//

public typealias DPermutation = Permutation<DynamicSize>

public struct Permutation<n: SizeType>: Group, MapType { // SymmetricGroup<n>
    public typealias Domain = Int
    public typealias Codomain = Int
    
    internal var elements: [Int : Int]
    
    public init(_ f: @escaping (Int) -> Int) {
        assert(!n.isDynamic)
        let elements = (0 ... n.intValue).map{ i in (i, f(i)) }
        self.init(Dictionary(pairs: elements))
    }
    
    public init<S: Sequence>(_ sequence: S) where S.Element == Int {
        let dict = Dictionary(pairs: sequence.enumerated().map{ ($0, $1) })
        self.init(dict)
    }
    
    public init(_ elements: [Int: Int]) {
        assert(Set(elements.keys) == Set(elements.values))
        self.elements = elements.filter{ (k, v) in k != v }
    }
    
    public static func cyclic(_ elements: [Int]) -> Permutation {
        var d = [Int : Int]()
        let l = elements.count
        for (i, a) in elements.enumerated() {
            d[a] = elements[(i + 1) % l]
        }
        return .init(d)
    }
    
    public static func cyclic(_ elements: Int...) -> Permutation {
        cyclic(elements)
    }
    
    public static func transposition(_ i: Int, _ j: Int) -> Permutation {
        .init([i : j, j : i])
    }

    public static var identity: Permutation {
        Permutation([:])
    }
    
    public var inverse: Permutation? {
        let inv = elements.map{ (i, j) in (j, i)}
        return Permutation(Dictionary(pairs: inv))
    }
    
    public subscript(i: Int) -> Int {
        elements[i] ?? i
    }
    
    public func applied(to i: Int) -> Int {
        self[i]
    }
    
    public func applied(to I: [Int]) -> [Int] {
        I.map{ applied(to: $0) }
    }
    
    // memo: the number of transpositions in it's decomposition.
    public var signature: Int {
        // the sign of a cyclic-perm of length l (l >= 2) is (-1)^{l - 1}
        let decomp = cyclicDecomposition
        return decomp.multiply { p in (-1).pow( p.elements.count - 1) }
    }
    
    public var cyclicDecomposition: [Permutation] {
        var dict = elements
        var result: [Permutation] = []
        
        while !dict.isEmpty {
            let i = dict.keys.anyElement!
            var c: [Int] = []
            var x = i
            
            while !c.contains(x) {
                c.append(x)
                x = dict.removeValue(forKey: x)!
            }
            
            if c.count > 1 {
                let p = Permutation.cyclic(c)
                result.append(p)
            }
        }
        
        return result
    }
    
    public static func *(a: Permutation, b: Permutation) -> Permutation {
        var d = a.elements
        for i in b.elements.keys {
            d[i] = a[b[i]]
        }
        return Permutation(d)
    }
    
    public var description: String {
        elements.isEmpty
            ? "id"
            : "p[\(elements.keys.sorted().map{ i in "\(i): \(self[i])"}.joined(separator: ", "))]"
    }
    
    public static var symbol: String {
        "S_\(n.intValue)"
    }
}

extension Permutation: FiniteSetType where n: StaticSizeType {
    public static var allElements: [Permutation] {
        DPermutation.rawPermutations(length: n.intValue).map{ Permutation($0) }
    }
    
    public static var countElements: Int {
        n.intValue.factorial
    }
}

extension Permutation where n == DynamicSize {
    
    // MEMO Heap's algorithm: https://en.wikipedia.org/wiki/Heap%27s_algorithm
    public static func rawPermutations(length n: Int) -> [[Int]] {
        assert(n >= 0)
        
        func generate(_ k: Int, _ arr: inout [Int], _ result: inout [[Int]]) {
            if k == 1 {
                result.append(arr)
            } else {
                generate(k - 1, &arr, &result)
                for i in 0 ..< k - 1 {
                    let swap = k.isEven ? (i, k - 1) : (0, k - 1)
                    arr.swapAt(swap.0, swap.1)
                    generate(k - 1, &arr, &result)
                }
            }
        }
        
        var arr = (0 ..< n).toArray()
        var result: [[Int]] = []
        
        generate(n, &arr, &result)
        
        return result
    }

    public static func permutations(length n: Int) -> [DPermutation] {
        DPermutation.rawPermutations(length: n).map{ DPermutation($0) }
    }
    
    public static func rawTranspositions(within n: Int) -> [(Int, Int)] {
        if n <= 1 {
            return []
        }
        return (0 ..< n - 1).flatMap { i in
            (i + 1 ..< n).map{ j in (i, j) }
        }
    }
    
    public static func transpositions(within n: Int) -> [DPermutation] {
        rawTranspositions(within: n).map{ (i, j) in
            DPermutation.transposition(i, j)
        }
    }
}

extension Array where Element: Hashable {
    public func permuted<n>(by p: Permutation<n>) -> Array {
        (0 ..< count).map{ i in self[p[i]] }
    }
}
