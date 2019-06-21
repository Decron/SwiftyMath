import Foundation

public typealias MatrixComponent<R: Ring> = (row: Int, col: Int, value: R)

public typealias SquareMatrix<n: StaticSizeType, R: Ring> = Matrix<n, n, R>
public typealias Matrix1<R: Ring> = SquareMatrix<_1, R>
public typealias Matrix2<R: Ring> = SquareMatrix<_2, R>
public typealias Matrix3<R: Ring> = SquareMatrix<_3, R>
public typealias Matrix4<R: Ring> = SquareMatrix<_4, R>

public typealias DMatrix<R: Ring> = Matrix<DynamicSize, DynamicSize, R>

public struct Matrix<n: SizeType, m: SizeType, R: Ring>: SetType {
    public typealias CoeffRing = R
    
    internal var impl: MatrixImpl<R>
    internal init(_ impl: MatrixImpl<R>) {
        self.impl = impl
    }
    
    public var rows: Int { return impl.rows }
    public var cols: Int { return impl.cols }
    
    private mutating func willMutate() {
        if !isKnownUniquelyReferenced(&impl) {
            impl = impl.copy()
        }
    }
    
    public subscript(i: Int, j: Int) -> R {
        get {
            return impl[i, j]
        } set {
            willMutate()
            impl[i, j] = newValue
        }
    }
    
    public static func ==(a: Matrix<n, m, R>, b: Matrix<n, m, R>) -> Bool {
        return a.impl == b.impl
    }
    
    public static func +(a: Matrix<n, m, R>, b: Matrix<n, m, R>) -> Matrix<n, m, R> {
        return Matrix(a.impl + b.impl)
    }
    
    public prefix static func -(a: Matrix<n, m, R>) -> Matrix<n, m, R> {
        return Matrix(-a.impl)
    }
    
    public static func -(a: Matrix<n, m, R>, b: Matrix<n, m, R>) -> Matrix<n, m, R> {
        return a + (-b)
    }
    
    public static func *(r: R, a: Matrix<n, m, R>) -> Matrix<n, m, R> {
        return Matrix(r * a.impl)
    }
    
    public static func *(a: Matrix<n, m, R>, r: R) -> Matrix<n, m, R> {
        return Matrix(a.impl * r)
    }
    
    public static func * <p>(a: Matrix<n, m, R>, b: Matrix<m, p, R>) -> Matrix<n, p, R> {
        return Matrix<n, p, R>(a.impl * b.impl)
    }
    
    public static func ⊕ <n1, m1>(A: Matrix<n, m, R>, B: Matrix<n1, m1, R>) -> DMatrix<R> {
        return A.concatDiagonally(B)
    }
    
    public static func ⊗ <n1, m1>(A: Matrix<n, m, R>, B: Matrix<n1, m1, R>) -> DMatrix<R> {
        return .init(A.impl ⊗ B.impl)
    }
    
    public func submatrix(rowRange: CountableRange<Int>) -> Matrix<DynamicSize, m, R> {
        return .init(impl.submatrix(rowRange: rowRange) )
    }
    
    public func submatrix(colRange: CountableRange<Int>) -> Matrix<n, DynamicSize, R> {
        return .init(impl.submatrix(colRange: colRange) )
    }
    
    public func submatrix(_ rowRange: CountableRange<Int>, _ colRange: CountableRange<Int>) -> DMatrix<R> {
        return .init(impl.submatrix(rowRange, colRange))
    }
    
    public func concatHorizontally<m1>(_ B: Matrix<n, m1, R>) -> Matrix<n, DynamicSize, R> {
        assert(rows == B.rows)
        return .init(impl.concatHorizontally(B.impl))
    }
    
    public func concatVertically<n1>(_ B: Matrix<n1, m, R>) -> Matrix<DynamicSize, m, R> {
        assert(cols == B.cols)
        return .init(impl.concatVertically(B.impl))
    }
    
    public func concatDiagonally<n1, m1>(_ B: Matrix<n1, m1, R>) -> DMatrix<R> {
        assert(cols == B.cols)
        return .init(impl.concatDiagonally(B.impl))
    }
    
