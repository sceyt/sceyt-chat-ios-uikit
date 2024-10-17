//
//  RequestManager.swift
//  SceytDemoApp
//
//  Created by Arthur Avagyan on 16.10.24
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation

class RequestManager {
    static func checkUsernameAvailability(username: String, completion: @escaping (Bool?) -> Void) {
        let urlString = "https://ebttn1ks2l.execute-api.us-east-2.amazonaws.com/user/check/\(username)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
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
        task.resume()
    }
}
