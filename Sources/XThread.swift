
import CKit
import Foundation

public protocol XThreadDelegate {
    func xthreadOnIdle(thread: XThreadProxy) -> Bool
}

enum ThreadStatus {
    case waitSig
    case runBlock
}

public struct XThreadProxy {
    var __ptr: UnsafeMutablePointer<XThread.Context>

    public func exec(block: @escaping () -> Void) throws {
        try __ptr.pointee.exec(block: block)
    }

    public func cancel() {
        __ptr.pointee.cancel()
    }
}

public class XThread {
    var context: UnsafeMutablePointer<Context>

    init(delegate: XThreadDelegate) {
        self.context = UnsafeMutablePointer<Context>.allocate(capacity: 1)
        self.context.pointee = Context(delegate: delegate)
        run()
    }

    init() {
        self.context = Context.alloc()
        run()
    }

    func run() {
        pthread_create(&context.pointee.thread, nil, { rawPointer in
            let __self = pthread_self()
            let ptr = rawPointer.assumingMemoryBound(to: Context.self)
            pthread_setcanceltype(PTHREAD_CANCEL_ENABLE, nil)

            // pthread_cleanup_push
            #if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
            var __handler = __darwin_pthread_handler_rec(__routine: {
                $0!.assumingMemoryBound(to: Context.self).pointee.trigger.close()
                $0!.assumingMemoryBound(to: Context.self).deallocate(capacity: 1)
            }, __arg: rawPointer, __next: __self.pointee.__cleanup_stack)
            __self.pointee.__cleanup_stack = mutablePointer(of: &__handler)
            #else
            // The linux pthread_cleanup_push is almost impossible to port
            #endif
            
            while (true) {
                if let delegate = ptr.pointee.delegate {
                    if !delegate.xthreadOnIdle(thread: XThreadProxy(__ptr: ptr)) {
                        break
                    }
                }
                
                if let block = ptr.pointee.block {
                    block()
                    ptr.pointee.block = nil
                }
                
                ptr.pointee.busy = false
                ptr.pointee.trigger.wait()
                ptr.pointee.busy = true
            }

            // pthread_cleanup_pop
            #if os(OSX) || os(iOS) || os(tvOS) || os(watchOS)
            __self.pointee.__cleanup_stack = __handler.__next
            __handler.__routine(__handler.__arg)
            #else
    
            #endif
            pthread_exit(nil)

        }, context.mutableRawPointer)
    }

    deinit {
        pthread_cancel(self.context.pointee.thread!)
        
        #if os(Linux)
        context.deallocate(capacity: 1)
        context.trigger.close()
        #endif
    }
}

public extension XThread {
    public func cancel() {
        self.context.pointee.cancel()
    }

    public func exec(block: @escaping () -> Void) throws {
        try self.context.pointee.exec(block: block)
    }
}

public extension XThread {
    struct Context {
        var delegate: XThreadDelegate?
        var block: (() -> Void)?
        
        var trigger = Trigger()

        var uuid = UUID()
        #if os(Linux) || os(FreeBSD)
        var thread = pthread_t()
        #else
        var thread: pthread_t?
        #endif

        var busy: Bool = false
        
        init(delegate: XThreadDelegate) {
            self.delegate = delegate
        }

        init() {
        }

        static func alloc() -> UnsafeMutablePointer<Context> {
            let ptr = UnsafeMutablePointer<Context>.allocate(capacity: 1)
            var t = Context()
            memcpy(ptr.mutableRawPointer, pointer(of: &t).rawPointer, MemoryLayout<Context>.size)
            return ptr
        }

        static func alloc(delegate: XThreadDelegate) -> UnsafeMutablePointer<Context> {
            let ptr = UnsafeMutablePointer<Context>.allocate(capacity: 1)
            ptr.pointee = Context(delegate: delegate)
            return ptr
        }

        mutating func exec(block: @escaping () -> Void) throws {

            guard self.block == nil && !self.busy else {
                throw XThreadError.ThreadIsBusy
            }

            self.block = block
            self.trigger.trigger()
        }

        func cancel() {
            pthread_cancel(self.thread!)
        }
    }
}
