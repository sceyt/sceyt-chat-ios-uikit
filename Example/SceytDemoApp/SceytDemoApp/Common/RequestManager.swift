//
//  RequestManager.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

class RequestManager {
    
    // MARK: - HTTP Methods Enum
    enum HTTPMethod: String {
        case GET
        case POST
        case PUT
        case DELETE
    }
    
    // MARK: - Generic Request Sender
    static func sendRequest(urlString: String, method: HTTPMethod, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil, nil, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            DispatchQueue.main.async {
                completion(data, response, error)
            }
        })
        task.resume()
    }
    
    // MARK: - Check Username Availability
    static func checkUsernameAvailability(username: String, completion: @escaping (Bool?) -> Void) {
        let urlString = "https://ebttn1ks2l.execute-api.us-east-2.amazonaws.com/user/check/\(username)"
        
        sendRequest(urlString: urlString, method: .GET) { data, response, error in
            if let error = error {
                print("Error checking username availability: \(error)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil)
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Username is available
                completion(true)
            case 400:
                // Username is taken
                completion(false)
            default:
                // Handle other cases
                completion(nil)
            }
        }
    }
    
    // MARK: - Delete User
    static func deleteUser(userId: String, completion: @escaping (Bool) -> Void) {
        let urlString = "https://ebttn1ks2l.execute-api.us-east-2.amazonaws.com/user/\(userId)"
        
        sendRequest(urlString: urlString, method: .DELETE) { data, response, error in
            if let error = error {
                print("Error deleting user: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                // User successfully deleted
                completion(true)
            default:
                // Deletion failed
                completion(false)
            }
        }
    }
}
