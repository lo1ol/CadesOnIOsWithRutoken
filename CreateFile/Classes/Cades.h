//
//  Cades.h
//  CreateFile
//
//  Created by tester on 24.12.2020.
//

#ifndef Cades_h
#define Cades_h

#import "Certificate.h"

@interface Cades : NSObject

+(void) getCertificatesWithSuccessCallback: (void (^)(NSArray* certs)) successCallback errorCallback: (void(^)(NSError*)) errorCallback;
+(void) signData : (NSData*) msg  withCert: (Certificate*) cert withPin: (NSString*) pin withTSP: (NSString*) tsp successCallback: (void (^)(NSString* signture)) successCallback errorCallback: (void(^)(NSError*)) errorCallback;
+(void) verifySignature : (NSString*) signature successCallback: (void (^)(NSInteger verificationStatus)) successCallback errorCallback: (void(^)(NSError*)) errorCallback;
+(void) closeCertificates : (NSArray*) certificates successCallback: (void (^)(void)) successCallback errorCallback: (void (^)(NSError*)) errorCallback;
+(void) verifyCertificate : (Certificate*) certificate successCallback: (void (^)(DWORD status)) successCallback errorCallback: (void (^)(NSError*)) errorCallback;

@end

#endif /* Cades_h */
