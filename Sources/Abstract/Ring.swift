import Foundation

public protocol Ring: AdditiveGroup, Monoid, ExpressibleByIntegerLiteral {
    associatedtype IntegerLiteralType = Int
    init(_ intValue: Int)
    
    static var matrixOperation: BaseMatrixOperation<Self> { get }
    static func matrixElimination<n:_Int, m:_Int>(_ A: Matrix<Self, n, m>, mode: MatrixEliminationMode) -> BaseMatrixElimination<Self, n, m>
}

public extension Ring {
    // required init from `ExpressibleByIntegerLiteral`
    public init(integerLiteral value: Int) {
        self.init(value)
    }
    
    public static var zero: Self {
        return Self.init(0)
    }
    
    static var identity: Self {
        return Self.init(1)
    }
    
    static func **(a: Self, n: Int) -> Self {
        return (0 ..< n).reduce(Self.identity){ (res, _) in res * a }
    }
    
    static var matrixOperation: BaseMatrixOperation<Self> {
        return BaseMatrixOperation<Self>.sharedInstance
    }
    
    // must override in subclass
    static func matrixElimination<n:_Int, m:_Int>(_ A: Matrix<Self, n, m>, mode: MatrixEliminationMode) -> BaseMatrixElimination<Self, n, m> {
        return BaseMatrixElimination<Self, n, m>(A, mode: mode)
    }
}
