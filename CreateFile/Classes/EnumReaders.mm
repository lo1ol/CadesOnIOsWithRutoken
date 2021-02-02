#include "EnumReaders.h"
#import <RtPcsc/rtnfc.h>

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
@end
