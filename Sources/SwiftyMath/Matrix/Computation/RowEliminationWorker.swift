//
//  RowSortedMatrix.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/10/16.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

internal final class RowEliminationWorker<R: EuclideanRing>: Equatable {
    var size: (rows: Int, cols: Int)
    
    typealias Table = [Int : LinkedList<(index: Int, value: R)>]
    private var working: Table
    private var result : Table
    
    init<S: Sequence>(size: (Int, Int), components: S) where S.Element == MatrixComponent<R> {
        self.size = size
        self.working = components.group{ c in c.row }
            .mapValues { l in
                let sorted = l.sorted{ c in c.col }.map{ c in (c.col, c.value) }
                return LinkedList.generate(from: sorted)!
        }
        self.result = [:]
        result.reserveCapacity(working.count)
    }
    
    convenience init<n, m>(from matrix: Matrix<n, m, R>) {
        self.init(size: matrix.size, components: matrix)
    }
    
    func headElement(row i: Int) -> (Int, R)? {
        return working[i]?.value
    }
    
    @_specialize(where R == 𝐙)
    func headElements(col j0: Int) -> [(Int, R)] {
        return working.compactMap{ (i, head) -> (Int, R)? in
            let (j, a) = head.value
            return j == j0 ? (i, a) : nil
        }
    }
    
    func apply(_ s: MatrixEliminator<R>.ElementaryOperation) {
        switch s {
        case let .AddRow(i, j, r):
            addRow(at: i, to: j, multipliedBy: r)
        case let .MulRow(i, r):
            multiplyRow(at: i, by: r)
        case let .SwapRows(i, j):
            swapRows(i, j)
        default:
            fatalError()
        }
    }

    @_specialize(where R == 𝐙)
    func multiplyRow(at i: Int, by r: R) {
        assert(r != .zero)
        guard let row = working[i] else {
            return
        }
        for t in row {
            t.value.value = r * t.value.value
        }
    }
    
    func swapRows(_ i: Int, _ j: Int) {
        let r0 = working[i]
        working[i] = working[j]
        working[j] = r0
    }
    
    @_specialize(where R == 𝐙)
    func addRow(at i1: Int, to i2: Int, multipliedBy r: R) {
        guard let fromHead = working[i1] else {
            fatalError("attempt to add from empty row: \(i1)")
        }
        
        guard var toHead = working[i2] else {
            fatalError("attempt to add into empty row: \(i2)")
        }
        
        if fromHead.value.index < toHead.value.index {
            // from: ●-->○-->○----->○-------->
            //   to:            ●------->○--->
            
            toHead = LinkedList((fromHead.value.index, .zero), next: toHead)

            // from: ●-->○-->○----->○-------->
            //   to: ●--------->○------->○--->
        }
        
        var (from, to) = (fromHead, toHead)
        
        while true {
            // At this point, it is assured that
            // `from.value.index >= to.value.index`
            
            // from: ------------->●--->○-------->
            //   to: -->●----->○------------>○--->
            
            while let next = to.next, next.value.index <= from.value.index {
                to = next
            }
            
            // from: ------------->●--->○-------->
            //   to: -->○----->●------------>○--->

            if from.value.index == to.value.index {
                to.value.value = to.value.value + r * from.value.value
            } else {
                let c = LinkedList((index: from.value.index, value: r * from.value.value))
                to.insert(c)
                to = c
            }
            
            // from: ------------->●--->○-------->
            //   to: -->○----->○-->●-------->○--->

            if let next = from.next {
                from = next
                
                // from: ------------->○--->●-------->
                //   to: -->○----->○---●-------->○--->
                
            } else {
                break
            }
        }
        
        let result = toHead.drop{ c in c.value == .zero } // possibly nil
        working[i2] = result
    }
    
    func finished(row i: Int) {
        result[i] = working[i]
        working[i] = nil
    }
    
    var isAllDone: Bool {
        return working.isEmpty
    }
    
    var resultData: MatrixData<R> {
        return Dictionary(pairs: (result + working).flatMap{ (i, list) -> [(MatrixCoord, R)] in
            list.map{ c in
                let (j, a) = c.value
                return (MatrixCoord(i, j), a)
            }
        })
    }
    
    func redo() {
        working = result
        result = [:]
        result.reserveCapacity(working.count)
    }
    
    static func identity(size n: Int) -> RowEliminationWorker<R> {
        let comps = (0 ..< n).map { i in (i, i, R.identity) }
        return RowEliminationWorker(size: (n, n), components: comps)
    }

    // for test
    static func ==(a: RowEliminationWorker, b: RowEliminationWorker) -> Bool {
        return (a.working.keys == b.working.keys) && a.working.keys.allSatisfy{ i in
            var itr1 = a.working[i]!.makeIterator()
            var itr2 = b.working[i]!.makeIterator()
            
            while let c1 = itr1.next(), let c2 = itr2.next() {
                if c1.value != c2.value {
                    return false
                }
            }
            return itr1.next() == nil && itr2.next() == nil
        }
    }
}

