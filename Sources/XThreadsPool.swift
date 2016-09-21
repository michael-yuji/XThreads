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
    public static var global = ContiguousArray<XThreadPool>()
    
    fileprivate var maxthreads: Int
    fileprivate var threads = [XThread]()
    fileprivate var mutex = pthread_mutex_t()
    var pending = [(time_t, () -> Void)]()
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
    
    public static func timeout(to pool: XThreadPool) {
        pool.checktimeout()
    }
    
    private func checktimeout() {
        for thread in threads {
            if thread.currentExecutionTimeout != 0 && thread.lastExecutionStartedTime != -1 {
                if time(nil) - thread.lastExecutionStartedTime > thread.currentExecutionTimeout {
                    thread.restart()
                }
            }
        }
    }
    
    private func withMutex<T>(block: @autoclosure () -> T) -> T {
        pthread_mutex_lock(&mutex)
        let t = block()
        pthread_mutex_unlock(&mutex)
        return t
    }
    
    public func xthread_idle(thread: XThread) {
        withMutex(block: thread.exec(self.pending.removeFirst()))
    }
    
    public func async(timeout: time_t = 0, block: @escaping () -> Void) {
        let leastBusy = threads.sorted {
            $0.queue.blocksCount < $1.queue.blocksCount
            }.first
        
        if leastBusy == nil || (self.threads.count < self.maxthreads && leastBusy!.queue.blocksCount != 0) {
            return create_exec(timeout: timeout, block)
        }
        
        return self.pending.append(timeout, block)
    }
    
    private func create_exec(timeout: time_t = 0, _ block: @escaping () -> Void) {
        let t = XThread(delegate: self)
        self.withMutex(block: self.threads.append(t))
        t.exec(timeout: timeout, block: block)
    }
    
    public func sync(thread: XThread, timeout: time_t = 0, block: @escaping () -> Void) {
        thread.exec(timeout: timeout, block: block)
    }
    
    public func sync(thread: XThread, timeout: time_t = 0, blocks: [() -> Void]) {
        blocks.forEach{thread.exec(timeout: timeout, block: $0)}
    }
}
