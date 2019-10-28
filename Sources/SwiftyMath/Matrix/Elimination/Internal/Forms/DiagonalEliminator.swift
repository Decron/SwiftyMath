//
//  DiagonalEliminator.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/11/08.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

final class DiagonalEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    override func prepare() {
        log("Find pivots...")
        
        if debug {
            printCurrentMatrix()
        }
        
        let pf = MatrixPivotFinder(size: size, components: components, debug: debug)
        let pivots = pf.start()
        
        log("\(pivots.count) pivots found.")
        
        let rowP = pf.asPermutation(pivots.map{ $0.0 }, size.rows)
        let colP = pf.asPermutation(pivots.map{ $0.1 }, size.cols)
        
        setComponents(components.map { (i, j, a) in
            (rowP[i], colP[j], a)
        })
        
        if debug {
            printCurrentMatrix()
        }
        
        self.rowPermutation = rowP
        self.colPermutation = colP
    }
    
    override func isDone() -> Bool {
        components.allSatisfy { (i, j, a) in
            (i == j) && a.isNormalized
        }
    }
    
    override func iteration() {
        subrun(RowEchelonEliminator.self)
        if !isDone() {
            subrun(ColEchelonEliminator.self)
        }
    }
}
