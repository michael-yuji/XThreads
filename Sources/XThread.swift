
#if os(Linux) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

import CKit


public protocol XThreadDelegate {
    func xthread_idle(thread: XThread)
}

public struct blkattr {
    var timeout: time_t = 0
}

public class XThread {
    
    class BlockQueue {
        var blocksCount: Int = 0
        var mutex: pthread_mutex_t = pthread_mutex_t()
        var blocks = [(time_t, () -> Void)]()
        var t_ref: XThread
        var mutexPointer: UnsafeMutablePointer<pthread_mutex_t> {
            return mutablePointer(of: &mutex)
        }
        
        init(thread: XThread) {
            self.t_ref = thread
            pthread_mutex_init(&mutex, nil)
        }
    }
    
    private static var initialized = false
    
    #if os(Linux) || os(FreeBSD)
    var thread = pthread_t()
    #else
    var thread: pthread_t?
    #endif
    
    var queue: BlockQueue!
    var delegate: XThreadDelegate?
    
    var lastExecutionStartedTime: time_t = 0;
    var currentExecutionTimeout: time_t = 0;
    
    @inline(__always)
    private func withMutex(_ execute: () -> Void) {
        pthread_mutex_lock(&queue.mutex)
        execute()
        pthread_mutex_unlock(&queue.mutex)
    }
    
    public func exec(timeout: time_t = 0, block: @escaping () -> Void) {
        withMutex {
            queue.blocks.append((timeout, block))
            queue.blocksCount += 1
            if queue.blocksCount == 1 {
                #if os(Linux)
                pthread_kill(thread, SIGUSR1)
                #else
                pthread_kill(thread!, SIGUSR1)
                #endif
            }
        }
    }
    
    public func exec(_ x: (timeout: time_t, block: () -> Void)) {
        withMutex {
            queue.blocks.append(x)
            queue.blocksCount += 1
            if queue.blocksCount == 1 {
                #if os(Linux)
                    pthread_kill(thread, SIGUSR1)
                #else
                    pthread_kill(thread!, SIGUSR1)
                #endif
            }
        }
    }
    
    func restart() {
        guard let thread = thread else { return }
        pthread_cancel(thread)
        self.queue.blocks.removeFirst() // this is the block causing problem
        thread_run()
    }
    
    private func thread_run() {
        pthread_create(&thread, nil, { (pointer) -> UnsafeMutableRawPointer? in
            
            pthread_setcanceltype(PTHREAD_CANCEL_ENABLE, nil)
            
            #if os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
                let blockQueue = pointer.cast(to: BlockQueue.self).pointee
            #else
                let blockQueue = pointer!.cast(to: BlockQueue.self).pointee
            #endif
            
            var signals = sigset_t()
            var caught: Int32 = 0
            sigemptyset(&signals)
            sigaddset(&signals, XthreadGlobalConf.signal)
            
            while true {
                while blockQueue.blocksCount > 0 {
                    let first = blockQueue.blocks.first!
                    blockQueue.t_ref.lastExecutionStartedTime = time_t()
                    blockQueue.t_ref.currentExecutionTimeout = first.0
                    first.1()
                    blockQueue.t_ref.lastExecutionStartedTime = -1
                    blockQueue.t_ref.currentExecutionTimeout = 0
                    pthread_mutex_lock(blockQueue.mutexPointer)
                    _ = blockQueue.blocks.removeFirst()
                    blockQueue.blocksCount -= 1
                    pthread_mutex_unlock(blockQueue.mutexPointer)
                }
                
                blockQueue.t_ref.delegate?.xthread_idle(thread: blockQueue.t_ref)
                
                // put thread to sleep
                sigwait(&signals, &caught)
            }
            
            }, UnsafeMutableRawPointer(mutablePointer(of: &self.queue)))
    }
    
    public init(delegate: XThreadDelegate? = nil) {
    
        var blk_sigs = sigset_t()
        self.delegate = delegate
        self.queue = BlockQueue(thread: self)
        
        if !XThread.initialized {
            sigemptyset(&blk_sigs)
            sigaddset(&blk_sigs, XthreadGlobalConf.signal)
            pthread_sigmask(SIG_BLOCK, &blk_sigs, nil)
        }
    
        thread_run()
    }
    
    deinit {
        #if os(Linux)
        pthread_exit(&thread)
        #else
        pthread_exit(thread)
        #endif
    }
}
