//
//  XThreadPool.swift
//  XThread
//
//  Created by yuuji on 9/5/16.
//
//

import CKit

#if os(Linux) || os(FreeBSD)
import Glibc
private typealias __uuid = uuid_t
#else
import Darwin
private typealias __uuid = UInt8
#endif

public final class XThreadPool: XThreadDelegate {
    
    fileprivate var maxthreads: Int
    fileprivate var threads = [XThread]()
    fileprivate var mutex = pthread_mutex_t()
    var pending = [() -> Void]()
    public var numberOfThreads: Int {
        return self.threads.count
    }
    
    public init(max: Int) {
        self.threads = [XThread]()
        self.maxthreads = max
        pthread_mutex_init(&mutex, nil)
    }
}

public extension XThreadPool {
    private func withMutex<T>(block: @autoclosure () -> T) -> T {
        pthread_mutex_lock(&mutex)
        let t = block()
        pthread_mutex_unlock(&mutex)
        return t
    }
    
    public func xthread_idle(thread: XThread) {
        withMutex(block: thread.exec(block: self.pending.removeFirst()))
    }
    
    public func async(block: @escaping () -> Void) {
        let leastBusy = threads.sorted {
            $0.queue.blocksCount < $1.queue.blocksCount
            }.first
        
        if leastBusy == nil || (self.threads.count < self.maxthreads && leastBusy!.queue.blocksCount != 0) {
            return create_exec(block)
        }
        
        return self.pending.append(block)
    }
    
    private func create_exec(_ block: @escaping () -> Void) {
        let t = XThread(delegate: self)
        self.withMutex(block: self.threads.append(t))
        t.exec(block: block)
    }
    
    public func sync(thread: XThread, block: @escaping () -> Void) {
        thread.exec(block: block)
    }
    
    public func sync(thread: XThread, blocks: [() -> Void]) {
        blocks.forEach{thread.exec(block: $0)}
    }
}
