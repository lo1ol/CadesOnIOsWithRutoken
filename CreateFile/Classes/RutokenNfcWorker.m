//
//  NfcWorker.m
//  CreateFile
//
//  Created by tester on 29.01.2021.
//
#import "RutokenNfcWorker.h"

#import <Foundation/Foundation.h>

#import <RtPcsc/rtnfc.h>
#import <RtPcsc/winscard.h>

static NSString* const gScardErrorDomain = @"ru.rutoken.scard";

@implementation RutokenNfcWorker

+(NSInteger) waitForTokenWithStopFlag: (bool*) pStopFlag lock: (NSLock *) lock
{
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
                goto close_context;
        } else if (rgReaderStates.dwEventState == SCARD_STATE_CHANGED) {
            goto close_context;
        }
        
        [lock lock];
        stopFlag = *pStopFlag;
        [lock unlock];
        
        if (stopFlag)
            goto close_context;
    }
    
close_context:
    SCardReleaseContext(hContext);
    
exit:
    return rv;
}

@end
