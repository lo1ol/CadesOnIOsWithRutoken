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
+(NSArray*) getCertificates
{
    PCCERT_CONTEXT* certs;
    size_t count;
    if (!get_certs(&certs, &count)) {
        NSException* myException = [NSException
                exceptionWithName:@"GetCerticateException"
                reason:@"Error while getting certificates"
                userInfo:nil];
        @throw myException;
    }
    
    NSMutableArray* wrapped_certs = [NSMutableArray new];
    for (int i=0; i != count; ++i) {
        [wrapped_certs addObject: [[Certificate alloc] initWithRawCert: certs[i]]];
    }
    
    free(certs);
    
    return wrapped_certs;
}

+(NSString*) signData : (NSData*) msg withCert : (Certificate*) cert withTSP: (NSString*) tsp
{
    char * signature = 0;
    bool res = do_low_sign(msg.bytes, msg.length, cert.rawCert, [tsp UTF8String], &signature);
    
    if (!res)
    {
        return nil;
    }
    
    NSString *wrapped_signature = [[NSString alloc] initWithUTF8String: signature ];
    
    return wrapped_signature;
}

+(BOOL) verifySignature : (NSString*) signature
{
    return do_low_verify([signature UTF8String]);
}

+(void) closeCertificates : (NSArray*) certificates
{
    for (Certificate* cert in certificates) {
        [cert close];
    }
}
@end
