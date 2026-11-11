//
//  Item.swift
//  INVERTER
//
//  Created by JJ Zhang on 2026/11/11.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
