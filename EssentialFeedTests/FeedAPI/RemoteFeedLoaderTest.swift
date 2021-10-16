//
//  RemoteFeedLoaderTest.swift
//  EssentialFeedTests
//
//  Created by Jhonatahan Orlando Rivera Vilcapoma on 3/09/21.
//

import XCTest
import EssentialFeed

class RemoteFeedLoaderTest: XCTestCase {
    
    func test_init_doesNotRequestDataFromURL(){
        let (_, client) = makeRemote()
        
        XCTAssertTrue(client.requestedURLs.isEmpty)
    }
    
    func test_load_requestsDataFromURL() {
        let url = URL(string: "https://given-url.com")!
        let (remote, client) = makeRemote(url:url)
        
        remote.load{_ in}
        
        XCTAssertEqual(client.requestedURLs, [url])
    }
    
    func test_loadTwice_requestsDataFromURLTwice() {
        let url = URL(string: "https://given-url.com")!
        let (remote, client) = makeRemote(url:url)
        
        remote.load{_ in}
        remote.load{_ in}
        XCTAssertEqual(client.requestedURLs, [url,url])
    }
    
    func test_load_deliversErrorOnClientError() {
        let (remote, client) = makeRemote()
        
        expect(remote, toCompleteWith: failure(.connectivity), when: {
            let clientError = NSError(domain: "Test", code: 0)
            client.complete(with: clientError)
        })
    }
    
    func test_load_deliversErrorOnNon200HTTPResponse() {
        let (remote, client) = makeRemote()
        
        let samples = [199,201,300,400,500]
        samples.enumerated().forEach { index, code in
            
            expect(remote, toCompleteWith: failure(.invalidData), when: {
                 let jsonData = makeItemsJSON([])
                client.complete(withStatusCode: code, data: jsonData, at: index)
            })
        }
    }
    
    func test_load_deliversON200HTTPResponseInvalidJSON(){
        let (remote, client) = makeRemote()
        
        expect(remote, toCompleteWith: failure(.invalidData), when: {
            let invalidJSON = Data("invalid json".utf8)
            client.complete(withStatusCode: 200, data: invalidJSON)
        })
    }
    
    func test_deliversOn200HTTPResponseEmptyJSON(){
        let (remote, client) = makeRemote()
        
        expect(remote, toCompleteWith: .success([]), when:{
            let emptyListJSON = makeItemsJSON([])
            client.complete(withStatusCode: 200, data: emptyListJSON)
        })
    }
    
    func test_deliversOn200HTTPResponseJSONItems(){
        let (remote, client) = makeRemote()
        let item1 = makeItem(
            id: UUID(),
            imageURL: URL(string: "http://a-url.com")!)
  
        
        let item2 = makeItem(
            id: UUID(),
            description: "a description",
            location: "a location",
            imageURL: URL(string: "http://b-url.com")!)
        
        
        let items = [item1.model,item2.model]
        expect(remote, toCompleteWith: .success(items), when:{
            let json = makeItemsJSON([item1.json,item2.json])
            client.complete(withStatusCode: 200, data: json)
        })
    }
    
    func test_dontCallLoadForRemoteDeallocated(){
        let url = URL(string: "http://a-url.com")!
        let client = HTTPClientSpy()
        var remote:RemoteFeedLoader? = RemoteFeedLoader(url: url, client: client)
        
        var captureResults = [RemoteFeedLoader.Result]()
        remote?.load {captureResults.append($0)}
        
        remote = nil
        client.complete(withStatusCode: 200, data: makeItemsJSON([]))
        
        XCTAssertTrue(captureResults.isEmpty)
        
    }
    
    //MARK: - Helpers
    private func makeRemote(url:URL = URL(string: "https://a-given-url.com")!, file: StaticString = #filePath, line: UInt = #line)->(remote: RemoteFeedLoader, client: HTTPClientSpy){
        let client = HTTPClientSpy()
        let remote = RemoteFeedLoader(url:url, client: client)
        trackForMemoryLeaks(remote)
        trackForMemoryLeaks(client)
        return (remote,client)
    }
    
    private func failure(_ error: RemoteFeedLoader.Error) -> RemoteFeedLoader.Result{
        return .failure(error)
    }
    
    private func makeItem(id:UUID, description:String? = nil, location:String? = nil, imageURL:URL)->(model:FeedItem, json:[String:Any]){
        
        let item = FeedItem(id: id, description: description, location: location, imageURL: imageURL)
        
        let json = [
            "id" : id.uuidString,
            "description" : description,
            "location" : location,
            "image" : imageURL.absoluteString
        ].reduce(into: [String:Any]()) { (accumulate, element) in
            if let value = element.value{
                accumulate[element.key] = value
            }
        }
        
        return(item,json)
    }
    
    private func makeItemsJSON(_ items:[[String:Any]]) -> Data {
        let json = ["items": items]
        let data = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        print("JSON: \(data)")
        return data
    }
    
    private func expect(_ remote: RemoteFeedLoader, toCompleteWith expectedResult: RemoteFeedLoader.Result, when action:()->Void,  file: StaticString = #filePath, line: UInt = #line){
        let exp = expectation(description: "Wailt for load compleation")
        exp.assertForOverFulfill = false
        remote.load {receivedResult in
            switch (receivedResult, expectedResult){
            case (let .success(receivedItems), let .success(expectedItems)):
                XCTAssertEqual(receivedItems, expectedItems, file:file, line:line)
            case (let .failure(receivedError as RemoteFeedLoader.Error), let .failure(expectedError as RemoteFeedLoader.Error)):
                XCTAssertEqual(receivedError, expectedError, file:file, line:line)
            default:
                XCTFail("Expected result \(expectedResult) got \(receivedResult) instead", file:file, line:line)
            }
            exp.fulfill()
        }
        action()
        wait(for: [exp], timeout: 1.0)
    }
    
    private class HTTPClientSpy:HTTPClient{
        private var messages = [(url:URL, completion:(HTTPClientResult)->Void)]()
        
        var requestedURLs: [URL]{
            return messages.map{$0.url}
        }
        
        func get(from url:URL, completion: @escaping (HTTPClientResult)->Void){
            messages.append((url,completion))
        }
        
        func complete(with error: Error, at index: Int = 0){
            messages[index].completion(.failure(error))
        }
        
        func complete(withStatusCode code: Int, data: Data, at index: Int = 0){
            let response = HTTPURLResponse(
                url: requestedURLs[index],
                statusCode: code,
                httpVersion: nil,
                headerFields: nil)!
            messages[index].completion(.success(data,response))
        }
    }
}
