//
//  DiagonalEliminator.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/11/08.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

internal final class DiagonalEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    override func isDone() -> Bool {
        return target.heads.enumerated().allSatisfy{ (i, head) in
            if let c = head?.pointee {
                return c.index == i && c.value.isNormalized && !c.hasNext
            } else {
                return true
            }
        }
    }
    
    override func iteration() {
        run(RowHermiteEliminator.self)
        
        if isDone() {
            return
        }
        
        run(ColHermiteEliminator.self)
    }
}
