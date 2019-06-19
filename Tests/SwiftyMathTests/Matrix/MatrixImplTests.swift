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
    
    public func testSwitchFromRow() {
        let a = M22(1,2,3,4)
        a.switchAlignment(.vertical)
        XCTAssertEqual(a, M22(1,2,3,4))
    }
    
    public func testSwitchFromCol() {
        let a = M22c(1,2,3,4)
        a.switchAlignment(.horizontal)
        XCTAssertEqual(a, M22(1,2,3,4))
    }
    
    public func testAddRow() {
        let a = M22(1,2,3,4)
        a.addRow(at: 0, to: 1)
        XCTAssertEqual(a, M22(1,2,4,6))
    }
    
    public func testAddRowWithMul() {
        let a = M22(1,2,3,4)
        a.addRow(at: 0, to: 1, multipliedBy: 2)
        XCTAssertEqual(a, M22(1,2,5,8))
    }
    
    public func testAddCol() {
        let a = M22(1,2,3,4)
        a.addCol(at: 0, to: 1)
        XCTAssertEqual(a, M22(1,3,3,7))
    }
    
    public func testAddColWithMul() {
        let a = M22(1,2,3,4)
        a.addCol(at: 0, to: 1, multipliedBy: 2)
        XCTAssertEqual(a, M22(1,4,3,10))
    }
    
    public func testMulRow() {
        let a = M22(1,2,3,4)
        a.multiplyRow(at: 0, by: 2)
        XCTAssertEqual(a, M22(2,4,3,4))
    }
    
    public func testMulCol() {
        let a = M22(1,2,3,4)
        a.multiplyCol(at: 0, by: 2)
        XCTAssertEqual(a, M22(2,2,6,4))
    }
    
    public func testSwapRows() {
        let a = M22(1,2,3,4)
        a.swapRows(0, 1)
        XCTAssertEqual(a, M22(3,4,1,2))
    }
    
    public func testSwapCols() {
        let a = M22(1,2,3,4)
        a.swapCols(0, 1)
        XCTAssertEqual(a, M22(2,1,4,3))
    }
}