    public func decomposeIntoBlocks(rowSizes: [Int], colSizes: [Int]) -> [[DMatrix<R>]] {
        assert(rowSizes.sumAll() == rows)
        assert(colSizes.sumAll() == cols)
        
        var i = 0
        return rowSizes.map { r -> [DMatrix<R>] in
            defer { i += r }
            
            var j = 0
            return colSizes.map { c -> DMatrix<R> in
                defer { j += c }
                return self.submatrix(i ..< i + r, j ..< j + c)
            }
        }
    }
    
    public var isZero: Bool {
        return impl.isZero
    }
    
    public var isIdentity: Bool {
        return impl.isIdentity
    }
    
    public var isDiagonal: Bool {
        return impl.isDiagonal
    }
    
    public var diagonal: [R] {
        return impl.diagonal
    }
    
    public var transposed: Matrix<m, n, R> {
        return Matrix<m, n, R>(impl.copy().transpose())
    }
    
    public func rowVector(_ i: Int) -> RowVector<m, R> {
        return RowVector(impl.submatrix(i ..< i + 1, 0 ..< cols))
    }
    
    public func colVector(_ j: Int) -> ColVector<n, R> {
        return ColVector(impl.submatrix(0 ..< rows, j ..< j + 1))
    }
    
    public func iterator() -> MatrixIterator<R> {
        return impl.iterator()
    }
    
    public func iterator(forRow i: Int) -> MatrixRowIterator<R> {
        return impl.iterator(forRow: i)
    }
    
    public func iterator(forCol j: Int) -> MatrixRowIterator<R> {
        return impl.iterator(forCol: j)
    }
    
    public func mapNonZeroComponents<R2>(_ f: (R) -> R2) -> Matrix<n, m, R2> {
        return Matrix<n, m, R2>(impl.mapComponents(f))
    }
    
    public func generateGrid() -> [R] {
        return impl.generateGrid()
    }
    
    public func `as`<n, m>(_ type: Matrix<n, m, R>.Type) -> Matrix<n, m, R> {
        assert(n.isDynamic || n.intValue == rows)
        assert(m.isDynamic || m.intValue == cols)
        
        return Matrix<n, m, R>(impl)
    }
    
    public var hashValue: Int {
        return impl.hashValue
    }
    
    public var description: String {
        return impl.description
    }
    
    public var detailDescription: String {
        return impl.detailDescription
    }
    
    public static var symbol: String {
        if !m.isDynamic && m.intValue == 1 {
            if !n.isDynamic {
                return "Vec<\(n.intValue); \(R.symbol)>"
            } else {
                return "Vec<\(R.symbol)>"
            }
        }
        if !n.isDynamic && n.intValue == 1 {
            if !m.isDynamic {
                return "rVec<\(m.intValue); \(R.symbol)>"
            } else {
                return "rVec<\(R.symbol)>"
            }
        }
        if !n.isDynamic && !m.isDynamic {
            return "Mat<\(n.intValue), \(m.intValue); \(R.symbol)>"
        } else {
            return "Mat<\(R.symbol)>"
        }
    }
}

extension Matrix: AdditiveGroup, Module where n: StaticSizeType, m: StaticSizeType {
    public init(_ grid: [R]) {
        let (rows, cols) = (n.intValue, m.intValue)
        self.init(MatrixImpl(rows: rows, cols: cols, grid: grid))
    }
    
    public init(_ grid: R...) {
        self.init(grid)
    }
    
    public init(generator g: (Int, Int) -> R) {
        let (rows, cols) = (n.intValue, m.intValue)
        self.init(MatrixImpl(rows: rows, cols: cols, generator: g))
    }
    
    public init(components: [MatrixComponent<R>]) {
        let (rows, cols) = (n.intValue, m.intValue)
        self.init(MatrixImpl(rows: rows, cols: cols, components: components))
    }
    
    public static var zero: Matrix<n, m, R> {
        return Matrix(components:[])
    }
    
    public static func unit(_ i0: Int, _ j0: Int) -> Matrix<n, m, R> {
        return Matrix(components: [(i0, j0, .identity)])
    }
}

extension Matrix: Monoid, Ring where n == m, n: StaticSizeType {
    public init(from a : 𝐙) {
        let comps = (0 ..< n.intValue).map{ i in (i, i, R(from: a)) }
        self.init(components: comps)
    }
    
    public var size: Int {
        return rows
    }
    
