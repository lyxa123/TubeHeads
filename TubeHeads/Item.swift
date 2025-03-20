//
//  Item.swift
//  TubeHeads
//
//  Created by Lyxa on 3/19/25.
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
