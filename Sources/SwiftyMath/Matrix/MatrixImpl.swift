//
//  RowSortedMatrix.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/10/16.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

internal typealias ComputationSpecializedRing = 𝐙

internal final class MatrixImpl<R: Ring>: Hashable, CustomStringConvertible {
    enum Alignment: String, Codable {
        case horizontal, vertical
        var isHorizontal: Bool {
            return self == .horizontal
        }
    }
    
    struct LinkedComponent {
        typealias Pointer = UnsafeMutablePointer<LinkedComponent>
        let index: Int
        var value: R
        var hasNext: Bool
        
        init(_ index: Int, _ value: R) {
            self.index = index
            self.value = value
            self.hasNext = false
        }
    }
    
    var rows: Int
    var cols: Int
    var align: Alignment
    var heads: [LinkedComponent.Pointer?] // pointer to the first element of the rows/cols
    
    private let allocator: MemoryAllocator<LinkedComponent>
    
    init<S: Sequence>(rows: Int, cols: Int, align: Alignment = .horizontal, components: S) where S.Element == MatrixComponent<R> {
        self.rows = rows
        self.cols = cols
        self.align = align
        self.heads = []
        self.allocator = MemoryAllocator(bufferLength: max(rows, cols) * 10)
        
        realign(align, components)
    }
    
    convenience init(rows: Int, cols: Int, align: Alignment = .horizontal, grid: [R]) {
        self.init(rows: rows, cols: cols, align: align) { (i, j) in
            let k = i * cols + j
            return grid.indices.contains(k) ? grid[k] : .zero
        }
    }
    
    convenience init(rows: Int, cols: Int, align: Alignment = .horizontal, generator g: (Int, Int) -> R) {
        let components = (0 ..< rows * cols).compactMap { k -> MatrixComponent<R>? in
            let (i, j) = (k / cols, k % cols)
            let a = g(i, j)
            return (a != .zero) ? (i, j, a) : nil
        }
        self.init(rows: rows, cols: cols, align: align, components: components)
    }
    
    private func realign<S: Sequence>(_ align: Alignment, _ components: S) where S.Element == MatrixComponent<R> {
        // MEMO this must be done first, since `components` may internally point to allocated memories.
        let group = components.group{ align.isHorizontal ? $0.row : $0.col }
        
        allocator.deallocate()
        heads = Array(repeating: nil, count: align.isHorizontal ? rows : cols)
        
        for (i, list) in group {
            generateRow(at: i, reserve: list.count) { append in
                for c in list {
                    let j = (align.isHorizontal) ? c.col : c.row
                    append(j, c.value)
                }
            }
        }
        self.align = align
    }
    
    @discardableResult
    private func generateRow(at i: Int?, reserve length: Int, generator: ((Int, R) -> Void) -> Void) -> LinkedComponent.Pointer? {
        var head: LinkedComponent.Pointer? = nil
        var prev: LinkedComponent.Pointer? = nil
        
        allocator.reserve(length)
        
        generator { (j, value) in
            if value == .zero {
                return
            }
            
            prev?.pointee.hasNext = true
            
            let p = allocator.next()
            p.initialize(to: LinkedComponent(j, value))
            
            if head == nil {
                head = p
            }
            prev = p
        }

        if let i = i {
            heads[i] = head
        }
        return head
    }
    
    @discardableResult
    private func mergeRows(into i: Int?, reserve length: Int, merging row1: LinkedComponent.Pointer?, _ row2: LinkedComponent.Pointer?, _ f: (R, R) -> R) -> LinkedComponent.Pointer? {
        return generateRow(at: i, reserve: length) { append in
            var (p1, p2) = (row1, row2)
            
            while let e1 = p1?.pointee, let e2 = p2?.pointee {
                let (j1, j2) = (e1.index, e2.index)
                let (a1, a2) = (e1.value, e2.value)
                if j1 == j2 {
                    append(j1, f(a1, a2))
                    proceed(&p1)
                    proceed(&p2)
                    
                } else if j1 < j2 {
                    append(j1, f(a1, .zero))
                    proceed(&p1)
                    
                } else if j1 > j2 {
                    append(j2, f(.zero, a2))
                    proceed(&p2)
                }
            }
            
            while let e1 = p1?.pointee {
                let (j1, a1) = (e1.index, e1.value)
                append(j1, f(a1, .zero))
                proceed(&p1)
            }
            while let e2 = p2?.pointee {
                let (j2, a2) = (e2.index, e2.value)
                append(j2, f(.zero, a2))
                proceed(&p2)
            }
        }
    }
    
