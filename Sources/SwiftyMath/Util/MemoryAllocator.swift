//
//  MemoryAllocator.swift
//  Sample
//
//  Created by Taketo Sano on 2019/06/21.
//

import Foundation

public final class MemoryAllocator<T> {
    public typealias Pointer = UnsafeMutablePointer<T>
    public let bufferLength: Int
    
    private var bufferHeads: [Pointer]
    private var ptr: Pointer?
    private var count: Int
    private var debug: Bool
    
    public init(bufferLength: Int, debug: Bool = true) {
        self.bufferLength = bufferLength
        self.bufferHeads = []
        
        self.ptr = nil
        self.count = 0
        self.debug = debug
    }
    
    deinit {
        deallocate()
    }
    
    private func allocate() {
        let p = Pointer.allocate(capacity: bufferLength)
        bufferHeads.append(p)
        ptr = p
        count = 0
        log("allocate \(bufferLength) at \(ptr)")
    }
    
    public func reserve(_ length: Int) {
        assert(length <= bufferLength)
        
        if ptr == nil || count + length >= bufferLength {
            allocate()
        }
    }
    
    public func next() -> Pointer {
        if ptr == nil {
            allocate()
        }
        defer {
            ptr! += 1
            count += 1
            assert(count < bufferLength)
        }
        return ptr!
    }
    
    public func deallocate() {
        ptr = nil
        count = 0
        
        for p in bufferHeads {
            p.deinitialize(count: bufferLength)
            p.deallocate()
            log("deallocate \(bufferLength) at \(p)")
        }
        bufferHeads.removeAll()
    }
    
    private func log(_ s: @autoclosure () -> String) {
        if debug {
            print(s())
        }
    }
}