    public static var identity: SquareMatrix<n, R> {
        return Matrix<n, n, R> { $0 == $1 ? .identity : .zero }
    }
    
    public static func scalar(_ a: R) -> SquareMatrix<n, R> {
        let comps = (0 ..< n.intValue).map{ i in (i, i, a) }
        return .init(components: comps)
    }
    
    public static func diagonal(_ d: [R]) -> SquareMatrix<n, R> {
        let comps = d.enumerated().map{ (i, a) in (i, i, a) }
        return .init(components: comps)
    }
    
    public var isInvertible: Bool {
        return determinant.isInvertible
    }
    
    public var inverse: SquareMatrix<n, R>? {
        if size >= 5 {
            print("warn: Directly computing matrix-inverse can be extremely slow. Use elimination().determinant instead.")
        }
        return impl.inverse.map{ SquareMatrix($0) }
    }
    
    public var trace: R {
        return impl.trace
    }
    
    public var determinant: R {
        if size >= 5 {
            print("warn: Directly computing determinant can be extremely slow. Use elimination().determinant instead.")
        }
        
        return impl.determinant
    }
    
    public func pow(_ n: 𝐙) -> SquareMatrix<n, R> {
        assert(n >= 0)
        return (0 ..< n).reduce(.identity){ (res, _) in self * res }
    }
}

extension Matrix where n == m, n == _1 {
    public var asScalar: R {
        return self[0, 0]
    }
}

public extension Matrix where n == DynamicSize, m == DynamicSize {
    init(rows: Int, cols: Int, grid: [R]) {
        self.init(MatrixImpl(rows: rows, cols: cols, grid: grid))
    }
    
    init(rows: Int, cols: Int, grid: R ...) {
        self.init(rows: rows, cols: cols, grid: grid)
    }
    
    init(rows: Int, cols: Int, generator g: (Int, Int) -> R) {
        self.init(MatrixImpl(rows: rows, cols: cols, generator: g))
    }
    
    init(rows: Int, cols: Int, components: [MatrixComponent<R>]) {
        self.init(MatrixImpl(rows: rows, cols: cols, components: components))
    }
    
    static func identity(size n: Int) -> DMatrix<R> {
        return DMatrix(.identity(size: n))
    }
    
    static func zero(size n: Int) -> DMatrix<R> {
        return DMatrix.zero(rows: n, cols: n)
    }
    
    static func zero(rows: Int, cols: Int) -> DMatrix<R> {
        return DMatrix(.zero(rows: rows, cols: cols))
    }
    
    var inverse: DMatrix<R>? {
        assert(rows == cols)
        if rows >= 5 {
            print("warn: Directly computing matrix-inverse can be extremely slow. Use elimination().determinant instead.")
        }
        return impl.inverse.map{ DMatrix($0) }
    }
    
    var trace: R {
        assert(rows == cols)
        return impl.trace
    }
    
    var determinant: R {
        assert(rows == cols)
        if rows >= 5 {
            print("warn: Directly computing determinant can be extremely slow. Use elimination().determinant instead.")
        }
        
        return impl.determinant
    }
    
    func pow(_ n: 𝐙) -> DMatrix<R> {
        assert(rows == cols)
        assert(n >= 0)
        return (0 ..< n).reduce(.identity(size: rows)){ (res, _) in self * res }
    }
}

public extension Matrix where R: RealSubset {
    var asReal: Matrix<n, m, 𝐑> {
        return Matrix<n, m, 𝐑>(impl.mapComponents{ $0.asReal })
    }
}

public extension Matrix where R: ComplexSubset {
    var asComplex: Matrix<n, m, 𝐂> {
        return Matrix<n, m, 𝐂>(impl.mapComponents{ $0.asComplex })
    }
}

public extension Matrix where R == 𝐂 {
    var realPart: Matrix<n, m, 𝐑> {
        return Matrix<n, m, 𝐑>(impl.mapComponents{ $0.realPart })
    }
    
    var imaginaryPart: Matrix<n, m, 𝐑> {
        return Matrix<n, m, 𝐑>(impl.mapComponents{ $0.imaginaryPart })
    }
    
    var adjoint: Matrix<m, n, R> {
        return transposed.mapNonZeroComponents { $0.conjugate }
    }
}

extension Matrix: Codable where R: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.impl = try c.decode(MatrixImpl<R>.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(impl)
    }
}
