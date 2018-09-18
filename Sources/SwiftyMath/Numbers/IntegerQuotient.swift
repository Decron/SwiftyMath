//
//  IntegerQuotient.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2018/04/01.
//  Copyright © 2018年 Taketo Sano. All rights reserved.
//

import Foundation

public typealias 𝐙₂ = IntegerQuotientRing<_2>

public struct IntegerIdeal<n: _Int>: EuclideanIdeal {
    public typealias Super = 𝐙
    public static var mod: 𝐙 {
        return n.intValue
    }
}

extension IntegerIdeal: MaximalIdeal where n: _Prime {}

public struct IntegerQuotientRing<n: _Int>: QuotientRingType, FiniteSetType, ExpressibleByIntegerLiteral, Codable {
    public typealias Base = 𝐙
    public typealias Sub = IntegerIdeal<n>
    
    public let value: 𝐙
    public init(_ value: 𝐙) {
        let mod = n.intValue
        self.value = (value >= 0) ? value % mod : (value % mod + mod)
    }
    
    public init(integerLiteral value: 𝐙) {
        self.init(value)
    }
    
    public var representative: 𝐙 {
        return value
    }
    
    public static var mod: 𝐙 {
        return n.intValue
    }
    
    public static var allElements: [IntegerQuotientRing<n>] {
        return (0 ..< mod).map{ IntegerQuotientRing($0) }
    }
    
    public static var countElements: Int {
        return mod
    }
    
    public static var symbol: String {
        return "𝐙\(Format.sub(mod))"
    }
}

extension IntegerQuotientRing: EuclideanRing, Field where n: _Prime {}
