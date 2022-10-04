//
//  FeedStoreSpy.swift
//  EssentialFeedTests
//
//  Created by Cửu Long Hoàng on 04/10/2022.
//

import Foundation
import EssentialFeed

class FeedStoreSpy: FeedStore {
    enum ReceivedMessage: Equatable {
        case deleteCachedFeed
        case inert([LocalFeedImage], Date)
    }
    
    private(set) var receivedMessages: [ReceivedMessage] = []
    private var deletionCompletions = [DeletionCompletion]()
    private var insertionCompletions = [InsertionCompletion]()
    func deleteCachedFeed(completion: @escaping DeletionCompletion) {
        deletionCompletions.append(completion)
        receivedMessages.append(.deleteCachedFeed)
    }
    
    func completionWithDeletionError(_ error: Error, at index: Int = 0) {
        deletionCompletions[index](error)
    }
    
    func completionWithInsertionError(_ error: Error, at index: Int = 0) {
        insertionCompletions[index](error)
    }
    
    func completionWithSuccessfulDeletion(at index: Int = 0) {
        deletionCompletions[index](nil)
    }
    
    func insert(_ feeds: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
        insertionCompletions.append(completion)
        receivedMessages.append(.inert(feeds, timestamp))
    }
    
    func completionWithSuccessfulInsertion(at index: Int = 0) {
        insertionCompletions[index](nil)
    }
}
