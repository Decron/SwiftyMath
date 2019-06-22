//
//  EchelonEliminator.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/11/08.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

internal final class RowEchelonEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    var currentRow = 0
    var currentCol = 0
    
    override func prepare() {
        target.switchAlignment(.horizontal)
    }
    
    override func isDone() -> Bool {
        return currentRow >= target.rows || currentCol >= target.cols
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    override func iteration() {
        
        // find pivot point
        let elements = targetColElements()
        guard let pivot = findPivot(in: elements) else {
            currentCol += 1
            return
        }
        
        let i0 = pivot.0
        var a0 = pivot.1
        
        if a0.normalizeUnit != .identity {
            apply(.MulRow(at: i0, by: a0.normalizeUnit))
            a0 = a0.normalized
        }
        
        // eliminate target col
        
        var again = false
        
        for (i, a) in elements where i != i0 {
            let (q, r) = a /% a0
            apply(.AddRow(at: i0, to: i, mul: -q))
            
            if r != .zero {
                again = true
            }
        }
        
        if again {
            return
        }
        
        // final step
        
        if i0 != currentRow {
            apply(.SwapRows(i0, currentRow))
        }
        
        currentRow += 1
        currentCol += 1
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    private func targetColElements() -> [(Int, R)] {
        // Take (i, a)'s from table = [ i : [ (j, a) ] ] where (i >= targetRow && j == targetCol)
        return (currentRow ..< target.rows).compactMap{ i -> (Int, R)? in
            guard let c = target.heads[i]?.pointee, c.index == currentCol else {
                return nil
            }
            return (i, c.value)
        }
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    private func findPivot(in candidates: [(Int, R)]) -> (Int, R)? {
        return candidates.first { $0.1.isInvertible } ?? candidates.min { $0.1.eucDegree < $1.1.eucDegree }
    }
}

internal final class ColEchelonEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    var done = false
    override func isDone() -> Bool {
        return done
    }
    
    override func iteration() {
        runTranpose(RowEchelonEliminator.self)
        done = true
    }
}
