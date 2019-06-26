//
//  EchelonEliminator.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/11/08.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

public final class RowEchelonEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    var worker: RowEliminationWorker<R>!
    var currentRow = 0
    var currentCol = 0
    
    override var form: Form {
        return .RowEchelon
    }
    
    override func prepare() {
        worker = RowEliminationWorker(from: target.pointee)
    }
    
    override func shouldIterate() -> Bool {
        return !worker.isAllDone
    }
    
    @_specialize(where R == 𝐙)
    override func iteration() {
        
        // find pivot point
        let elements = worker.headElements(col: currentCol)
        guard let pivot = findPivot(in: elements) else {
            currentCol += 1
            return
        }
        
        let i0 = pivot.0
        var a0 = pivot.1
        
        if !a0.isNormalized {
            apply(.MulRow(at: i0, by: a0.normalizingUnit))
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
        
        worker.finished(row: currentRow)
        currentRow += 1
        currentCol += 1
    }
    
    @_specialize(where R == 𝐙)
    private func findPivot(in candidates: [(Int, R)]) -> (Int, R)? {
        return candidates.min { $0.1.eucDegree < $1.1.eucDegree }
    }
    
    override func apply(_ s: MatrixEliminator<R>.ElementaryOperation) {
        worker.apply(s)
        
        if debug {
            target.pointee.data = worker.resultData
        }
        
        super.apply(s)
    }
    
    override func finalize() {
        target.pointee.data = worker.resultData
    }
}

public final class ColEchelonEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    override var form: Form {
        return .ColEchelon
    }

    override func prepare() {
        subrun(RowEchelonEliminator(mode: mode, debug: debug), transpose: true)
        exit()
    }
}
