//
//  NfcWorker.h
//  CreateFile
//
//  Created by tester on 29.01.2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RutokenNfcWorker : NSObject

+(void) waitForTokenWithStopFlag: (bool*) pStopFlag withLock: (NSLock *) lock successCallback:(void(^)(void)) successCallback errorCallback: (void(^)(NSError*)) errorCallback;
+(void) startNfcSessionWithSucessCallback: (void(^)(void)) successCallback errorCallback: (void (^)(NSError* error, bool nfcWorks)) errorCallback;
+(void) stopNfcSessionWithSuccessCallback:(void(^)(void)) successCallback;
@end

NS_ASSUME_NONNULL_END
