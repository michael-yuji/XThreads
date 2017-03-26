
import CKit

public class XThreadPool {
    
//    var control: XThread
    
    var pool = [XThread]()
    var works = [(() -> Void)?]()
    
//    var kq = KernelQueue()
    
    public func async(block: @escaping () -> Void) {
        for thread in pool {
            do {
                try thread.exec(block: block)
                return
            } catch {
                print(error)
            }
        }
        
        let newThread = XThread()
        try! newThread.exec(block: block)
        pool.append(newThread)
    }
    
    public func async(_ c: Int) {
        let block = {
            print("executed: \(c)\n")
        }
        
        for thread in pool {
            do {
                try thread.exec(block: block)
                print("should exec \(c) on \(thread.context.pointee.uuid)")
                return
            } catch {
//                print("\(error) \(c)")
            }
        }
        
        let newThread = XThread()
        print("made new thread \(newThread.context.pointee.uuid) for \(c)")
        
        try! newThread.exec(block: block)
        pool.append(newThread)
    }
    public init() {

    }
}
