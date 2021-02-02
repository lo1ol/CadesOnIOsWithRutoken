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

+(DWORD) getReaderCertificates: (NSArray**) outCerts;
+(DWORD) getStoreCertificates: (NSArray**) outCerts;
+(DWORD) signData : (NSData*) msg withCert : (Certificate*) cert withPin : (NSString*) pin withTSP: (NSString*) tsp signature: (NSString**) signture;
+(DWORD) verifySignature: (NSString*) signature status: (NSInteger) verificationStatus;
+(DWORD) closeCertificates: (NSArray*) certificates;

@end

#endif /* Cades_h */
