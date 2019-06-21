//
//  MatrixDecompositionTest.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/05/09.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

import Foundation

import XCTest
@testable import SwiftyMath

class MatrixImplTests: XCTestCase {
    
    private typealias R = 𝐙
    
    private func M22(_ xs: R...) -> MatrixImpl<R> {
        return MatrixImpl(rows: 2, cols: 2, grid: xs)
    }
    
    private func M22c(_ xs: R...) -> MatrixImpl<R> {
        return MatrixImpl(rows: 2, cols: 2, align: .vertical, grid: xs)
    }
    
    private func M12(_ xs: R...) -> MatrixImpl<R> {
        return MatrixImpl(rows: 1, cols: 2, grid: xs)
    }
    
    private func M21(_ xs: R...) -> MatrixImpl<R> {
        return MatrixImpl(rows: 2, cols: 1, grid: xs)
    }
    
    private func M11(_ xs: R...) -> MatrixImpl<R> {
        return MatrixImpl(rows: 1, cols: 1, grid: xs)
    }
    
    func testEqual() {
        let a = M22(1,2,3,4)
        XCTAssertEqual(a, M22(1,2,3,4))
        XCTAssertNotEqual(a, M22(1,3,2,4))
    }
    
    func testEqual_differentAlign() {
        let a = M22(1,2,3,4)
        let b = M22c(1,2,3,4)
        XCTAssertEqual(a, b)
    }
    
    func testSwitchFromRow() {
        let a = M22(1,2,3,4)
        a.switchAlignment(.vertical)
        XCTAssertEqual(a, M22(1,2,3,4))
    }
    
    func testSwitchFromCol() {
        let a = M22c(1,2,3,4)
        a.switchAlignment(.horizontal)
        XCTAssertEqual(a, M22(1,2,3,4))
    }
    
    func testSubscript() {
        let a = M22(1,2,0,4)
        XCTAssertEqual(a[0, 0], 1)
        XCTAssertEqual(a[0, 1], 2)
        XCTAssertEqual(a[1, 0], 0)
        XCTAssertEqual(a[1, 1], 4)
    }
    
    func testSubscript_c() {
        let a = M22c(1,2,0,4)
        XCTAssertEqual(a[0, 0], 1)
        XCTAssertEqual(a[0, 1], 2)
        XCTAssertEqual(a[1, 0], 0)
        XCTAssertEqual(a[1, 1], 4)
    }
    
    func testSubscriptSet() {
        let a = M22(1,2,0,4)
        a[0, 0] = 0
        a[0, 1] = -1
        a[1, 1] = 2
        XCTAssertEqual(a.generateGrid(), [0, -1, 0, 2])
    }

    func testSubscriptSet_c() {
        let a = M22c(1,2,0,4)
        a[0, 0] = 0
        a[0, 1] = -1
        a[1, 1] = 2
        XCTAssertEqual(a.generateGrid(), [0, -1, 0, 2])
    }

    func testAdd1() {
        let a = M22(1,2,3,4)
        let b = M22(2,3,6,4)
        let c = a + b
        XCTAssertEqual(c, M22(3,5,9,8))
    }
    
    func testAdd2() {
        let a = M22(1,2,3,4)
        let b = M22c(2,3,6,4)
        let c = a + b
        XCTAssertEqual(c, M22(3,5,9,8))
    }
    
    func testAdd3() {
        let a = M22c(1,2,3,4)
        let b = M22(2,3,6,4)
        let c = a + b
        XCTAssertEqual(c, M22(3,5,9,8))
    }
    
    func testAdd4() {
        let a = M22c(1,2,3,4)
        let b = M22c(2,3,6,4)
        let c = a + b
        XCTAssertEqual(c, M22(3,5,9,8))
    }
    
    func testAddRow() {
        let a = M22(1,2,3,4)
        a.addRow(at: 0, to: 1)
        XCTAssertEqual(a, M22(1,2,4,6))
    }
    
    func testAddRowWithMul() {
        let a = M22(1,2,3,4)
        a.addRow(at: 0, to: 1, multipliedBy: 2)
        XCTAssertEqual(a, M22(1,2,5,8))
    }
    
    func testAddCol() {
        let a = M22(1,2,3,4)
        a.addCol(at: 0, to: 1)
        XCTAssertEqual(a, M22(1,3,3,7))
    }
    
    func testAddColWithMul() {
        let a = M22(1,2,3,4)
        a.addCol(at: 0, to: 1, multipliedBy: 2)
        XCTAssertEqual(a, M22(1,4,3,10))
    }
    
    func testMulRow() {
        let a = M22(1,2,3,4)
        a.multiplyRow(at: 0, by: 2)
        XCTAssertEqual(a, M22(2,4,3,4))
    }
    
    func testMulRow_zero() {
        let a = M22(1,2,3,4)
        a.multiplyRow(at: 0, by: 0)
        XCTAssertEqual(a, M22(0,0,3,4))
    }
    
    func testMulCol() {
        let a = M22(1,2,3,4)
        a.multiplyCol(at: 0, by: 2)
        XCTAssertEqual(a, M22(2,2,6,4))
    }
    
    func testMulCol_zero() {
        let a = M22(1,2,3,4)
        a.multiplyCol(at: 0, by: 0)
        XCTAssertEqual(a, M22(0,2,0,4))
    }
    
    func testSwapRows() {
        let a = M22(1,2,3,4)
        a.swapRows(0, 1)
        XCTAssertEqual(a, M22(3,4,1,2))
    }
    
    func testSwapCols() {
        let a = M22(1,2,3,4)
        a.swapCols(0, 1)
        XCTAssertEqual(a, M22(2,1,4,3))
    }
    
    func testSubmatrixRow() {
        let a = M22(1,2,3,4)
        let a1 = a.submatrix(rowRange: 0 ..< 1)
        XCTAssertEqual(a1, M12(1, 2))
    }
    
    func testSubmatrixCol() {
        let a = M22(1,2,3,4)
        let a2 = a.submatrix(colRange: 1 ..< 2)
        XCTAssertEqual(a2, M21(2, 4))
    }
    
    func testSubmatrixBoth() {
        let a = M22(1,2,3,4)
        let a3 = a.submatrix(1 ..< 2, 0 ..< 1)
        XCTAssertEqual(a3, M11(3))
    }
    
    func testConcatHor() {
        let a = M22(1,2,3,4)
        let b = M22(5,6,7,8)
        let y = a.concatHorizontally(b)
        XCTAssertEqual(y, MatrixImpl(rows: 2, cols: 4, grid:
            [1,2,5,6,
             3,4,7,8]
        ))
    }
    
    func testConcatVer() {
        let a = M22(1,2,3,4)
        let b = M22(5,6,7,8)
        
        let x = a.concatVertically(b)
        XCTAssertEqual(x, MatrixImpl(rows: 4, cols: 2, grid:
            [1,2,
             3,4,
             5,6,
             7,8]
        ))
    }
    
    func testConcatDiag() {
        let a = M22(1,2,3,4)
        let b = M22(5,6,7,8)
        let x = a.concatDiagonally(b)
        XCTAssertEqual(x, MatrixImpl(rows: 4, cols: 4, grid:
            [1,2,0,0,
             3,4,0,0,
             0,0,5,6,
             0,0,7,8]
        ))
    }
}
