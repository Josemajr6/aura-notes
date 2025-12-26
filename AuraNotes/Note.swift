//
//  Note.swift
//  AuraNotes
//
//  Created by José Manuel Jiménez Rodríguez on 22/12/25.
//


import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var content: String
    var timestamp: Date
    
    init(title: String = "", content: String = "", timestamp: Date = .now) {
        self.title = title
        self.content = content
        self.timestamp = timestamp
    }
}
