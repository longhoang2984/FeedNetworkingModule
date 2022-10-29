//
//  ValidateFeedCachedUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Cửu Long Hoàng on 05/10/2022.
//

import XCTest
import EssentialFeed

final class ValidateFeedCachedUseCaseTests: XCTestCase {
    
    func test_init_doesNotDeleteCacheUponCreation() {
        
        let (_, store) = makeSUT()
        
        XCTAssertEqual(store.receivedMessages, [])
    }
    
    func test_validateCache_deleteCachedOnRetrieveError() {
        
        let (sut, store) = makeSUT()
        
        sut.validateCache { _ in }
        store.completionWithRetrievalError(anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.retrieve, .deleteCachedFeed])
        
    }
    
    func test_validateCache_doesNotDeleteCachedOnEmptyCache() {
        
        let (sut, store) = makeSUT()
        
        sut.validateCache { _ in }
        store.completionRetrievalWithEmptyCache()
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_validateCache_doesNotDeleteCachedNonExpiringCached() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let nonExpiringCache = fixedCurrentDate.minusFeedCacheMaxAge().add(seconds: 1)
        let (sut, store) = makeSUT { fixedCurrentDate }
        
        sut.validateCache { _ in }
        store.completionRetrieval(with: feed.local, timestamp: nonExpiringCache)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_validateCache_deleteCachedOnExpirationCache() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let expirationTimestamp = fixedCurrentDate.minusFeedCacheMaxAge()
        let (sut, store) = makeSUT { fixedCurrentDate }
        
        sut.validateCache { _ in }
        store.completionRetrieval(with: feed.local, timestamp: expirationTimestamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve, .deleteCachedFeed])
    }
    
    func test_validateCache_deleteCachedOnExpiredCached() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let expiredTimestamp = fixedCurrentDate.minusFeedCacheMaxAge().add(seconds: -1)
        let (sut, store) = makeSUT { fixedCurrentDate }
        
        sut.validateCache { _ in }
        store.completionRetrieval(with: feed.local, timestamp: expiredTimestamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve, .deleteCachedFeed])
    }
    
    func test_validate_doesNotDeliverMessageAfterSUTInstanceHasDeallocated() {
        let store = FeedStoreSpy()
        var sut: LocalFeedLoader? = LocalFeedLoader(store: store, currentDate: Date.init)
        
        sut?.validateCache { _ in }
        
        sut = nil
        store.completionWithRetrievalError(anyNSError())
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }

    // MARK: - Helpers
    private func makeSUT(currentDate: @escaping () -> Date = Date.init, file: StaticString = #filePath, line: UInt = #line) -> (sut: LocalFeedLoader, store: FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedLoader(store: store, currentDate: currentDate)
        trackForMemoryLeaks(store, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, store)
    }
}
