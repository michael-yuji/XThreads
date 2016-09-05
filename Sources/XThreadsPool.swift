//
//  XThreadPool.swift
//  XThread
//
//  Created by yuuji on 9/5/16.
//
//

import CKit

public class XThreadPool {
    public var threadsCount: Int
    var threads: [XThread]
    
    public func exec(block: @escaping () -> Void) {
        threads.sorted {
            $0.queue.blocksCount < $1.queue.blocksCount
        }.first!.exec(block: block)
    }
    
    public init(threads count: Int = Sysconf.cpusConfigured * 3) {
        threadsCount = count
        threads = [XThread](count: count) { _ in XThread() }
    }
}
