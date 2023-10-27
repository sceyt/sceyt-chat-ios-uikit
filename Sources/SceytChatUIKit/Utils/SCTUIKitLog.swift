//
//  SCTUIKitLog.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 17.07.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Foundation

@inlinable
public func formatLogMessage(_ logString: String,
                                file: String = #file,
                                function: String = #function,
                                line: Int = #line) -> String {
    let filename = (file as NSString).lastPathComponent
    // We format the filename & line number in a format compatible
    // with XCode's "Open Quickly..." feature.
    return "[SceytChatUIKit: \(filename):\(line) \(function)]: \(logString)"
}

var log: SCTUIKitLog.Type {
    Components.logger.self
}

let formatter: ISO8601DateFormatter = {
   let formatter = ISO8601DateFormatter()
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter
}()

open class SCTUIKitLog {
    
    open class func verbose(_ logString: @autoclosure () -> String,
                            file: String = #file,
                            function: String = #function,
                            line: Int = #line) {
        
        print("[VERBOSE] \(formatter.string(from: Date()))", formatLogMessage(logString(), file: file, function: function, line: line))
    }

    open class func debug(_ logString: @autoclosure () -> String,
                          file: String = #file,
                          function: String = #function,
                          line: Int = #line) {
        debugPrint("[DEBUG] \(formatter.string(from: Date()))", formatLogMessage(logString(), file: file, function: function, line: line))
    }

    open class func info(_ logString: @autoclosure () -> String,
                         file: String = #file,
                         function: String = #function,
                         line: Int = #line) {
        print("[INFO] \(formatter.string(from: Date()))", formatLogMessage(logString(), file: file, function: function, line: line))
    }

    open class func warn(_ logString: @autoclosure () -> String,
                         file: String = #file,
                         function: String = #function,
                         line: Int = #line) {
        print("[WARN] \(formatter.string(from: Date()))", formatLogMessage(logString(), file: file, function: function, line: line))
    }

    open class func error(_ logString: @autoclosure () -> String,
                          file: String = #file,
                          function: String = #function,
                          line: Int = #line) {
        print("[ERROR] \(formatter.string(from: Date()))", formatLogMessage(logString(), file: file, function: function, line: line))
    }

    internal class func errorIfNotNil( _ error: Error?,
                                       _ logString: @autoclosure () -> String,
                                       file: String = #file,
                                       function: String = #function,
                                       line: Int = #line) {
        if let error {
            log.error(logString() + " error: \(error)", file: file, function: function, line: line)
        }
    }
}
