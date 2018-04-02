import Foundation

public protocol Module: AdditiveGroup {
    associatedtype CoeffRing: Ring
    static func * (r: CoeffRing, m: Self) -> Self
    static func * (m: Self, r: CoeffRing) -> Self
}

public protocol Submodule: Module, AdditiveSubgroup where Super: Module {}

public extension Submodule where CoeffRing == Super.CoeffRing {
    static func * (r: CoeffRing, a: Self) -> Self {
        return Self(r * a.asSuper)
    }
    
    static func * (a: Self, r: CoeffRing) -> Self {
        return Self(a.asSuper * r)
    }
}

public typealias ProductModule<X: Module, Y: Module> = AdditiveProductGroup<X, Y>

extension ProductModule: Module where Left: Module, Right: Module, Left.CoeffRing == Right.CoeffRing {
    public typealias CoeffRing = Left.CoeffRing
    
    public static func * (r: CoeffRing, a: ProductModule<Left, Right>) -> ProductModule<Left, Right> {
        return ProductModule(r * a.left, r * a.right)
    }
    
    public static func * (a: ProductModule<Left, Right>, r: CoeffRing) -> ProductModule<Left, Right> {
        return ProductModule(a.left * r, a.right * r)
    }
    
    public static var symbol: String {
        return "\(Left.symbol)⊕\(Right.symbol)"
    }
}

public typealias QuotientModule<M, N: Submodule> = AdditiveQuotientGroup<M, N> where M == N.Super

extension QuotientModule: Module where Sub: Submodule {
    public typealias CoeffRing = Base.CoeffRing
    
    public static func * (r: CoeffRing, a: QuotientModule<Base, Sub>) -> QuotientModule<Base, Sub> {
        return QuotientModule(r * a.representative)
    }
    
    public static func * (a: QuotientModule<Base, Sub>, r: CoeffRing) -> QuotientModule<Base, Sub> {
        return QuotientModule(a.representative * r)
    }
}