    // MEMO subscript access is slow for both get / set.
    subscript(row: Int, col: Int) -> R {
        get {
            let (i, j) = align.isHorizontal ? (row, col) : (col, row)
            var p = heads[i]
            while p != nil {
                let c = p!.pointee
                if c.index == j {
                    return c.value
                } else if c.index > j || !c.hasNext {
                    return .zero
                }
                proceed(&p)
            }
            return .zero
        } set {
            let (i, j) = align.isHorizontal ? (row, col) : (col, row)
            let tmp = generateRow(at: nil, reserve: 1) { append in append(j, newValue - self[row, col]) }
            mergeRows(into: i, reserve: align.isHorizontal ? cols : rows, merging: heads[i], tmp, (+))
        }
    }
    
    func switchAlignment(_ align: Alignment) {
        if self.align != align {
            self.realign(align, IteratorSequence(iterator()))
        }
    }
    
    func copy() -> MatrixImpl<R> {
        return mapComponents{ $0 }
    }
    
    static func zero(rows: Int, cols: Int, align: Alignment = .horizontal) -> MatrixImpl<R> {
        return MatrixImpl(rows: rows, cols: cols, align: align, components: [])
    }
    
    static func identity(size n: Int, align: Alignment = .horizontal) -> MatrixImpl<R> {
        let components = (0 ..< n).map{ i in MatrixComponent(i, i, R.identity)}
        return MatrixImpl(rows: n, cols: n, align: align, components: components)
    }
    
    var isZero: Bool {
        return heads.allSatisfy{ $0 == nil }
    }
    
    var isIdentity: Bool {
        return isDiagonal { $0 == .identity }
    }
    
    var isDiagonal: Bool {
        return isDiagonal { _ in true }
    }
    
    private func isDiagonal(satisfying check: (R) -> Bool) -> Bool {
        return heads.enumerated().allSatisfy { (i, ptr) in
            if let head = ptr?.pointee {
                return head.index == i && check(head.value) && !head.hasNext
            } else {
                return check(.zero)
            }
        }
    }
    
    var trace: R {
        assert(rows == cols)
        return (0 ..< rows).sum { i in self[i, i] }
    }
    
    var determinant: R {
        assert(rows == cols)
        if rows == 0 {
            return .identity
        }
        
        let row = IteratorSequence(iterator(forRow: 0))
        return row.sum { (_, j, a) in
            let ε = R(from: (-1).pow(j))
            let minor = self.minor(0, j)
            return ε * a * minor.determinant
        }
    }
    
    var inverse: MatrixImpl<R>? {
        assert(rows == cols)
        
        guard let dInv = determinant.inverse else {
            return nil
        }
        return dInv * MatrixImpl(rows: rows, cols: cols) { (i, j) in
            let ε = R(from: (-1).pow(i + j))
            let a = minor(j, i).determinant
            return ε * a
        }
    }
    
    func minor(_ row: Int, _ col: Int) -> MatrixImpl<R> {
        assert( (0 ..< rows).contains(row) )
        assert( (0 ..< cols).contains(col) )
        
        let res = MatrixImpl.zero(rows: rows - 1, cols: cols - 1, align: align)
        
        let (i0, j0) = align.isHorizontal ? (row, col) : (col, row)
        let l = (align.isHorizontal ? cols : rows) - 1
        
        for (i, head) in heads.enumerated() where head != nil && i != i0 {
            let i1 = (i < i0) ? i : i - 1
            res.generateRow(at: i1, reserve: l) { append in
                var p = head
                while let c = p?.pointee {
                    let j = c.index
                    if j != j0 {
                        let j1 = (j < j0) ? j : j - 1
                        append(j1, c.value)
                    }
                    proceed(&p)
                }
            }
        }
        return res
    }
    
    func submatrix(rowRange: CountableRange<Int>) -> MatrixImpl<R> {
        return submatrix(rowRange, 0 ..< cols)
    }
    
    func submatrix(colRange: CountableRange<Int>) -> MatrixImpl<R> {
        return submatrix(0 ..< rows, colRange)
    }
    
