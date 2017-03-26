//
//  Helper.swift
//  XThreads
//
//  Created by yuuji on 9/5/16.
//
//

import Foundation
import CKit

extension Array {
    init(count: Int, initalizer: (_ index: Int) -> Element) {
        self = [Element]()
        for index in 0..<count {
            self.append(initalizer(index))
        }
    }
    
    func x(send: AnyCollection<UInt8>) {
        
    }
}

public struct XthreadGlobalConf {
    static var signal: Int32 = SIGIO
}

public enum XThreadError: Error {
    case ThreadIsBusy
}

public struct Trigger {
    
    var kq: Int32
    
    public init() {
        #if os(FreeBSD) || os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            kq = kqueue()
            var ev = KernelEvent(ident: 0, filter: Int16(EVFILT_USER), flags: UInt16(EV_ADD | EV_ENABLE), fflags: NOTE_FFCOPY, data: 0, udata: nil)
            kevent(kq, &ev, 1, nil, 0, nil)
        #elseif os(Linux) || os(Android)
            kq = eventfd(0,0)
        #endif
    }
    
    public func trigger() {
        #if os(FreeBSD) || os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            var triggerEv = KernelEventDescriptor.user(ident: 0, options: .trigger).makeEvent(.enable)
            if kevent(kq, &triggerEv, 1, nil, 0, nil) == -1 {
                return
            }
        #elseif os(Linux) || os(Android)
            eventfd_write(kq, 1)
        #endif
    }
    
    public func wait() {
        #if os(FreeBSD) || os(OSX) || os(iOS) || os(watchOS) || os(tvOS)
            var t = KernelEvent()
            
            var ev = KernelEvent(ident: 0, filter: Int16(EVFILT_USER), flags: UInt16(EV_DISABLE), fflags: NOTE_FFCOPY, data: 0, udata: nil)
            print("wait")
            kevent(kq, nil, 0, &t, 1, nil)
            kevent(kq, &ev, 1, nil, 0, nil)
            print("wait finished")
        #elseif os(Linux) || os(Android)
            var pfd = pollfd(fd: kq, events: Int16(POLLIN), revents: 0)
            if poll(&pfd, 1, 0) == -1 {
                return
            }
            var val: eventfd_t = 0
            eventfd_read(kq, &val)
        #endif
    }
    
    public func close() {
        _ = xlibc.close(kq)
    }
}
