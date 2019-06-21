//
//  MatrixIterator.swift
//  Sample
//
//  Created by Taketo Sano on 2019/06/21.
//

import Foundation

public struct MatrixRowIterator<R: Ring>: IteratorProtocol {
    public typealias Element = MatrixComponent<R>
    private let align: MatrixImpl<R>.Alignment
    private var index: Int
    private var currentPtr: MatrixImpl<R>.LinkedComponent.Pointer?
    
    internal init(_ align: MatrixImpl<R>.Alignment, _ index: Int, _ head: MatrixImpl<R>.LinkedComponent.Pointer?) {
        self.align = align
        self.index = index
        self.currentPtr = head
    }
    
    public mutating func next() -> MatrixComponent<R>? {
        guard let current = currentPtr?.pointee else {
            return nil
        }
        
        defer {
            if current.hasNext {
                currentPtr = currentPtr! + 1
            } else {
                currentPtr = nil
            }
        }
        
        return (align.isHorizontal)
            ? (index, current.index, current.value)
            : (current.index, index, current.value)
    }
}

public struct MatrixIterator<R: Ring>: IteratorProtocol {
    public typealias Element = MatrixComponent<R>
    private let align: MatrixImpl<R>.Alignment
    private let heads: [MatrixImpl<R>.LinkedComponent.Pointer?]
    private var index: Int
    private var rowIterator: MatrixRowIterator<R>?
    
    internal init(_ align: MatrixImpl<R>.Alignment, _ heads: [MatrixImpl<R>.LinkedComponent.Pointer?]) {
        self.align = align
        self.heads = heads
        self.index = 0
        self.rowIterator = nil
    }
    
    public mutating func next() -> MatrixComponent<R>? {
        if rowIterator != nil {
            if let next = rowIterator!.next() {
                return next
            } else {
                rowIterator = nil
                index += 1
            }
        }
        
        while index < heads.count && heads[index] == nil {
            index += 1
        }
        
        if index < heads.count {
            rowIterator = MatrixRowIterator(align, index, heads[index])
            return rowIterator?.next()
        } else {
            return nil
        }
    }
}
