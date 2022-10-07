//
//  CodableFeedStoreTests.swift
//  EssentialFeedTests
//
//  Created by Cửu Long Hoàng on 06/10/2022.
//

import XCTest
import EssentialFeed

typealias FailableFeedStoreSpects = FailableDeleteFeedStoreSpecs & FailableInsertFeedStoreSpecs & FailableRetrieveFeedStoreSpecs
final class CodableFeedStoreTests: XCTestCase, FailableFeedStoreSpects {
    
    override func setUp() {
        super.setUp()
        
        setUpEmptyStoreState()
    }
    
    override func tearDown() {
        super.tearDown()
        
        undoStoreArtifacts()
    }
    
    func test_retrieve_deliverEmptyOnEmptyCache() {
        let sut = makeSUT()
        
        expect(sut, toRetrieve: .empty)
    }
    
    func test_retrieve_hasNoSideEffectsOnEmptyCache() {
        let sut = makeSUT()
        
        expect(sut, toRetrieve: .empty)
        expect(sut, toRetrieve: .empty)
        
    }
    
    func test_retrieve_deliversFoundValuesOnNonEmptyCache() {
        let sut = makeSUT()
        let feed = uniqueFeeds()
        let timestamp = Date()
        
        insert((feed.local, timestamp), to: sut)
        expect(sut, toRetrieve: .found(feed: feed.local, timestamp: timestamp))
    }
    
    func test_retrieve_hasNoSideEffectsOnNonEmptyCache() {
        let sut = makeSUT()
        let feed = uniqueFeeds()
        let timestamp = Date()
        
        insert((feed.local, timestamp), to: sut)
        expect(sut, toRetrieveTwice: .found(feed: feed.local, timestamp: timestamp))
    }
    
    func test_retrieve_deliversFailureOnRetrievalError() {
        let storeURL = testSpecificStoreURL()
        let sut = makeSUT(storeURL: storeURL)
        
        try! "invalid data".write(to: storeURL, atomically: false, encoding: .utf8)
        
        expect(sut, toRetrieve: .failure(anyNSError()))
        
    }
    
    func test_retrieve_hasNoSideEffectsOnFailure() {
        let storeURL = testSpecificStoreURL()
        let sut = makeSUT(storeURL: storeURL)
        
        try! "invalid data".write(to: storeURL, atomically: false, encoding: .utf8)
        
        expect(sut, toRetrieveTwice: .failure(anyNSError()))
    }
    
    func test_insert_overridesPreviouslyInsertedCacheValues() {
        let sut = makeSUT()
        
        let firstInsertionError = insert((uniqueFeeds().local, Date()), to: sut)
        XCTAssertNil(firstInsertionError, "Expected to insert cache successfully")
        
        let latestFeed = uniqueFeeds().local
        let latestTimestamp = Date()
        let latestInsertionError = insert((latestFeed, latestTimestamp), to: sut)
        XCTAssertNil(latestInsertionError, "Expected to override cache successfully")
        expect(sut, toRetrieve: .found(feed: latestFeed, timestamp: latestTimestamp))
    }
    
    func test_insert_deliversFailureOnInsertionError() {
        let storeURL = URL(string: "invalid://invalid-url")!
        let sut = makeSUT(storeURL: storeURL)
        let feed = uniqueFeeds()
        let timestamp = Date()
        
        let insertionError = insert((feed.local, timestamp), to: sut)
        XCTAssertNotNil(insertionError, "Expected to insert cache failure with an error")
    }
    
    func test_insert_hasNoSideEffectsOnFailure() {
        let storeURL = URL(string: "invalid://invalid-url")!
        let sut = makeSUT(storeURL: storeURL)
        let feed = uniqueFeeds()
        let timestamp = Date()
        
        insert((feed.local, timestamp), to: sut)
        expect(sut, toRetrieve: .empty)
    }
    
    func test_delete_hasNoSideEffectsOnEmptyCache() {
        let sut = makeSUT()
        
        let error = delete(sut)
        XCTAssertNil(error, "Expected empty cache deletion to succeed")
        expect(sut, toRetrieve: .empty)
    }
    