    func submatrix(_ rowRange: CountableRange<Int>, _ colRange: CountableRange<Int>) -> MatrixImpl<R> {
        assert(0 <= rowRange.lowerBound && rowRange.upperBound <= rows)
        assert(0 <= colRange.lowerBound && colRange.upperBound <= cols)
        
        let res = MatrixImpl.zero(rows: rowRange.count, cols: colRange.count, align: align)
        
        let (iRange, jRange) = (align.isHorizontal) ? (rowRange, colRange) : (colRange, rowRange)
        let l = jRange.count
        
        for (i, head) in heads.enumerated() where head != nil && iRange.contains(i) {
            let i1 = i - iRange.lowerBound
            res.generateRow(at: i1, reserve: l) { append in
                var p = head
                while let c = p?.pointee {
                    let j = c.index
                    if jRange.contains(j) {
                        let j1 = j - jRange.lowerBound
                        append(j1, c.value)
                    } else if j >= jRange.upperBound {
                        break
                    }
                    proceed(&p)
                }
            }
        }
        return res
    }
    
    func concatHorizontally(_ B: MatrixImpl<R>) -> MatrixImpl<R> {
        let A = self
        
        A.transpose()
        B.transpose()
        
        let C = A.concatVertically(B)
        
        A.transpose()
        B.transpose()

        return C.transpose()
    }
    
    func concatVertically(_ B: MatrixImpl<R>) -> MatrixImpl<R> {
        let A = self
        assert(A.rows == B.rows)
        
        A.switchAlignment(.horizontal)
        B.switchAlignment(.horizontal)
        
        let C = MatrixImpl.zero(rows: A.rows + B.rows, cols: A.cols, align: .horizontal)
        for i in (0 ..< A.rows) {
            C.mergeRows(into: i, reserve: C.rows, merging: A.heads[i], nil, (+))
        }
        for i in (0 ..< B.rows) {
            C.mergeRows(into: i + A.rows, reserve: C.rows, merging: B.heads[i], nil, (+))
        }
        
        return C
    }
    
    func concatDiagonally(_ B: MatrixImpl<R>) -> MatrixImpl<R> {
        let A = self
        let AO = A.concatVertically(.zero(rows: B.rows, cols: A.cols, align: .horizontal))
        let OB = MatrixImpl.zero(rows: A.rows, cols: B.cols, align: .horizontal).concatVertically(B)
        return AO.concatHorizontally(OB)
    }
    
    func iterator() -> MatrixIterator<R> {
        return MatrixIterator(align, heads)
    }
    
    func iterator(forRow i: Int) -> MatrixRowIterator<R> {
        switchAlignment(.horizontal)
        return MatrixRowIterator(align, i, heads[i])
    }
    
    func iterator(forCol j: Int) -> MatrixRowIterator<R> {
        switchAlignment(.vertical)
        return MatrixRowIterator(align, j, heads[j])
    }
    
    func mapComponents<R2>(_ f: (R) -> R2) -> MatrixImpl<R2> {
        let res = MatrixImpl<R2>.zero(rows: rows, cols: cols, align: self.align.isHorizontal ? .horizontal : .vertical)
        for (i, head) in heads.enumerated() where head != nil {
            let l = align.isHorizontal ? cols : rows
            res.generateRow(at: i, reserve: l) { append in
                var p = head
                while let c = p?.pointee {
                    append(c.index, f(c.value))
                    proceed(&p)
                }
            }
        }
        return res
    }
    
    func generateComponents() -> [MatrixComponent<R>] {
        return IteratorSequence(iterator()).sorted{ (c1, c2) in
            (c1.row < c2.row) || (c1.row == c2.row && c1.col < c2.col)
        }
    }
    
    func generateGrid() -> [R] {
        var grid = Array(repeating: R.zero, count: rows * cols)
        let comps = IteratorSequence(iterator())
        for c in comps {
            grid[c.row * cols + c.col] = c.value
        }
        return grid
    }
    
