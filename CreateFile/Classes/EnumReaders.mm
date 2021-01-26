#include "EnumReaders.h"
 static const int kGostProvType = PROV_GOST_2012_256;


@implementation CProReader
 
@synthesize name;
@synthesize nickname;
@synthesize media;
@synthesize flags;
 
-(CProReader*) init {
    if (!(self = [super init])) return nil;
    self.name = nil;
    self.nickname = nil;
    self.media = nil;
    return self;
}
 
-(CProReader*) initWithData: (uint8_t*)dataPtr {
    if (!(self = [super init])) return nil;
    self.nickname = [[NSString alloc] initWithBytes:dataPtr length:strlen((char*)dataPtr) encoding:NSUTF8StringEncoding];
    dataPtr+=1+[self.nickname length];
    self.name = [[NSString alloc] initWithBytes:dataPtr length:strlen((char*)dataPtr) encoding:NSUTF8StringEncoding];
    dataPtr+=1+[self.name length];
    self.media = [[NSString alloc] initWithBytes:dataPtr length:strlen((char*)dataPtr) encoding:NSUTF8StringEncoding];
    dataPtr+=1+[self.name length];
    self.flags = *dataPtr;
    return self;
}
 
+(NSArray*) getReaderList
{   
    NSMutableArray* readerList = nil;
    
    DWORD error = ERROR_SUCCESS;
    HCRYPTPROV  hCryptProv = 0;
    CSP_BOOL    bResult = 0;
    DWORD       dwLen = 0;
    
    bResult = CryptAcquireContext(&hCryptProv, NULL, NULL, kGostProvType, CRYPT_VERIFYCONTEXT);
    if (!bResult) {
        error = CSP_GetLastError();
        NSLog(@"CryptAcquireContext(CRYPT_VERIFYCONTEXT): %x\n", error);
    }
    
    if(0 == hCryptProv) {
        NSLog(@"Invalid HCRYPTPROV");
        return nil;
    }
    
    BYTE cryptFirst = CRYPT_FIRST;
    DWORD dwMaxLen;
    
    for (;;) {
        if (cryptFirst) {
            CSP_SetLastError(ERROR_SUCCESS);
            bResult = CryptGetProvParam(hCryptProv, PP_ENUMREADERS, NULL, &dwMaxLen, CRYPT_MEDIA | cryptFirst);
            error = CSP_GetLastError();
            if (error == ERROR_NO_MORE_ITEMS)
                break;
            if (!bResult)
            {
                printf("CryptGetProvParam(PP_ENUMREADERS, LEN): %x\n", error);
                break;
            }
        }
        
         
        dwLen = dwMaxLen;
        NSMutableData* data = [[NSMutableData alloc] initWithCapacity:dwLen];
        
        CSP_SetLastError(ERROR_SUCCESS);
        bResult = CryptGetProvParam(hCryptProv, PP_ENUMREADERS, (BYTE*)[data bytes], &dwLen, CRYPT_MEDIA | cryptFirst);
        cryptFirst = 0;
        error = CSP_GetLastError();
        if (error == ERROR_NO_MORE_ITEMS)
            break;
        if (!bResult)
        {
            printf("CryptGetProvParam(PP_ENUMREADERS, NAME): %x\n", error);
            break;
        }
        
        BYTE* dataPtr = (BYTE*)[data bytes];
        CProReader* reader = [[CProReader alloc] initWithData:dataPtr];
        
        if (nil == readerList) {
            readerList =[NSMutableArray new];
        }
        
        [readerList addObject: reader];
    }
    
    NSString* logMessage = @"";
    for (id obj in readerList) {
        //NSString * tmp = @"\n\nname %@\nnickname %@\nmedia %@\n\n", [obj name], [obj nickname], [obj media]];
        logMessage = [logMessage stringByAppendingFormat:@"\nname %@\nnickname %@\nmedia %@\n\n", [obj name], [obj nickname], [obj media]];
    }

    UIAlertView *alert;
    if (readerList != nil) {
        alert = [[UIAlertView alloc] initWithTitle:@"Readers" message:logMessage delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    } else {
        alert = [[UIAlertView alloc] initWithTitle:@"Readers" message:@"readers were not found!" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];      
    }
    [alert show];
    //NSString * name = [readerList [CProReader name]];
        return readerList;
}

+(bool) waitForNfcInsert
{
    for(;;) {
        DWORD error = ERROR_SUCCESS;
        HCRYPTPROV  hCryptProv = 0;
        CSP_BOOL    bResult = 0;
        DWORD       dwLen = 0;
        
        bResult = CryptAcquireContext(&hCryptProv, NULL, NULL, kGostProvType, CRYPT_VERIFYCONTEXT);
        if (!bResult) {
            error = CSP_GetLastError();
            NSLog(@"CryptAcquireContext(CRYPT_VERIFYCONTEXT): %x\n", error);
        }
        
        if(0 == hCryptProv) {
            NSLog(@"Invalid HCRYPTPROV");
            return false;
        }
        
        BYTE cryptFirst = CRYPT_FIRST;
        DWORD dwMaxLen;
        
        for (;;) {
            if (cryptFirst) {
                CSP_SetLastError(ERROR_SUCCESS);
                bResult = CryptGetProvParam(hCryptProv, PP_ENUMREADERS, NULL, &dwMaxLen, CRYPT_MEDIA | cryptFirst);
                error = CSP_GetLastError();
                if (error == ERROR_NO_MORE_ITEMS)
                    break;
                if (!bResult)
                {
                    printf("CryptGetProvParam(PP_ENUMREADERS, LEN): %x\n", error);
                    break;
                }
            }
            
             
            dwLen = dwMaxLen;
            NSMutableData* data = [[NSMutableData alloc] initWithCapacity:dwLen];
            
            CSP_SetLastError(ERROR_SUCCESS);
            bResult = CryptGetProvParam(hCryptProv, PP_ENUMREADERS, (BYTE*)[data bytes], &dwLen, CRYPT_MEDIA | cryptFirst);
            cryptFirst = 0;
            error = CSP_GetLastError();
            if (error == ERROR_NO_MORE_ITEMS)
                break;
            if (!bResult)
            {
                printf("CryptGetProvParam(PP_ENUMREADERS, NAME): %x\n", error);
                break;
            }
            
            BYTE* dataPtr = (BYTE*)[data bytes];
            CProReader* reader = [[CProReader alloc] initWithData:dataPtr];
            if ([[reader.name lowercaseString] containsString: @"nfc"]) {
                return true;
            }
        }
        sleep(1);
    }
}

bool addCertToStore(PCCERT_CONTEXT pcert)
{
    HCERTSTORE hCertStore = CertOpenSystemStore(0, "My");
    if(!hCertStore){
        fprintf (stderr, "CertOpenSystemStore failed.");
        return false;
    }
    BOOL added = CertAddCertificateContextToStore(hCertStore, pcert, CERT_STORE_ADD_REPLACE_EXISTING, NULL);

    if (added)
        printf("cert was added in system successfully");
    else
        printf("cert wasn't added in system\n");

    CertCloseStore(hCertStore, CERT_CLOSE_STORE_CHECK_FLAG);
    return added;
}

+(void) installCerts
{
    //
    // 1. Acquire context to enumerate containers.
    //
    HCRYPTPROV hProv = 0;
    if (!CryptAcquireContext(&hProv, NULL, NULL, kGostProvType, CRYPT_VERIFYCONTEXT)) {
        printf("CryptAcquireContext failed\n");
        return;
    }

    DWORD fParam = CRYPT_FIRST;
    DWORD cnt = 0;
    BYTE* pbCertBlob = 0;
    DWORD dwCertBlob = 0;
    char* contName = NULL;
    PCCERT_CONTEXT certificate = 0;

    //
    // 2. Enumerate containers and collect all CERT_CONTEXTs.
    //
    while (true)
    {
        DWORD size = 0;
        if(contName){
            free(contName);
            contName = NULL;
        }
        if (!CryptGetProvParam(hProv, PP_ENUMCONTAINERS, NULL, &size, fParam)) {
            break;
        }
        
        contName = (char *) malloc(size);
        if (!CryptGetProvParam(hProv, PP_ENUMCONTAINERS, (BYTE *) contName, &size, fParam)) {
            free(contName);
            break;
        }
        
        fParam = 0;
        
        printf("Container name: %s\n", contName);

        cnt++;
        HCRYPTKEY hKey;
        HCRYPTPROV hProv2;

        //
        // 3. Start work with a container.
        //
        CryptAcquireContext(&hProv2, (char*) contName, NULL, kGostProvType, NULL);

        if (!CryptGetUserKey(hProv2, AT_KEYEXCHANGE, &hKey)) {
            printf("CryptGetUserKey failed\n");
            CryptReleaseContext(hProv2, 0);
            continue;
        }

        //
        // Get size of certificate.
        //
        if (!CryptGetKeyParam(hKey, KP_CERTIFICATE, NULL, &dwCertBlob, NULL)) {
            printf("CryptGetKeyParam failed\n");
            CryptReleaseContext(hProv2, 0);
            continue;
        }

        //
        // Read certificate.
        //
        pbCertBlob = new BYTE[dwCertBlob];
        if (!CryptGetKeyParam(hKey, KP_CERTIFICATE, pbCertBlob, &dwCertBlob, NULL)) {
            printf("Get certificate blob failed\n");
            delete pbCertBlob;
            CryptReleaseContext(hProv2, 0);
            continue;
        }

        //
        // Create certificate context from just read binary data.
        //
        certificate = CertCreateCertificateContext( PKCS_7_ASN_ENCODING | X509_ASN_ENCODING, pbCertBlob, dwCertBlob);
        
        DWORD cbProvName;
        
        LPWSTR pbProvName = NULL;
        if(!CryptGetDefaultProviderW(
            kGostProvType,
            NULL,
            CRYPT_MACHINE_DEFAULT,
            NULL,
            &cbProvName))
        {
            printf("Error getting the length of the default provider name.");
        }
        
        pbProvName = new wchar_t[cbProvName];
        if(!CryptGetDefaultProviderW(
            kGostProvType,
            NULL,
            CRYPT_MACHINE_DEFAULT,
            pbProvName,
            &cbProvName))
        {
            printf("Error getting the length of the default provider name.");
        }
        
        
        CRYPT_KEY_PROV_INFO KeyProvInfo;
//
        LPWSTR wContName = new wchar_t[strlen(contName)+1];
        mbstowcs (wContName, contName, strlen(contName)+1);
        
        KeyProvInfo.pwszContainerName = wContName;
        KeyProvInfo.pwszProvName = pbProvName;
        KeyProvInfo.dwProvType = kGostProvType;
        KeyProvInfo.dwKeySpec = AT_KEYEXCHANGE;
        KeyProvInfo.dwFlags = 0;
        KeyProvInfo.cProvParam = 0;
        KeyProvInfo.rgProvParam = NULL;
        
        if (!CertSetCertificateContextProperty(certificate, CERT_KEY_PROV_INFO_PROP_ID, NULL, (void *) &KeyProvInfo)) {
            printf("CertSetCertificateContextProperty error");
            delete[] pbProvName;
            delete[] wContName;
            delete pbCertBlob;
            CryptReleaseContext(hProv2, 0);
            continue;
        }
        
        addCertToStore(certificate);
        
        delete[] pbProvName;
        delete[] wContName;
        delete pbCertBlob;
        CryptReleaseContext(hProv2, 0);
    }

    CryptReleaseContext(hProv, 0);
}
@end
