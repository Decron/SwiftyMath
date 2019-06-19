//
//  HermiteEliminator.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/11/08.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

internal final class RowHermiteEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    var targetRow = 0
    var rank = 0

    override func prepare() {
        run(RowEchelonEliminator.self)
        rank = target.heads.count{ $0 != nil }
    }
    
    override func isDone() -> Bool {
        return targetRow >= rank
    }
    
    @_specialize(where R == ComputationSpecializedRing)
    override func iteration() {
        let c0 = target.heads[targetRow]!.pointee
        let j0 = c0.index
        let a0 = c0.value
        
        for i in 0 ..< targetRow {
            let a = target[i, j0]
            if a == .zero {
                continue
            }
            
            let q = a / a0
            if q != .zero {
                apply(.AddRow(at: targetRow, to: i, mul: -q))
            }
        }
        
        targetRow += 1
    }
}

internal final class ColHermiteEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    var done = false
    override func isDone() -> Bool {
        return done
    }
    
    override func iteration() {
        runTranpose(RowHermiteEliminator.self)
        done = true
    }
}
