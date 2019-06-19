//
//  RowSortedMatrix.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/10/16.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

private var _debug: Bool = false

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
    
    private let bufferLength: Int
    private var bufferHeads: [LinkedComponent.Pointer]
    private var currentPtr: LinkedComponent.Pointer
    private var currentIdx: Int
    private var prevAppend: LinkedComponent.Pointer?
    
    convenience init(rows: Int, cols: Int, align: Alignment = .horizontal) {
        self.init(rows: rows, cols: cols, align: align, components: [])
    }
    
    init<S: Sequence>(rows: Int, cols: Int, align: Alignment = .horizontal, components: S) where S.Element == MatrixComponent<R> {
        self.rows = rows
        self.cols = cols
        self.align = align
        self.heads = []
        
        self.bufferLength = max(rows, cols) * 10 // TODO
        self.bufferHeads = []
        
        let dummy = LinkedComponent.Pointer.allocate(capacity: 1)
        self.currentPtr = dummy
        self.currentIdx = 0
        
        realign(align, components)
        
        dummy.deallocate()
    }
    
    deinit {
        deallocateBuffers()
    }
    
    private func allocateBuffer() {
        let p = LinkedComponent.Pointer.allocate(capacity: bufferLength)
        bufferHeads.append(p)
        currentPtr = p
        currentIdx = 0
        log("allocate \(bufferLength) at \(currentPtr)")
    }
    
    private func assureBuffer(_ length: Int) {
        if currentIdx + length >= bufferLength {
            allocateBuffer()
        }
    }
    
    private func realign<S: Sequence>(_ align: Alignment, _ components: S) where S.Element == MatrixComponent<R> {
        // MEMO this must be done first, since `components` may internally point to allocated memories.
        let group = components.group{ align.isHorizontal ? $0.row : $0.col }
        
        deallocateBuffers()
        allocateBuffer()
        
        heads = Array(repeating: nil, count: align.isHorizontal ? rows : cols)
        
        for (i, list) in group {
            initializeRow(i, list.count)
            
            for c in list {
                let j = (align.isHorizontal) ? c.col : c.row
                append(i, j, c.value)
            }
            
            finalizeRow(i)
        }
        self.align = align
    }
    
    private func initializeRow(_ i: Int, _ length: Int) {
        assert(prevAppend == nil)
        
        heads[i] = nil
        assureBuffer(length)
    }
    
    @discardableResult
    private func append(_ i: Int, _ j: Int, _ value: R) -> LinkedComponent.Pointer? {
        guard value != .zero else {
            return nil
        }
        
        defer {
            currentPtr += 1
            currentIdx += 1
            assert(currentIdx < bufferLength)
        }
        
        prevAppend?.pointee.hasNext = true
        
        currentPtr.initialize(to: LinkedComponent(j, value))
        if heads[i] == nil {
            heads[i] = currentPtr
        }
        
        prevAppend = currentPtr
        
        log("add: \(currentPtr): \((i, j, value))")
        
        return currentPtr
    }
    
    private func finalizeRow(_ i: Int) {
        prevAppend = nil
    }
    
    private func deallocateBuffers() {
        for p in bufferHeads {
            p.deinitialize(count: bufferLength)
            p.deallocate()
            log("deallocate \(bufferLength) at \(p)")
        }
        bufferHeads.removeAll()
    }
    
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
            let p = LinkedComponent.Pointer.allocate(capacity: 1)
            p.initialize(to: LinkedComponent(j, newValue - self[row, col]))
            mergeRows(i, heads[i], p, (+))
            p.deallocate()
        }
    }
    
    func copy() -> MatrixImpl<R> {
        return mapComponents{ $0 }
    }
    
    func switchAlignment(_ align: Alignment) {
        if self.align != align {
            self.realign(align, IteratorSequence(iterator()))
        }
    }
    
    func iterator() -> Iterator {
        return Iterator(align, heads)
    }
    
    func rowIterator(_ i: Int) -> RowIterator {
        switchAlignment(.horizontal)
        return RowIterator(align, i, heads[i])
    }
    
    func colIterator(_ i: Int) -> RowIterator {
        switchAlignment(.vertical)
        return RowIterator(align, i, heads[i])
    }
    
    var allComponents: [MatrixComponent<R>] {
        return IteratorSequence(iterator()).sorted{ (c1, c2) in
            (c1.row < c2.row) || (c1.row == c2.row && c1.col < c2.col)
        }
    }
    
    func generateGrid() -> [R] {
        var grid = Array(repeating: R.zero, count: rows * cols)
        for c in allComponents {
            grid[c.row * cols + c.col] = c.value
        }
        return grid
    }
    
    @discardableResult
    func transpose() -> MatrixImpl<R> {
        (rows, cols) = (cols, rows)
        align = (align.isHorizontal) ? .vertical : .horizontal
        return self
    }
    
    func mapComponents<R2>(_ f: (R) -> R2) -> MatrixImpl<R2> {
        let res = MatrixImpl<R2>(rows: rows, cols: cols, align: align.isHorizontal ? .horizontal : .vertical, components: [])
        for (i, head) in heads.enumerated() where head != nil {
            res.initializeRow(i, cols)
            var p = head
            while let c = p?.pointee {
                res.append(i, c.index, f(c.value))
                proceed(&p)
            }
            res.finalizeRow(i)
        }
        return res
    }
    
    static func ==(a: MatrixImpl, b: MatrixImpl) -> Bool {
        if (a.rows, a.cols) != (b.rows, b.cols) {
            return false
        }
        let aComps = a.allComponents
        let bComps = b.allComponents
        return (aComps.count == bComps.count) && zip(aComps, bComps).allSatisfy{ $0 == $1 }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    static func +(a: MatrixImpl, b: MatrixImpl) -> MatrixImpl<R> {
        assert( (a.rows, a.cols) == (b.rows, b.cols) )
        b.switchAlignment(a.align)
        
        let c = MatrixImpl(rows: a.rows, cols: a.cols, align: a.align, components: [])
        for i in 0 ..< a.rows {
            c.mergeRows(i, a.heads[i], b.heads[i], (+))
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
            c.initializeRow(i, c.cols)
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
                c.append(i, j, r)
            }
            c.finalizeRow(i)
        }
        
        return c
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    func multiplyRow(at i0: Int, by r: R) {
        switchAlignment(.horizontal)
        
        guard R.self == Int.self || R.isField else {
            fatalError()
        }
        
        var p = heads[i0]
        while let a = p?.pointee.value {
            p!.pointee.value = r * a
            proceed(&p)
        }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    func addRow(at i: Int, to j: Int, multipliedBy r: R = .identity) {
        switchAlignment(.horizontal)
        mergeRows(j, heads[i], heads[j], { r * $0 + $1 })
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    private func mergeRows(_ i: Int, _ row1: LinkedComponent.Pointer?, _ row2: LinkedComponent.Pointer?, _ f: (R, R) -> R) {
        initializeRow(i, align.isHorizontal ? cols : rows)
        
        var (p1, p2) = (row1, row2)
        
        while let e1 = p1?.pointee, let e2 = p2?.pointee {
            let (j1, j2) = (e1.index, e2.index)
            let (a1, a2) = (e1.value, e2.value)
            if j1 == j2 {
                append(i, j1, f(a1, a2))
                proceed(&p1)
                proceed(&p2)
                
            } else if j1 < j2 {
                append(i, j1, f(a1, .zero))
                proceed(&p1)
                
            } else if j1 > j2 {
                append(i, j2, f(.zero, a2))
                proceed(&p2)
            }
        }
        
        while let e1 = p1?.pointee {
            let (j1, a1) = (e1.index, e1.value)
            append(i, j1, f(a1, .zero))
            proceed(&p1)
        }
        while let e2 = p2?.pointee {
            let (j2, a2) = (e2.index, e2.value)
            append(i, j2, f(.zero, a2))
            proceed(&p2)
        }
        
        finalizeRow(i)
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
    
    struct RowIterator: IteratorProtocol {
        typealias Element = MatrixComponent<R>
        let align: Alignment
        var index: Int
        var currentPtr: LinkedComponent.Pointer?
        
        init(_ align: Alignment, _ index: Int, _ head: LinkedComponent.Pointer?) {
            self.align = align
            self.index = index
            self.currentPtr = head
        }
        
        mutating func next() -> MatrixComponent<R>? {
            guard let current = currentPtr?.pointee else {
                return nil
            }
            
            defer {
                if current.hasNext {
                    currentPtr = currentPtr! + 1
                } else {
                    currentPtr = nil
                }
            }
            
            return (align.isHorizontal)
                ? (index, current.index, current.value)
                : (current.index, index, current.value)
        }
    }
    
    struct Iterator: IteratorProtocol {
        typealias Element = MatrixComponent<R>
        let align: Alignment
        let heads: [LinkedComponent.Pointer?]
        var index: Int
        var rowIterator: RowIterator?
        
        init(_ align: Alignment, _ heads: [LinkedComponent.Pointer?]) {
            self.align = align
            self.heads = heads
            self.index = 0
            self.rowIterator = nil
        }
        
        mutating func next() -> MatrixComponent<R>? {
            if rowIterator != nil {
                if let next = rowIterator!.next() {
                    return next
                } else {
                    rowIterator = nil
                    index += 1
                }
            }
            
            while index < heads.count && heads[index] == nil {
                index += 1
            }

            if index < heads.count {
                rowIterator = RowIterator(align, index, heads[index])
                return rowIterator?.next()
            } else {
                return nil
            }
        }
    }
    
    private func log(_ s: @autoclosure () -> String) {
        if _debug {
            print(s())
        }
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

extension MatrixImpl {
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
            return nilIfZero(a).map{ a in (i, j, a) }
        }
        self.init(rows: rows, cols: cols, align: align, components: components)
    }
    
    var isZero: Bool {
        return heads.allSatisfy{ $0 == nil }
    }
    
    var isDiagonal: Bool {
        fatalError()
    }
    
    var isIdentity: Bool {
        fatalError()
    }
    
    static func identity(size n: Int, align: Alignment) -> MatrixImpl<R> {
        let components = (0 ..< n).map{ i in MatrixComponent(i, i, R.identity)}
        return MatrixImpl(rows: n, cols: n, align: align, components: components)
    }
    
    var trace: R {
        assert(rows == cols)
        fatalError()
    }
    
    var determinant: R {
        assert(rows == cols)
        if rows == 0 {
            return .identity
        }
        
        fatalError()
        //        guard let row = table[0] else {
        //            return .zero
        //        }
        //
        //        return row.sum{ (j, a) in
        //            let minor = (align == .horizontal)
        //                ? submatrix({ $0 != 0 }, { $0 != j })
        //                : submatrix({ $0 != j }, { $0 != 0 })
        //            return R(from: (-1).pow(j)) * a * minor.determinant
        //        }
    }
    
    func cofactor(_ i: Int, _ j: Int) -> R {
        fatalError()
        
        //        assert(rows == cols)
        //        let ε = R(from: (-1).pow(i + j))
        //        let d = submatrix({ $0 != i }, { $0 != j }).determinant
        //        return ε * d
    }
    
    var inverse: MatrixImpl<R>? {
        assert(rows == cols)
        
        guard let dInv = determinant.inverse else {
            return nil
        }
        return dInv * MatrixImpl(rows: rows, cols: cols) { (i, j) in self.cofactor(j, i) }
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
        
        return submatrix({i in rowRange.contains(i)}, {j in colRange.contains(j)})
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    func submatrix(_ rowCond: (Int) -> Bool, _ colCond: (Int) -> Bool) -> MatrixImpl<R> {
        fatalError()
        //        let (sRows, sCols, iList, jList): (Int, Int, [Int], [Int])
        //
        //        switch align {
        //        case .horizontal:
        //            (iList, jList) = ((0 ..< rows).filter(rowCond), (0 ..< cols).filter(colCond))
        //            (sRows, sCols) = (iList.count, jList.count)
        //        case .vertical:
        //            (iList, jList) = ((0 ..< cols).filter(colCond), (0 ..< rows).filter(rowCond))
        //            (sRows, sCols) = (jList.count, iList.count)
        //        }
        //
        //        let subTable = table.compactMap{ (i, list) -> (Int, [(Int, R)])? in
        //            guard let i1 = iList.binarySearch(i) else {
        //                return nil
        //            }
        //            let subList = list.compactMap{ (j, a) -> (Int, R)? in
        //                guard let j1 = jList.binarySearch(j) else {
        //                    return nil
        //                }
        //                return (j1, a)
        //            }
        //            return !subList.isEmpty ? (i1, subList) : nil
        //        }
        //
        //        return MatrixImpl(sRows, sCols, align, Dictionary(pairs: subTable))
    }
    
    func concatDiagonally(_ B: MatrixImpl<R>) -> MatrixImpl<R> {
        fatalError()
    }
    
    func concatHorizontally(_ B: MatrixImpl<R>) -> MatrixImpl<R> {
        fatalError()
    }
    
    func concatVertically(_ B: MatrixImpl<R>) -> MatrixImpl<R> {
        fatalError()
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

@inlinable
func nilIfZero<R: Ring>(_ r: R?) -> R? {
    return (r == .zero) ? nil : r
}

fileprivate func proceed<R>(_ p: inout MatrixImpl<R>.LinkedComponent.Pointer?) {
    if let e = p?.pointee, e.hasNext {
        p! += 1
    } else {
        p = nil
    }
}
