//
//  NfcWorker.m
//  CreateFile
//
//  Created by tester on 29.01.2021.
//
#import "RutokenNfcWorker.h"
#import "CadesError.h"

#import <Foundation/Foundation.h>

#import <RtPcsc/rtnfc.h>
#import <RtPcsc/winscard.h>

static NSString* const gScardErrorDomain = @"ru.rutoken.scard";

@implementation RutokenNfcWorker

+(void) waitForTokenWithStopFlag: (bool*) pStopFlag withLock: (NSLock *) lock successCallback:(void(^)(void)) successCallback errorCallback: (void(^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        LONG rv;
        SCARDCONTEXT hContext;
        [lock lock];
        bool stopFlag = *pStopFlag;
        [lock unlock];
        
        rv = SCardEstablishContext(SCARD_SCOPE_SYSTEM, NULL, NULL, &hContext);
        if (rv != SCARD_S_SUCCESS)
            goto exit;
        
        for (;;) {
            DWORD cReaders;
            SCARD_READERSTATE rgReaderStates = {};
            
            rgReaderStates.szReader = "\\\\?PnP?\\Notification";
            cReaders = 1;
            
            rv = SCardGetStatusChange(hContext, 500, &rgReaderStates, cReaders);
            if (rv != SCARD_S_SUCCESS) {
                if (rv != SCARD_E_TIMEOUT)
                    goto exit;
            } else if (rgReaderStates.dwEventState == SCARD_STATE_CHANGED) {
                goto exit;
            }
            
            [lock lock];
            stopFlag = *pStopFlag;
            [lock unlock];
            
            if (stopFlag)
                goto exit;
        }
        
        SCardCancel(hContext);
        
exit:
        if (stopFlag)
            return;
        if (rv == SCARD_S_SUCCESS) {
            dispatch_async(dispatch_get_main_queue(), ^() {successCallback();});
        } else {
            NSError* error = [[NSError alloc] initWithDomain:gScardErrorDomain code:rv userInfo: nil];
            dispatch_async(dispatch_get_main_queue(), ^() { errorCallback(error); });
        }
    });
}

+(void) startNfcSessionWithSucessCallback: (void(^)(void)) successCallback
                            errorCallback: (void (^)(NSError* error, bool nfcWorks)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(){
        __block NSLock* lock = [NSLock new];
        __block bool stopFlag = false;
        
        void (^nfcErrorCallback)(NSError*) =
            ^void(NSError* error)
            {
                [lock lock];
                stopFlag = true;
                [lock unlock];
                
                errorCallback(error, false);
            };
        
        void (^internalErrorCallback)(NSError*) =
            ^void(NSError* error)
            {
                errorCallback(error, true);
            };
        
        startNFC(nfcErrorCallback);
        
        [self waitForTokenWithStopFlag: &stopFlag withLock: lock successCallback:successCallback errorCallback:internalErrorCallback];
    });
}

+(void) stopNfcSessionWithSuccessCallback:(void(^)(void)) successCallback
{
    stopNFC();
}
@end
