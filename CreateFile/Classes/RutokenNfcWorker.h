//
//  NfcWorker.h
//  CreateFile
//
//  Created by tester on 29.01.2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RutokenNfcWorker : NSObject

+(NSInteger) waitForTokenWithStopFlag: (bool*) pStopFlag lock: (NSLock *) lock;
@end

NS_ASSUME_NONNULL_END
