//
//  PolynomialRootTests.swift
//  SwiftyMathTests
//
//  Created by Taketo Sano on 2019/06/12.
//

import XCTest
@testable import SwiftyMath

class PolynomialRootTests: XCTestCase {

    typealias P = xPolynomial<𝐂>
    
    func testExample() {
        let f = P(coeffs: 1, 0, 1)
        let i = 𝐂.imaginaryUnit
        let zs = f.findAllRoots()
        XCTAssertEqual(zs.count, 2)
        XCTAssertTrue(zs.contains(i))
        XCTAssertTrue(zs.contains(-i))
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
