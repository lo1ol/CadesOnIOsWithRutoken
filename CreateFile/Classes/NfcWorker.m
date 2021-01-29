//
//  NfcWorker.m
//  CreateFile
//
//  Created by tester on 29.01.2021.
//
#import "NfcWorker.h"

#import <Foundation/Foundation.h>

#import <rtpkcs11ecp/rtpkcs11.h>
#import <RtPcsc/rtnfc.h>

@implementation NfcWorker

+(void) waitForTokenWithStopFlag: (bool*) pStopFlag withLock: (NSLock *) lock successCallback:(void(^)(void)) successCallback errorCallback: (void(^)(void)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        for (;;) {
            CK_SLOT_ID slot;
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
            }
            
            [lock lock];
            bool stopFlag = *pStopFlag;
            [lock unlock];
            
            if (stopFlag) {
                dispatch_async(dispatch_get_main_queue(), ^() {
                    errorCallback();
                });
                return;
            }
            
            sleep(1);
        }
    });
}

+(void) startNfcSessionWithNfcErrorCallback: (void(^)(NSError* error)) nfcErrorCallback sucessCallback: (void(^)(void)) successCallback errorCallback: (void(^)(void)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(){
        
        CK_C_INITIALIZE_ARGS initArgs = { NULL_PTR, NULL_PTR, NULL_PTR, NULL_PTR, CKF_OS_LOCKING_OK, NULL_PTR };
        C_Initialize(&initArgs);

        __block NSLock* lock = [NSLock new];
        __block bool stopFlag = false;

        void (^internalNfcErrorCallback)(NSError* error) =
            ^void(NSError* error)
            {
                [lock lock];
                stopFlag = true;
                [lock unlock];
                C_Finalize(NULL);
                
                dispatch_async(dispatch_get_main_queue(), ^() {
                    nfcErrorCallback(error);
                });
            };
        
        startNFC(internalNfcErrorCallback);
        
        void (^internalSuccessCallback)(void) =
            ^void(void)
            {
                C_Finalize(NULL);
                dispatch_async(dispatch_get_main_queue(), ^() {
                    successCallback();
                });
            };
        
        void (^internalErrorCallback)(void) =
            ^void(void)
            {
                C_Finalize(NULL);
                dispatch_async(dispatch_get_main_queue(), ^() {
                    errorCallback();
                });
            };
        
            dispatch_async(dispatch_get_main_queue(), ^() {
                [self waitForTokenWithStopFlag: &stopFlag withLock: lock successCallback:internalSuccessCallback errorCallback:errorCallback];
            });
    });
}

+(void) stopNfcSessionWithSuccessCallback:(void(^)(void)) successCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(){
        stopNFC();
        dispatch_async(dispatch_get_main_queue(), ^() {
            successCallback();
        });
    });
}
@end
