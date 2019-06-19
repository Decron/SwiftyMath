//
//  SwiftyMathTests.swift
//  SwiftyMathTests
//
//  Created by Taketo Sano on 2017/05/03.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import XCTest
@testable import SwiftyMath

class DMatrixTests: XCTestCase {
    
    typealias R = 𝐙
    typealias C = MatrixComponent<R>
    
    private func M2(_ a: R, _ b: R, _ c: R, _ d: R) -> DMatrix<R> {
        return DMatrix(rows: 2, cols: 2, grid: [a, b, c, d])
    }
    
    func testDirSum() {
        let a = M2(1,2,3,4)
        let b = M2(5,6,7,8)
        let x = a ⊕ b
        XCTAssertEqual(x, DMatrix(rows: 4, cols: 4, grid:
            [1,2,0,0,
             3,4,0,0,
             0,0,5,6,
             0,0,7,8]
        ))
    }
    
    func testSubmatrix() {
        let a = M2(1,2,3,4)
        
        let a1 = a.submatrix(rowRange: 0 ..< 1)
        XCTAssertEqual(a1, DMatrix(rows: 1, cols: 2, grid: [1, 2]))
        
        let a2 = a.submatrix(colRange: 1 ..< 2)
        XCTAssertEqual(a2, DMatrix(rows: 2, cols: 1, grid: [2, 4]))
        
        let a3 = a.submatrix(rowRange: 1 ..< 2, colRange: 0 ..< 1)
        XCTAssertEqual(a3, DMatrix(rows: 1, cols: 1, grid: [3]))
        
        let a4 = a.submatrix(rowsMatching: { $0 % 2 == 0}, colsMatching: { $0 % 2 != 0})
        XCTAssertEqual(a3, DMatrix(rows: 1, cols: 1, grid: [2]))
    }
    
    func testConcat() {
        let a = M2(1,2,3,4)
        let b = M2(5,6,7,8)

        let x = a.concatVertically(b)
        XCTAssertEqual(x, DMatrix(rows: 4, cols: 2, grid:
            [1,2,
             3,4,
             5,6,
             7,8]
        ))
        
        let y = a.concatHorizontally(b)
        XCTAssertEqual(y, DMatrix(rows: 2, cols: 4, grid:
            [1,2,5,6,
             3,4,7,8]
        ))
    }
}
