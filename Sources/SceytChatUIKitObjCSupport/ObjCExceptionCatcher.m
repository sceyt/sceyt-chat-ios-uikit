//
//  ObjCExceptionCatcher.m
//  SceytChatUIKitObjCSupport
//

#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (nullable NSException *)tryBlock:(__attribute__((noescape)) void (^)(void))block {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}

@end
