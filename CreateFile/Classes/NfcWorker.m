//
//  NfcWorker.m
//  CreateFile
//
//  Created by tester on 29.01.2021.
//
#import "NfcWorker.h"
#import "CadesError.h"

#import <Foundation/Foundation.h>

#import <rtpkcs11ecp/rtpkcs11.h>
#import <RtPcsc/rtnfc.h>

static NSString* const gPkcs11Domain = @"ru.cryptopro.pkcs11";


@implementation NfcWorker

+(void) waitForTokenWithStopFlag: (bool*) pStopFlag withLock: (NSLock *) lock successCallback:(void(^)(void)) successCallback errorCallback: (void(^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        for (;;) {
            CK_SLOT_ID slot;
            
            [lock lock];
            if (*pStopFlag) {
                return;
            }
            
            CK_RV rv = C_WaitForSlotEvent(CKF_DONT_BLOCK, &slot, NULL);
            
            if (rv == CKR_OK) {
                CK_SLOT_INFO slotInfo;
                C_GetSlotInfo(slot, &slotInfo);
                if (slotInfo.flags & CKF_TOKEN_PRESENT){
                    dispatch_async(dispatch_get_main_queue(), ^() {
                        successCallback();
                    });
                    return;
                }
            } else if (rv != CKR_NO_EVENT) {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    errorCallback([NSError errorWithDomain:gPkcs11Domain code:rv userInfo:nil]);
                });
                return;
            }
            [lock unlock];
            
            sleep(1);
        }
    });
}

+(void) startNfcSessionWithSucessCallback: (void(^)(void)) successCallback errorCallback: (void(^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(){
        
        CK_C_INITIALIZE_ARGS initArgs = { NULL_PTR, NULL_PTR, NULL_PTR, NULL_PTR, CKF_OS_LOCKING_OK, NULL_PTR };
        C_Initialize(&initArgs);

        __block NSLock* lock = [NSLock new];
        __block bool stopFlag = false;
        
        void (^internalSuccessCallback)(void) =
            ^void(void)
            {
                C_Finalize(NULL);
                dispatch_async(dispatch_get_main_queue(), ^() {
                    successCallback();
                });
            };
        
        void (^internalErrorCallback)(NSError*) =
            ^void(NSError* error)
            {
                [lock lock];
                stopFlag = true;
                C_Finalize(NULL);
                [lock unlock];
                
                dispatch_async(dispatch_get_main_queue(), ^() {
                    errorCallback(error);
                });
            };
        
        startNFC(internalErrorCallback);
        
        [self waitForTokenWithStopFlag: &stopFlag withLock: lock successCallback:internalSuccessCallback errorCallback:errorCallback];
    });
}

+(void) stopNfcSessionWithSuccessCallback:(void(^)(void)) successCallback
{
    stopNFC();
}
@end
