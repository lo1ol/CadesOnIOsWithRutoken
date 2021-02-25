//
//  Cades.m
//  CreateFile
//
//  Created by tester on 24.12.2020.
//

#import <Foundation/Foundation.h>
#import "Cades.h"
#import "CadesError.h"
#import "CadesImpl.h"


@implementation Cades

+ (void)onError:(NSError*)error callback:(void (^)(NSError*))callback {
    dispatch_async(dispatch_get_main_queue(), ^() {
        callback(error);
    });
}

+ (void)onErrorWithCode: (DWORD) code callback:(void (^)(NSError*))callback {
    [Cades onError: [CadesError errorWithCode: code] callback: callback];
}

+(void) getCertificatesWithSuccessCallback: (void (^)(NSArray* certs)) successCallback errorCallback: (void(^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        PCCERT_CONTEXT* certs;
        size_t count;
        DWORD rv = get_certs(&certs, &count);
        
        if (rv != ERROR_SUCCESS) {
            [Cades onErrorWithCode: rv callback: errorCallback];
            return;
        }
        
        NSMutableArray* wrapped_certs = [NSMutableArray new];
        for (int i=0; i != count; ++i) {
            [wrapped_certs addObject: [[Certificate alloc] initWithRawCert: certs[i]]];
        }
        
        if (count != 0)
            free(certs);
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            successCallback(wrapped_certs);
        });
    });
}

+(void) signData : (NSData*) msg withCert : (Certificate*) cert withPin : (NSString*) pin withTSP: (NSString*) tsp successCallback: (void (^)(NSString* signture)) successCallback errorCallback: (void(^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        char* signature = 0;
        DWORD rv = do_low_sign([pin cStringUsingEncoding: NSUTF8StringEncoding], msg.bytes, msg.length, cert.rawCert, [tsp UTF8String], &signature);
        
        if (rv != ERROR_SUCCESS) {
            [Cades onErrorWithCode: rv callback: errorCallback];
            return;
        }
    
        NSString *wrapped_signature = [[NSString alloc] initWithUTF8String: signature];
    
        dispatch_async(dispatch_get_main_queue(), ^() {
            successCallback(wrapped_signature);
        });
    });
}

+(void) verifySignature: (NSString*) signature successCallback: (void (^)(NSInteger verificationStatus)) successCallback errorCallback: (void(^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        __block DWORD status;
        DWORD rv = do_low_verify([signature UTF8String], &status);
        
        if (rv != ERROR_SUCCESS) {
            [Cades onErrorWithCode: rv callback: errorCallback];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            successCallback(status);
        });
    });
}

+(void) closeCertificates : (NSArray*) certificates  successCallback: (void (^)(void)) successCallback errorCallback: (void (^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        DWORD lastError = ERROR_SUCCESS;
        for (Certificate* cert in certificates) {
            DWORD rv = [cert close];
            if (rv != ERROR_SUCCESS) {
                lastError = rv;
            }
        }
        
        if (lastError != ERROR_SUCCESS) {
            [self onErrorWithCode:lastError callback:errorCallback];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            successCallback();
        });
    });
}

+(void) verifyCertificate : (Certificate*) certificate successCallback: (void (^)(DWORD status)) successCallback errorCallback: (void (^)(NSError*)) errorCallback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        DWORD status;
        DWORD rv = [certificate verifyWithStatus: &status];
        
        if (rv != ERROR_SUCCESS) {
            [self onErrorWithCode:rv callback:errorCallback];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^() {
            successCallback(status);
        });
    });
}
@end
