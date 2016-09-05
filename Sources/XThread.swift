
#if os(Linux) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

import CKit

public class XThread {
    class BlockQueue {
        var blocksCount: Int = 0
        var mutex: pthread_mutex_t = pthread_mutex_t()
        var blocks = [() -> Void]()
        
        var mutexPointer: UnsafeMutablePointer<pthread_mutex_t> {
            return mutablePointer(of: &mutex)
        }
        
        init() {
            pthread_mutex_init(&mutex, nil)
        }
    }
    
    private static var initialized = false
    
    #if os(Linux) || os(FreeBSD)
    var thread = pthread_t()
    #else
    var thread: pthread_t?
    #endif
    
    var queue = BlockQueue()
    
    @inline(__always)
    private func withMutex(_ execute: () -> Void) {
        pthread_mutex_lock(&queue.mutex)
        execute()
        pthread_mutex_unlock(&queue.mutex)
    }
    
    public func exec(block: @escaping () -> Void) {
        withMutex {
            queue.blocks.append(block)
            queue.blocksCount += 1
            if queue.blocksCount == 1 {
                pthread_kill(thread!, SIGUSR1)
            }
        }
    }
    
    public init() {
    
        var blk_sigs = sigset_t()
        
        if !XThread.initialized {
            sigemptyset(&blk_sigs)
            sigaddset(&blk_sigs, SIGUSR1)
            pthread_sigmask(SIG_BLOCK, &blk_sigs, nil)
        }
        
        pthread_create(&thread, nil, { (pointer) -> UnsafeMutableRawPointer? in
            
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
                let blockQueue = pointer.cast(to: BlockQueue.self).pointee
            #else
                let blockQueue = pointer!.cast(to: BlockQueue.self).pointee
            #endif
            
            var signals = sigset_t()
            var caught: Int32 = 0
            sigemptyset(&signals)
            sigaddset(&signals, SIGUSR1)
            
            while true {
                while blockQueue.blocksCount > 0 {
                    blockQueue.blocks.first!()
                    pthread_mutex_lock(blockQueue.mutexPointer)
                    _ = blockQueue.blocks.removeFirst()
                    blockQueue.blocksCount -= 1
                    pthread_mutex_unlock(blockQueue.mutexPointer)
                }
                sigwait(&signals, &caught)
            }
            
            }, UnsafeMutableRawPointer(mutablePointer(of: &self.queue)))
    }
    
    deinit {
        pthread_exit(thread)
    }
}
