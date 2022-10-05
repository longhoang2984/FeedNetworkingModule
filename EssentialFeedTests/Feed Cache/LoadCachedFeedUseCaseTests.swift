//
//  LoadCachedFeedUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Cửu Long Hoàng on 04/10/2022.
//

import XCTest
import EssentialFeed

final class LoadCachedFeedUseCaseTests: XCTestCase {

    func test_init_doesNotDeleteCacheUponCreation() {
        
        let (_, store) = makeSUT()
        
        XCTAssertEqual(store.receivedMessages, [])
    }
    
    func test_load_requestsCacheRetrieval() {
        let (sut, store) = makeSUT()
        
        sut.load { _ in }
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_failsOnRetrievalError() {
        let error = anyNSError()
        let (sut, store) = makeSUT()

        expect(sut, toCompletionWith: .failure(error)) {
            store.completionWithRetrievalError(error)
        }
    }
    
    func test_load_deliversNoImagesOnEmptyCached() {
        let (sut, store) = makeSUT()
        
        expect(sut, toCompletionWith: .success([])) {
            store.completionRetrievalWithEmptyCache()
        }
    }
    
    func test_load_deliversCachedImagesOnLessThanSevenDaysOldCache() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let lessThanSevenDaysOldTimestamp = fixedCurrentDate.add(days: -7).add(seconds: 1)
        let (sut, store) = makeSUT { fixedCurrentDate }
        expect(sut, toCompletionWith: .success(feed.models)) {
            store.completionRetrieval(with: feed.local, timestamp: lessThanSevenDaysOldTimestamp)
        }
    }
    
    func test_load_deliversNoImagesOnThanSevenDaysOldCache() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let sevenDaysOldTimestamp = fixedCurrentDate.add(days: -7)
        let (sut, store) = makeSUT(currentDate: { fixedCurrentDate } )
        expect(sut, toCompletionWith: .success([])) {
            store.completionRetrieval(with: feed.local, timestamp: sevenDaysOldTimestamp)
        }
    }
    
    func test_load_deliversNoImagesOnMoreThanSevenDaysOldCache() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let lessThanSevenDaysOldTimestamp = fixedCurrentDate.add(days: -7).add(seconds: -1)
        let (sut, store) = makeSUT { fixedCurrentDate }
        expect(sut, toCompletionWith: .success([])) {
            store.completionRetrieval(with: feed.local, timestamp: lessThanSevenDaysOldTimestamp)
        }
    }
    
    func test_load_noSideEffectsOnRetrieveError() {
        
        let (sut, store) = makeSUT()
        
        sut.load { _ in }
        store.completionWithRetrievalError(anyNSError())
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
        
    }
    
    func test_load_hasNoSideEffectsOnEmptyCache() {
        
        let (sut, store) = makeSUT()
        
        sut.load { _ in }
        store.completionRetrievalWithEmptyCache()
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_hasNoSideEffectsLessThanSevenDaysOld() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let lessThanSevenDaysOldTimestamp = fixedCurrentDate.add(days: -7).add(seconds: 1)
        let (sut, store) = makeSUT { fixedCurrentDate }
        
        sut.load { _ in }
        store.completionRetrieval(with: feed.local, timestamp: lessThanSevenDaysOldTimestamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_hasNoSideEffectsOnSevenDaysOldCached() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let sevenDaysOldTimestamp = fixedCurrentDate.add(days: -7)
        let (sut, store) = makeSUT { fixedCurrentDate }
        
        sut.load { _ in }
        store.completionRetrieval(with: feed.local, timestamp: sevenDaysOldTimestamp)
        
        XCTAssertEqual(store.receivedMessages, [.retrieve])
    }
    
    func test_load_hasNoSideEffectsOnMoreThanSevenDaysOldCached() {
        let feed = uniqueFeeds()
        let fixedCurrentDate = Date()
        let moreThanSevenDaysOldTimestamp = fixedCurrentDate.add(days: -7).add(seconds: -1)
        let (sut, store) = makeSUT { fixedCurrentDate }
        
        sut.load { _ in }
        store.completionRetrieval(with: feed.local, timestamp: moreThanSevenDaysOldTimestamp)
        
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
    
    private func expect(_ sut: LocalFeedLoader, toCompletionWith expectedResult: LocalFeedLoader.LoadResult,
                        action: @escaping () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Wait for completion")
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedImages), .success(expectedImage)):
                XCTAssertEqual(receivedImages, expectedImage, file: file, line: line)
            case let (.failure(receivedError as NSError), .failure(expectedError as NSError)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
            default:
                XCTFail("Expected result \(expectedResult), got \(receivedResult) instead")
            }
            exp.fulfill()
        }
        action()
        wait(for: [exp], timeout: 1.0)
    }
}
