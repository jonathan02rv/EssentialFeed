//
//  FeadLoader.swift
//  EssentialFeed
//
//  Created by Jhonatahan Orlando Rivera Vilcapoma on 3/09/21.
//

import Foundation

public enum LoadFeedResult{
    case success([FeedItem])
    case failure(Error)
}

public protocol FeedLoader {
    func load(completion:@escaping (LoadFeedResult)->Void )
}
