//
//  Cades.m
//  CreateFile
//
//  Created by tester on 24.12.2020.
//

#import <Foundation/Foundation.h>
#import "Cades.h"
#import "SignFile.h"


@implementation Cades

+(DWORD) getReaderCertificates: (NSArray**) outCerts
{
    PCCERT_CONTEXT* certs;
    size_t count;
    DWORD rv = get_reader_certs(&certs, &count);

    if (rv != ERROR_SUCCESS) {
        return rv;
    }

    NSMutableArray* wrapped_certs = [NSMutableArray new];
    for (int i=0; i != count; ++i) {
        [wrapped_certs addObject: [[Certificate alloc] initWithRawCert: certs[i]]];
    }

    if (count != 0)
        free(certs);
    
    *outCerts = wrapped_certs;
    
    return ERROR_SUCCESS;
}

+(DWORD) getStoreCertificates: (NSArray**) outCerts
{
    PCCERT_CONTEXT* certs;
    size_t count;
    DWORD rv = get_store_certs(&certs, &count);

    if (rv != ERROR_SUCCESS) {
        return rv;
    }

    NSMutableArray* wrapped_certs = [NSMutableArray new];
    for (int i=0; i != count; ++i) {
        [wrapped_certs addObject: [[Certificate alloc] initWithRawCert: certs[i]]];
    }

    if (count != 0)
        free(certs);
    
    *outCerts = wrapped_certs;
    
    return ERROR_SUCCESS;
}

+(DWORD) signData : (NSData*) msg withCert : (Certificate*) cert withPin : (NSString*) pin withTSP: (NSString*) tsp signature: (NSString**) outSignature
{
    char* signature = 0;
    DWORD rv = do_low_sign([pin cStringUsingEncoding: NSUTF8StringEncoding], msg.bytes, msg.length, cert.rawCert, [tsp UTF8String], &signature);
    
    if (rv != ERROR_SUCCESS) {
        return rv;
    }

    *outSignature = [[NSString alloc] initWithUTF8String: signature];
    return ERROR_SUCCESS;
}

+(DWORD) verifySignature: (NSString*) signature status: (NSInteger) verificationStatus
{
    DWORD status;
    DWORD rv = do_low_verify([signature UTF8String], &status);
    
    if (rv != ERROR_SUCCESS) {
        return rv;
    }
    
    verificationStatus = status;
    return ERROR_SUCCESS;
}

+(DWORD) closeCertificates: (NSArray*) certificates
{
    DWORD lastError = ERROR_SUCCESS;
    for (Certificate* cert in certificates) {
        DWORD rv = [cert close];
        if (rv != ERROR_SUCCESS) {
            lastError = rv;
        }
    }
    
    return lastError;
}
@end
