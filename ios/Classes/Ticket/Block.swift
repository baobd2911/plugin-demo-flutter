//
//  Block.swift
//  Ticket
//
//  Created by gix on 2019/6/30.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

public protocol Printable {
    func data(using encoding: String.Encoding) -> Data
}

public protocol BlockDataProvider: Printable { }

public protocol Attribute {
    var attribute: [UInt8] { get }
}

public struct Block: Printable {

    public static var defaultFeedPoints: UInt8 = 70
    
    private let feedPoints: UInt8
    private let dataProvider: BlockDataProvider
    
    public init(_ dataProvider: BlockDataProvider, feedPoints: UInt8 = Block.defaultFeedPoints) {
        self.feedPoints = feedPoints
        self.dataProvider = dataProvider
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        return dataProvider.data(using: encoding) + Data.print(feedPoints)
    }
}

public extension Block {
   
   
    // image
    static func image(_ im: Image, attributes: TicketImage.PredefinedAttribute...) -> Block {
        return Block(TicketImage(im, attributes: attributes))
    }
    
}
