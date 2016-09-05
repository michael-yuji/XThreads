//
//  Helper.swift
//  XThreads
//
//  Created by yuuji on 9/5/16.
//
//

import Foundation

extension Array {
    init(count: Int, initalizer: (_ index: Int) -> Element) {
        self = [Element]()
        for index in 0..<count {
            self.append(initalizer(index))
        }
    }
}
