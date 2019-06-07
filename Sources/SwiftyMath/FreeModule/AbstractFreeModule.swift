//
//  AbstractFreeModule.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2019/06/05.
//

import Foundation

public struct AbstractGenerator: FreeModuleGenerator, Codable {
    public let index: Int
    internal init(_ index: Int) {
        self.index = index
    }
    
    public static func < (lhs: AbstractGenerator, rhs: AbstractGenerator) -> Bool {
        return lhs.index < rhs.index
    }
    
    public var description: String {
        return "e\(Format.sub(index))"
    }
}

public typealias AbstractFreeModule<R: Ring> = FreeModule<AbstractGenerator, R>
public typealias AbstractVectorSpace<F: Field> = AbstractFreeModule<F>

extension FreeModule where A == AbstractGenerator {
    public static func generators(count: Int) -> [AbstractGenerator] {
        return generators(indexRange: 0 ... count - 1)
    }
    
    public static func generators(indexRange: ClosedRange<Int>) -> [AbstractGenerator] {
        return indexRange.map{ A($0) }
    }
}
