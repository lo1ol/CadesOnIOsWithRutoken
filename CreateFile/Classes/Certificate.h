//
//  Cerificate.h
//  CreateFile
//
//  Created by tester on 24.12.2020.
//

#ifndef Cerificate_h
#define Cerificate_h

#include <CPROCSP/CPROCSP.h>

@interface Certificate : NSObject
@property (readonly) NSString* serialNumber;
@property (readonly) NSString* signatureAlgorithm;
@property (readonly) NSString* issuer;
@property (readonly) NSString* subject;
@property (readonly) NSDate* notBefore;
@property (readonly) NSDate* notAfter;
@property (readwrite) PCCERT_CONTEXT rawCert;

-(Certificate*) initWithRawCert:(PCCERT_CONTEXT) rawCert;
-(DWORD) verifyWithStatus:(DWORD *) checkResult;
-(DWORD) close;

@end

#endif /* Cerificate_h */