    static func ==(a: MatrixImpl, b: MatrixImpl) -> Bool {
        if (a.rows, a.cols) != (b.rows, b.cols) {
            return false
        }
        let aComps = a.generateComponents()
        let bComps = b.generateComponents()
        return (aComps.count == bComps.count) && zip(aComps, bComps).allSatisfy{ $0 == $1 }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func +(a: MatrixImpl, b: MatrixImpl) -> MatrixImpl<R> {
        assert( (a.rows, a.cols) == (b.rows, b.cols) )
        b.switchAlignment(a.align)
        
        let c = MatrixImpl.zero(rows: a.rows, cols: a.cols, align: a.align)
        for i in 0 ..< a.rows {
            c.mergeRows(into: i, reserve: a.cols, merging: a.heads[i], b.heads[i], (+))
        }
        return c
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static prefix func -(a: MatrixImpl) -> MatrixImpl<R> {
        return a.mapComponents{ -$0 }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func *(r: R, a: MatrixImpl) -> MatrixImpl<R> {
        return a.mapComponents{ r * $0 }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func *(a: MatrixImpl, r: R) -> MatrixImpl<R> {
        return a.mapComponents{ $0 * r }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func *(a: MatrixImpl, b: MatrixImpl) -> MatrixImpl<R> {
        assert(a.cols == b.rows)
        
        a.switchAlignment(.horizontal)
        b.switchAlignment(.vertical)
        
        let c = MatrixImpl(rows: a.rows, cols: b.cols, align: .horizontal, components: [])
        
        let I = (0 ..< a.rows).filter { i in a.heads[i] != nil }
        let J = (0 ..< b.cols).filter { j in b.heads[j] != nil }
        
        for i in I {
            c.generateRow(at: i, reserve: c.cols) { append in
                for j in J {
                    var r = R.zero
                    var (p, q) = (a.heads[i], b.heads[j])
                    while let x = p?.pointee, let y = q?.pointee {
                        if x.index == y.index {
                            r = r + x.value * y.value
                            proceed(&p)
                            proceed(&q)
                        } else if x.index < y.index {
                            proceed(&p)
                        } else if x.index > y.index {
                            proceed(&q)
                        }
                    }
                    append(j, r)
                }
            }
        }
        
        return c
    }
    
    @discardableResult
    func transpose() -> MatrixImpl<R> {
        (rows, cols) = (cols, rows)
        align = (align.isHorizontal) ? .vertical : .horizontal
        return self
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    func multiplyRow(at i: Int, by r: R) {
        switchAlignment(.horizontal)
        
        if r != .zero && (R.self == Int.self || R.isField) {
            var p = heads[i]
            while let a = p?.pointee.value {
                p!.pointee.value = r * a
                proceed(&p)
            }
        } else {
            mergeRows(into: i, reserve: cols, merging: heads[i], nil, { (a, _) in r * a })
        }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    func addRow(at i: Int, to j: Int, multipliedBy r: R = .identity) {
        switchAlignment(.horizontal)
        mergeRows(into: j, reserve: cols, merging: heads[i], heads[j], { r * $0 + $1 })
    }
    
    func swapRows(_ i0: Int, _ i1: Int) {
        switchAlignment(.horizontal)
        
        let p0 = heads[i0]
        heads[i0] = heads[i1]
        heads[i1] = p0
    }
    
    func multiplyCol(at j0: Int, by r: R) {
        transpose()
        multiplyRow(at: j0, by: r)
        transpose()
    }
    
    func addCol(at j0: Int, to j1: Int, multipliedBy r: R = .identity) {
        transpose()
        addRow(at: j0, to: j1, multipliedBy: r)
        transpose()
    }
    
    func swapCols(_ j0: Int, _ j1: Int) {
        transpose()
        swapRows(j0, j1)
        transpose()
    }
    
    var hashValue: Int {
        return isZero ? 0 : 1 // TODO
    }
    
    public var description: String {
        let grid = generateGrid()
        let res = (0 ..< rows).map { i -> String in
            (0 ..< cols).map { j -> String in
                grid[i * cols + j].description
            }.joined(separator: ", ")
        }.joined(separator: "; ")
        return "[\(res)]"
    }
    
    public var detailDescription: String {
        if (rows, cols) == (0, 0) {
            return "[]"
        } else if rows == 0 {
            return "[" + String(repeating: "\t,", count: cols - 1) + "\t]"
        } else if cols == 0 {
            return "[" + String(repeating: "\t;", count: rows - 1) + "\t]"
        } else {
            let grid = generateGrid()
            let res = (0 ..< rows).map { i -> String in
                (0 ..< cols).map { j -> String in
                    grid[i * cols + j].description
                }.joined(separator: ", ")
            }.joined(separator: ",\n\t")
            return "[\t\(res)]"
        }
    }
}

extension MatrixImpl: Codable where R: Codable {
    enum CodingKeys: String, CodingKey {
        case rows, cols, grid
    }
    
    convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try c.decode(Int.self, forKey: .rows)
        let cols = try c.decode(Int.self, forKey: .cols)
        let grid = try c.decode([R].self, forKey: .grid)
        self.init(rows: rows, cols: cols, align: .horizontal, grid: grid)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rows, forKey: .rows)
        try c.encode(cols, forKey: .cols)
        try c.encode(generateGrid(), forKey: .grid)
    }
}

fileprivate func proceed<R>(_ p: inout MatrixImpl<R>.LinkedComponent.Pointer?) {
    if let e = p?.pointee, e.hasNext {
        p! += 1
    } else {
        p = nil
    }
}
