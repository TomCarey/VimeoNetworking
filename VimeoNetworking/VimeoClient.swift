//
//  VimeoClient.swift
//  VimeoNetworkingExample-iOS
//
//  Created by Huebner, Rob on 3/21/16.
//  Copyright © 2016 Vimeo. All rights reserved.
//

import Foundation

protocol Mappable
{
    static var mappingClass: AnyClass? { get }
    
    static var modelKeyPath: String? { get }
}

extension VIMModelObject: Mappable
{
    static var mappingClass: AnyClass?
    {
        return self
    }
    
    static var modelKeyPath: String?
    {
        return nil
    }
}

extension Array: Mappable
{
    // The default implementation for all arrays will return no mapping class or model key path
    // Only if Element itself is a VIMModelObject will the values be returned
    // This is because we can't restrict the generic type if we're 
    // extending a type with generics to conform to a protocol [RH]
    
    static var mappingClass: AnyClass?
    {
        if Element.self is VIMModelObject.Type
        {
            return (Element.self as! AnyClass)
        }
        
        return nil
    }
    
    static var modelKeyPath: String?
    {
        if Element.self is VIMModelObject.Type
        {
            return "data"
        }
        
        return nil
    }
}

enum Result<ModelType where ModelType: Mappable>
{
    case Success(result: ModelType)
    case Failure(error: NSError)
}

/// This dummy enum acts as a generic typealias
enum RequestCompletion<ModelType where ModelType: Mappable>
{
    typealias T = (result: Result<ModelType>) -> Void
}

enum Method
{
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}

struct Request<ModelType where ModelType: Mappable>
{
    init(method: Method = .GET, path: String = "/", parameters: RequestParameters? = nil, modelKeyPath: String? = nil)
    {
        self.method = method
        self.path = path
        self.parameters = parameters
        self.modelKeyPath = modelKeyPath
    }
    
    let method: Method
    
    let path: String
    
    let parameters: RequestParameters?
    
    let modelKeyPath: String?
}

extension Request
{
    static func meRequest() -> Request
    {
        return Request(path: "/me")
    }

    static func meFollowingRequest() -> Request
    {
        return Request(path: "/me/following")
    }
}

class VimeoClient
{
    let sessionManager: VimeoSessionManager
    
    init(sessionManager: VimeoSessionManager)
    {
        self.sessionManager = sessionManager
    }
    
    func request<ModelType where ModelType: Mappable>(request: Request<ModelType>, completion: RequestCompletion<ModelType>.T)
    {
        let urlString = request.path
        let parameters = request.parameters
        
        let success: (NSURLSessionDataTask, AnyObject?) -> Void = { (task, responseObject) in
            self.requestSuccess(request: request, task: task, responseObject: responseObject, completion: completion)
        }
        
        let failure: (NSURLSessionDataTask?, NSError) -> Void = { (task, error) in
            self.requestFailure(request: request, task: task, error: error, completion: completion)
        }
        
        switch request.method
        {
        case .GET:
            self.sessionManager.GET(urlString, parameters: parameters, success: success, failure: failure)
        case .POST:
            self.sessionManager.POST(urlString, parameters: parameters, success: success, failure: failure)
        case .PUT:
            self.sessionManager.PUT(urlString, parameters: parameters, success: success, failure: failure)
        case .PATCH:
            self.sessionManager.PATCH(urlString, parameters: parameters, success: success, failure: failure)
        case .DELETE:
            self.sessionManager.DELETE(urlString, parameters: parameters, success: success, failure: failure)
        }
    }
    
    private func requestSuccess<ModelType where ModelType: Mappable>(request request: Request<ModelType>, task: NSURLSessionDataTask, responseObject: AnyObject?, completion: RequestCompletion<ModelType>.T)
    {
        guard let responseDictionary = responseObject as? [String: AnyObject]
        else
        {
            assertionFailure("requestSuccess returned invalid/absent dictionary")
            
            let error = NSError(domain: "", code: 0, userInfo: nil) // TODO: fill out error [RH] (3/21/16)
            
            self.requestFailure(request: request, task: task, error: error, completion: completion)
            
            return
        }
        
        // Serialize the dictionary into a model object
        
        guard let mappingClass = ModelType.mappingClass
        else
        {
            assertionFailure("no mapping class found")
            
            let error = NSError(domain: "", code: 0, userInfo: nil) // TODO: fill out error [RH] (3/21/16)
            
            self.requestFailure(request: request, task: task, error: error, completion: completion)
            
            return
        }
        
        let objectMapper = VIMObjectMapper()
        let modelKeyPath = request.modelKeyPath ?? ModelType.modelKeyPath
        objectMapper.addMappingClass(mappingClass, forKeypath: modelKeyPath ?? "")
        var mappedObject = objectMapper.applyMappingToJSON(responseDictionary)
        
        if let modelKeyPath = modelKeyPath
        {
            mappedObject = (mappedObject as? [String: AnyObject])?[modelKeyPath]
        }
        
        guard let modelObject = mappedObject as? ModelType
        else
        {
            assertionFailure("couldn't map")
            
            let error = NSError(domain: "", code: 0, userInfo: nil) // TODO: fill out error [RH] (3/21/16)
            
            self.requestFailure(request: request, task: task, error: error, completion: completion)
            
            return
        }
        
        completion(result: .Success(result: modelObject))
    }
    
    private func requestFailure<ModelType where ModelType: Mappable>(request request: Request<ModelType>, task: NSURLSessionDataTask?, error: NSError, completion: RequestCompletion<ModelType>.T)
    {
        
        
        completion(result: .Failure(error: error))
    }
}