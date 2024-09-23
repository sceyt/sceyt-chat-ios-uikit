//
//  SceytChatUIKit+Logger.swift
//  SceytChatUIKit
//
//  Created by Arthur Avagyan on 23.09.24.
//  Copyright © 2024 Sceyt LLC. All rights reserved.
//

import Foundation
import SceytChat

/// A convenience variable to access the `Logger` type from `Components` for internal usage.
var logger: SceytChatUIKit.Logger.Type {
    Components.logger.self
}

extension SceytChatUIKit {
    /// The `Logger` class provides logging functionalities for the SceytChatUIKit.
    open class Logger {
        
        /// Represents the logging levels available in the `Logger`.
        public enum LogLevel: Int, Comparable {
            /// No logging.
            case none = 0
            /// Fatal errors.
            case fatal
            /// Error messages.
            case error
            /// Warning messages.
            case warning
            /// Informational messages.
            case info
            /// Debug messages.
            case debug
            /// Verbose messages.
            case verbose
            
            /// Maps the `Logger.LogLevel` to the SDK's `SceytChat.LogLevel`.
            public var sceytLogLevel: SceytChat.LogLevel {
                switch self {
                case .none:
                    return .none
                case .fatal:
                    return .fatal
                case .error:
                    return .error
                case .warning:
                    return .warning
                case .info:
                    return .info
                case .debug:
                    return .verbose  // Since SceytChat SDK doesn't have `debug`, map to `verbose`.
                case .verbose:
                    return .verbose
                }
            }
            
            /// Implements the `<` operator to allow comparison of `LogLevel` values.
            public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
        }
        
        /// Type alias for the logging callback function.
        public typealias CallBack = (
            _ logMessage: String,
            _ logLevel: LogLevel,
            _ logString: String,
            _ file: String,
            _ function: String,
            _ line: Int
        ) -> Void
        
        /// The current log level for the `Logger`.
        public private(set) static var logLevel: LogLevel = .verbose
        
        /// The date formatter used for formatting the log messages.
        public static var formatter: any DateFormatting = SceytChatUIKit.shared.formatters.logDateFormatter
        
        /// A closure that gets called every time a log is printed.
        ///
        /// - Parameters:
        ///   - logMessage: The formatted log message.
        ///   - logLevel: The level of the log message.
        ///   - logString: The original log string provided by the caller.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        public private(set) static var onLog: CallBack?
        
        /// Sets the current log level and an optional callback for log events.
        ///
        /// - Parameters:
        ///   - logLevel: The desired log level.
        ///   - callBack: An optional callback to handle log events.
        public class func setLogLevel(_ logLevel: LogLevel, callBack: CallBack?) {
            self.logLevel = logLevel
            onLog = callBack
        }
        
        // MARK: - Logging Methods
        
        /// Logs a verbose message.
        ///
        /// - Parameters:
        ///   - logString: The message to log.
        ///   - file: The file from which the log function was called. Defaults to the caller's file.
        ///   - function: The function from which the log function was called. Defaults to the caller's function.
        ///   - line: The line number from which the log function was called. Defaults to the caller's line.
        open class func verbose(
            _ logString: @autoclosure () -> String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard logLevel >= .verbose else { return }
            
            let message = "[VERBOSE] \(formatter.format(Date())) \(formatLogMessage(logString(), file: file, function: function, line: line))"
            print(message)
            onLog?(message, .verbose, logString(), file, function, line)
        }
        
        /// Logs an informational message.
        ///
        /// - Parameters:
        ///   - logString: The message to log.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        open class func info(
            _ logString: @autoclosure () -> String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard logLevel >= .info else { return }
            
            let message = "[INFO] \(formatter.format(Date())) \(formatLogMessage(logString(), file: file, function: function, line: line))"
            print(message)
            onLog?(message, .info, logString(), file, function, line)
        }
        
        /// Logs a warning message.
        ///
        /// - Parameters:
        ///   - logString: The message to log.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        open class func warn(
            _ logString: @autoclosure () -> String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard logLevel >= .warning else { return }
            
            let message = "[WARN] \(formatter.format(Date())) \(formatLogMessage(logString(), file: file, function: function, line: line))"
            print(message)
            onLog?(message, .warning, logString(), file, function, line)
        }
        
        /// Logs an error message.
        ///
        /// - Parameters:
        ///   - logString: The message to log.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        open class func error(
            _ logString: @autoclosure () -> String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard logLevel >= .error else { return }
            
            let message = "[ERROR] \(formatter.format(Date())) \(formatLogMessage(logString(), file: file, function: function, line: line))"
            print(message)
            onLog?(message, .error, logString(), file, function, line)
        }
        
        /// Logs a fatal error message.
        ///
        /// - Parameters:
        ///   - logString: The message to log.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        open class func fatal(
            _ logString: @autoclosure () -> String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard logLevel >= .fatal else { return }
            
            let message = "[FATAL] \(formatter.format(Date())) \(formatLogMessage(logString(), file: file, function: function, line: line))"
            print(message)
            onLog?(message, .fatal, logString(), file, function, line)  // Note: Should this be `.fatal`?
        }
        
        /// Logs a debug message.
        ///
        /// - Parameters:
        ///   - logString: The message to log.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        open class func debug(
            _ logString: @autoclosure () -> String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard logLevel >= .debug else { return }
            
            let message = "[DEBUG] \(formatter.format(Date())) \(formatLogMessage(logString(), file: file, function: function, line: line))"
            debugPrint(message)
            onLog?(message, .debug, logString(), file, function, line)
        }
        
        /// Logs an error message if the provided error is not nil.
        ///
        /// - Parameters:
        ///   - error: The optional error to check.
        ///   - logString: The message to log if the error is not nil.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        open class func errorIfNotNil(
            _ error: (any Error)?,
            _ logString: @autoclosure () -> String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            guard let error else { return }
            self.error("\(logString()) error: \(error)", file: file, function: function, line: line)
        }
        
        /// Formats the log message with the file, function, and line information.
        ///
        /// - Parameters:
        ///   - logString: The original log message.
        ///   - file: The file from which the log function was called.
        ///   - function: The function from which the log function was called.
        ///   - line: The line number from which the log function was called.
        ///
        /// - Returns: A formatted string containing the log message and context.
        @inlinable
        public class func formatLogMessage(
            _ logString: String,
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) -> String {
            let filename = (file as NSString).lastPathComponent
            let threadName = Thread.current.isMainThread ? "Main" : (Thread.current.name ?? "Thread \(Thread.current)")

            // We format the filename & line number in a format compatible
            // with Xcode's "Open Quickly..." feature.
            return "[SceytChatUIKit: \(filename):\(line) \(function) \(threadName)]: \(logString)"
        }
    }
}
