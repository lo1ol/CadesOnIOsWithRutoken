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

+(NSArray*) getCertificates;
+(NSString*) signData : (NSData*) msg  withCert: (Certificate*) cert withTSP: (NSString*) tsp;
+(BOOL) verifySignature : (NSString*) signature;
+(void) closeCertificates : (NSArray*) certificates;

@end

#endif /* Cades_h */
