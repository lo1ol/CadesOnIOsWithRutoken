//
//  Certificate.m
//  CreateFile
//
//  Created by tester on 24.12.2020.
//

#import <Foundation/Foundation.h>
#import "Certificate.h"

#define MY_STRING_TYPE (CERT_OID_NAME_STR)

@implementation Certificate
@synthesize rawCert;

-(Certificate*) initWithRawCert:(PCCERT_CONTEXT) rawCert
{
    if (!(self = [super init])) return nil;
    self.rawCert = rawCert;
    return self;
}

- (NSString*) serialNumber
{
    NSMutableString *string = [NSMutableString new];
    for (size_t i =0 ; i != rawCert->pCertInfo->SerialNumber.cbData; ++i) {
        [string appendFormat:@"%x", rawCert->pCertInfo->SerialNumber.pbData[i]];
    }
    return string;
}

NSString* GetSigAlgoName(CRYPT_ALGORITHM_IDENTIFIER* pSigAlgo)
{
    if(pSigAlgo && pSigAlgo->pszObjId)
    {
        PCCRYPT_OID_INFO pCOI = CryptFindOIDInfo(CRYPT_OID_INFO_OID_KEY, pSigAlgo->pszObjId, 0);
        if(pCOI && pCOI->pwszName)
        {
            return [[NSString alloc] initWithBytes: pCOI->pwszName
                length: wcslen(pCOI->pwszName)*sizeof(*pCOI->pwszName)
                encoding:NSUTF32LittleEndianStringEncoding];
        }
        else
        {
            return [ [NSString alloc] initWithFormat:@"%s", pSigAlgo->pszObjId];
        }
    }
    
    return @"";
}

- (NSString*) signatureAlgorithm
{
    return GetSigAlgoName(&rawCert->pCertInfo->SignatureAlgorithm);
}

NSString* certNameToString(CERT_NAME_BLOB* certName, DWORD encodingType)
{
    DWORD cbSize;
    cbSize = CertNameToStr(encodingType,
                           certName,
                      CERT_X500_NAME_STR,
                      NULL,
                      0);
    
    LPTSTR pszString = (LPTSTR)malloc(cbSize * sizeof(TCHAR));
    cbSize = CertNameToStr(encodingType,
                           certName,
                MY_STRING_TYPE,
                pszString,
                cbSize);
    
    return [[NSString alloc]  initWithUTF8String:pszString];
}

- (NSString*) issuer
{
    return certNameToString(&rawCert->pCertInfo->Issuer, rawCert->dwCertEncodingType);
}

- (NSString*) subject
{
    return certNameToString(&rawCert->pCertInfo->Subject, rawCert->dwCertEncodingType);
}

NSDate* FileTimeToDate (FILETIME* ft)
{
    uint64_t* val = (uint64_t*) ft;
    
    return [[NSDate alloc] initWithTimeIntervalSince1970: (double) ((*val) / 10000000.0 - 11644473600.0)];
}

- (NSDate*) notBefore
{
    return FileTimeToDate(&rawCert->pCertInfo->NotBefore);
}

- (NSDate*) notAfter
{
    return FileTimeToDate(&rawCert->pCertInfo->NotAfter);
}

-(DWORD) close
{
    if(!CertFreeCertificateContext(rawCert)) {
        return CSP_GetLastError();
    }
    return ERROR_SUCCESS;
}

@end