    func test_delete_deliversEmptyOnNonEmptyCache() {
        let sut = makeSUT()
        let feed = uniqueFeeds()
        let timestamp = Date()
        
        let insertionError = insert((feed.local, timestamp), to: sut)
        XCTAssertNil(insertionError, "Expected to insert successfully")
        
        let error = delete(sut)
        XCTAssertNil(error, "Expected non-empty cache deletion to succeed")
        expect(sut, toRetrieve: .empty)
    }
    
    func test_delete_deliversErrorOnDeletionError() {
        let noPermissionURL = cachesDirectory()
        let sut = makeSUT(storeURL: noPermissionURL)

        let error = delete(sut)
        XCTAssertNotNil(error, "Expected cache deletion to failed")
    }
    
    func test_delete_hasNoSideEffectsOnFailure() {
        let noPermissionURL = cachesDirectory()
        let sut = makeSUT(storeURL: noPermissionURL)

        delete(sut)
        expect(sut, toRetrieve: .empty)
    }
    
    func test_storeSideEffects_runSerrially() {
        
        let sut = makeSUT()
        var completionOperationsInOrder = [XCTestExpectation]()
        
        let op1 = expectation(description: "Operation 1")
        sut.insert(uniqueFeeds().local, timestamp: Date(), completion: {_ in
            completionOperationsInOrder.append(op1)
            op1.fulfill()
        })
        
        let op2 = expectation(description: "Operation 2")
        sut.deleteCachedFeed { _ in
            completionOperationsInOrder.append(op2)
            op2.fulfill()
        }
        
        let op3 = expectation(description: "Operation 3")
        sut.insert(uniqueFeeds().local, timestamp: Date()) { _ in
            completionOperationsInOrder.append(op3)
            op3.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(completionOperationsInOrder, [op1, op2, op3])
        
    }
    
    // MARK: - Helpers
    private func makeSUT(storeURL: URL? = nil, file: StaticString = #filePath, line: UInt = #line) -> FeedStore {
        let store = CodableFeedStore(storeURL: storeURL ?? testSpecificStoreURL())
        trackForMemoryLeaks(store, file: file, line: line)
        return store
    }
    
    private func expect(_ sut: FeedStore, toRetrieve expectedResult: RetrieveCachedFeedResult, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "Wait for cache retrieval")
        sut.retrieve { receivedResult in
            switch (receivedResult, expectedResult) {
            case (.empty, .empty), (.failure, .failure):
                break
            case let (.found(receivedFeed, receivedTimestamp), .found(expectedFeed, expectedTimestamp)):
                XCTAssertEqual(receivedFeed, expectedFeed)
                XCTAssertEqual(receivedTimestamp, expectedTimestamp)
            default:
                XCTFail("Expected result \(expectedResult), got \(receivedResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
    
    private func expect(_ sut: FeedStore, toRetrieveTwice expectedResult: RetrieveCachedFeedResult, file: StaticString = #filePath, line: UInt = #line) {
        expect(sut, toRetrieve: expectedResult)
        expect(sut, toRetrieve: expectedResult)
    }
    
    @discardableResult
    private func insert(_ cache: (feed: [LocalFeedImage], timestamp: Date), to sut: FeedStore, file: StaticString = #filePath, line: UInt = #line) -> Error? {
        let exp = expectation(description: "Wait for cache insertion")
        var receivedError: Error?
        sut.insert(cache.feed, timestamp: cache.timestamp) { insertError in
            receivedError = insertError
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        return receivedError
    }
    
    @discardableResult
    private func delete(_ sut: FeedStore,  file: StaticString = #filePath, line: UInt = #line) -> Error? {
        let exp = expectation(description: "Wait for cache deletion")
        var deletionError: Error?
        sut.deleteCachedFeed { error in
            deletionError = error
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
        return deletionError
    }
    
    private func testSpecificStoreURL() -> URL {
        return cachesDirectory().appendingPathComponent("\(type(of: self)).store")
    }
    
    private func cachesDirectory() -> URL {
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    
    private func setUpEmptyStoreState() {
        deleteStoreArtifacts()
    }
    
    private func undoStoreArtifacts() {
        deleteStoreArtifacts()
    }
    
    private func deleteStoreArtifacts() {
        try? FileManager.default.removeItem(at: testSpecificStoreURL())
    }
}
