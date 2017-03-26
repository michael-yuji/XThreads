
import CKit

public class XThreadPool {
    var pool = [XThread]()
    public static let global = XThreadPool()
    public func async(block: @escaping () -> Void) {
        for thread in pool {
            do {
                try thread.exec(block: block)
                return
            } catch {
            }
        }
        let newThread = XThread()
        try! newThread.exec(block: block)
        pool.append(newThread)
    }
}
