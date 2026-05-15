//
//  ObjCExceptionCatcher.h
//  SceytChatUIKitObjCSupport
//
//  Swift's `do/catch` does not catch `NSException`. UIKit raises
//  `NSInternalInconsistencyException` (and friends) from
//  `performBatchUpdates` when the batch is malformed. This thin Objective-C
//  wrapper lets production code catch those exceptions so we can degrade
//  gracefully (log + reload) instead of crashing.
//
//  This target is an implementation detail of `SceytChatUIKit`. It is NOT
//  exposed via any `products` entry in Package.swift, so consumers of the
//  SceytChatUIKit package cannot import it directly.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject

/// Runs `block` inside an `@try`/`@catch`. Returns the caught NSException, or
/// nil if the block completed normally. Caller is responsible for inspecting
/// the exception's name / reason if it cares which exception was raised.
///
/// Swift bridged name: `ObjCExceptionCatcher.catching(_:)` — Swift's bare
/// `try` is a keyword, so we use `NS_SWIFT_NAME` to give it a usable name.
+ (nullable NSException *)tryBlock:(__attribute__((noescape)) void (^)(void))block
    NS_SWIFT_NAME(catching(_:));

@end

NS_ASSUME_NONNULL_END
