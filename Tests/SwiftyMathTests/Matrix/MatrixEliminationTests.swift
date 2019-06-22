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

class MatrixEliminationTests: XCTestCase {
    
    typealias M = Matrix
    typealias M1 = Matrix1
    typealias M2 = Matrix2
    typealias M5<R: EuclideanRing> = Matrix<_5, _5, R>
    
    override func setUp() {
        super.setUp()
//        MatrixEliminator<𝐙>.debug = true
    }
    
    func testNormalize_Z() {
        let A = M1(-2)
        let B = M1(2)
        let E = A.eliminate()
        XCTAssertEqual(E.result, B)
    }
    
    func testNormalize_Q() {
        let A = M1(-3./1)
        let B = M1(1./1)
        let E = A.eliminate()
        XCTAssertEqual(E.result, B)
    }

    func testZ55_regular() {
        let A = M5(2, -1, -2, -2, -3, 1, 2, -1, 1, -1, 2, -2, -4, -3, -6, 1, 7, 1, 5, 3, 1, -12, -6, -10, -11)
        let B = M5(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1)
        let E = A.eliminate(form: .Smith)

        XCTAssertEqual(E.result, B)
        XCTAssertEqual(E.left * A * E.right, B)
        XCTAssertEqual(E.leftInverse * B * E.rightInverse, A)
    }

    func testZ55_rank4() {
        let A = M5(3, -5, -22, 20, 8, 6, -11, -50, 45, 18, -1, 2, 10, -9, -3, 3, -6, -30, 27, 10, -1, 2, 7, -6, -3)
        let B = M5(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0)
        let E = A.eliminate(form: .Smith)

        XCTAssertEqual(E.result, B)
        XCTAssertEqual(E.left * A * E.right, B)
        XCTAssertEqual(E.leftInverse * B * E.rightInverse, A)
    }

    func testZ55_fullRankWithFactors() {
        let A = M5(-20, -7, -27, 2, 29, 17, 8, 14, -4, -10, 13, 8, 10, -4, -6, -9, -2, -14, 0, 16, 5, 0, 5, -1, -4)
        let B = M5(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 60)
        let E = A.eliminate(form: .Smith)

        XCTAssertEqual(E.result, B)
        XCTAssertEqual(E.left * A * E.right, B)
        XCTAssertEqual(E.leftInverse * B * E.rightInverse, A)
    }

    func testZ55_rank3WithFactors() {
        let A = M5(4, 6, -18, -15, -46, -1, 0, 6, 4, 13, -13, -12, 36, 30, 97, -7, -6, 18, 15, 49, -6, -6, 18, 15, 48)
        let B = M5(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        let E = A.eliminate(form: .Smith)

        XCTAssertEqual(E.result, B)
        XCTAssertEqual(E.left * A * E.right, B)
        XCTAssertEqual(E.leftInverse * B * E.rightInverse, A)
    }

    func testZ46_rank4WithFactors() {
        let A = M<_4, _6, 𝐙>(8, -6, 14, -10, -14, 6, 12, -8, 18, -18, -20, 8, -16, 7, -23, 22, 23, -7, 32, -17, 44, -49, -49, 17)
        let B = M<_4, _6, 𝐙>(1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 12, 0, 0)
        let E = A.eliminate(form: .Smith)

        XCTAssertEqual(E.result, B)
        XCTAssertEqual(E.left * A * E.right, B)
        XCTAssertEqual(E.leftInverse * B * E.rightInverse, A)
    }

    func testZ46_zero() {
        let A = M<_4, _6, 𝐙>.zero
        let E = A.eliminate(form: .Smith)
        XCTAssertEqual(E.result, A)
    }

    func testQ55_regular() {
        let A = M5<𝐐>(-3./1, 0./1, 0./1, -9./2, 0./1, 10./3, 2./1, 0./1, -15./2, 6./1, -10./3, -2./1, 0./1, 15./2, -10./1, 0./1, 0./1, 3./4, -5./1, 0./1, 0./1, 0./1, 1./1, 0./1, 0./1)
        let B = M5<𝐐>(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1)
        let E = A.eliminate(form: .Smith)

        XCTAssertEqual(E.result, B)
        XCTAssertEqual(E.left * A * E.right, B)
        XCTAssertEqual(E.leftInverse * B * E.rightInverse, A)
    }

    func testQ55_rank3() {
        let A = M5<𝐐>(1./1, 1./1, 0./1, 8./3, 10./3, -3./1, 0./1, 0./1, -3./1, -5./1, 2./1, 0./1, 10./3, 2./1, 16./3, 79./8, 0./1, 395./24, 79./8, 79./3, 7./2, 0./1, 35./6, 7./2, 28./3)
        let B = M5<𝐐>(1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        let E = A.eliminate(form: .Smith)

        XCTAssertEqual(E.result, B)
        XCTAssertEqual(E.left * A * E.right, B)
        XCTAssertEqual(E.leftInverse * B * E.rightInverse, A)
    }
    
    public func testKernel() {
        let A = M2(1, 2, 1, 2)
        let E = A.eliminate()
        let K = E.kernelMatrix
        
        XCTAssertEqual(K.rows, 2)
        XCTAssertEqual(K.cols, 1)
        XCTAssertTrue((A * K).isZero)

        let T = E.kernelTransitionMatrix
        XCTAssertEqual(T * K, DMatrix(rows: 1, cols: 1, grid: [1]))
    }

    public func testImage() {
        let A = M2(2, 4, 2, 4)
        let E = A.eliminate()
        let I = E.imageMatrix

        XCTAssertEqual(I.rows, 2)
        XCTAssertEqual(I.cols, 1)
        XCTAssertEqual(I.generateGrid(), [2, 2])
    }
    
    public func testDet() {
        let A = Matrix4(3,-1,2,4,
                        2,1,1,3,
                        -2,0,3,-1,
                        0,-2,1,3)
        let E = A.eliminate()
        XCTAssertEqual(E.determinant, 66)
    }
}
