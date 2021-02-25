 //
//  CreateFileViewController.m
//  CreateFile
//
//  Created by Кондакова Татьяна Андреевна on 03.12.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "CreateFileViewController.h"
#import <sys/types.h>
#import <dirent.h>
#import <sys/stat.h>
#import "EnumReaders.h"
#import "Cades.h"
#import "RutokenNfcWorker.h"
#import <RtPcsc/rtnfc.h>

static NSString* const gCreateFileErrorDomain = @"ru.rutoken.testappcreatefile";

@implementation CreateFileViewController
@synthesize content;
@synthesize signature;


-(IBAction)startCreatingFile:(id)sender {
	[self createTestFile];
}


-(IBAction)startReadingFile:(id)sender {
	[self readTestFile];
}

-(IBAction)startPane:(id)sender{
	[self launchPane];
}

static bool nfcSelected;
-(void) startCallbackForNfcOrBtTokenWithSucessCallback: (void (^)(void)) successCallback errorCallback: (void (^)(NSError* error, bool nfcWorks)) errorCallback
{
    UIAlertController * alert = [UIAlertController
                                alertControllerWithTitle:@"Тип Рутокена"
                                message:@"Выберете тип Вашего Рутокена:"
                                preferredStyle:UIAlertControllerStyleActionSheet];

   void (^nfcHandler)(UIAlertAction* action) =
       ^void(UIAlertAction* action) {
           nfcSelected = true;
           [RutokenNfcWorker startNfcSessionWithSucessCallback: successCallback
                                          errorCallback: errorCallback
        ];
       };
   
   UIAlertAction* nfcButton = [UIAlertAction
                               actionWithTitle:@"NFC Рутокен"
                               style:UIAlertActionStyleDefault
                               handler:nfcHandler];

   void (^btHandler)(UIAlertAction * action) =
       ^void(UIAlertAction* action) {
           nfcSelected = false;
           successCallback();
       };
   
   UIAlertAction* btButton = [UIAlertAction
                              actionWithTitle:@"BT Рутокен"
                              style:UIAlertActionStyleDefault
                              handler:btHandler];
   
   [alert addAction:nfcButton];
   [alert addAction:btButton];

   [self presentViewController:alert animated:YES completion:nil];
}

-(IBAction)startEnumReaders:(id)sender {
    [self
     startCallbackForNfcOrBtTokenWithSucessCallback:
        ^() {
            [CProReader getReaderList];
            [RutokenNfcWorker stopNfcSessionWithSuccessCallback: ^(){}];
        
        }
     
     errorCallback:
        ^(NSError* error, bool nfcWorks) {
            if (nfcWorks){
                [RutokenNfcWorker stopNfcSessionWithSuccessCallback: ^(){}];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Readers" message: [NSString stringWithFormat: @"Can't get readers list. Error code: 0x%lx", error.code]delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                [alert show];
            }
        }
     ];
}

-(void) launchPane
{
	if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		CPROPane = [[PaneViewController alloc] initWithNibName:@"PaneViewController" bundle:nil];
	else 
		CPROPane = [[PaneViewController alloc] initWithNibName:@"PaneViewControllerIPhone" bundle: nil];
	UINavigationController * cont = [[UINavigationController alloc] initWithRootViewController:CPROPane];
	[cont setModalPresentationStyle:UIModalPresentationFullScreen];
	[self presentViewController:cont animated:YES completion:nil];
}

void lslr(const char * path)
{
	struct dirent * d;
	
	DIR * dp = opendir(path);
	if (dp == NULL)
		return;
	while((d=readdir(dp)) != NULL)
	{
		time_t t;
		char buf[PATH_MAX];
		struct stat st;
		sprintf(buf,"%s/%s",path,d->d_name);
		stat(buf,&st);
		t=st.st_mtimespec.tv_sec;
		printf("%s",ctime(&t));
		switch( st.st_mode & S_IFMT)
		{
			case S_IFIFO: printf("p");break;
			case S_IFCHR: printf("b");break;
			case S_IFDIR: printf("d");break;
			case S_IFLNK: printf("l");break;
			case S_IFSOCK: printf("@");break;
			case S_IFREG: printf("-");break;
			case S_IFWHT: printf("w");break;
			default: printf("?");break;
		}
		
		
		printf("%c%c%c%c%c%c%c%c%c%c%c%c",
			   (st.st_mode&S_ISVTX)?'t':'-',
			   (st.st_mode&S_ISUID)?'s':'-',
			   (st.st_mode&S_IRUSR)?'r':'-',
			   (st.st_mode&S_IWUSR)?'w':'-',
			   (st.st_mode&S_IXUSR)?'x':'-',
			   (st.st_mode&S_ISGID)?'s':'-',
			   (st.st_mode&S_IRGRP)?'r':'-',
			   (st.st_mode&S_IWGRP)?'w':'-',
			   (st.st_mode&S_IXGRP)?'x':'-',
			   (st.st_mode&S_IROTH)?'r':'-',
			   (st.st_mode&S_IWOTH)?'w':'-',
			   (st.st_mode&S_IXOTH)?'x':'-');
		printf(" %s\n",buf);
		if (d->d_type & DT_DIR && strcmp(d->d_name,".") && strcmp(d->d_name,".."))
		{
			lslr(buf);
		}
	}
	closedir(dp);
}


uint8_t cert_body[] = {0x30, 0x82, 0x02, 0x73, 0x30, 0x82, 0x02, 0x22, 0xa0, 0x03, 0x02, 0x01, 0x02, 0x02, 0x10, 0x37,
    0x41, 0x88, 0x82, 0xf5, 0x39, 0xa5, 0x92, 0x4a, 0xd4, 0x4e, 0x3d, 0xe0, 0x02, 0xea, 0x3c, 0x30,
    0x08, 0x06, 0x06, 0x2a, 0x85, 0x03, 0x02, 0x02, 0x03, 0x30, 0x7f, 0x31, 0x23, 0x30, 0x21, 0x06,
    0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x01, 0x16, 0x14, 0x73, 0x75, 0x70, 0x70,
    0x6f, 0x72, 0x74, 0x40, 0x63, 0x72, 0x79, 0x70, 0x74, 0x6f, 0x70, 0x72, 0x6f, 0x2e, 0x72, 0x75,
    0x31, 0x0b, 0x30, 0x09, 0x06, 0x03, 0x55, 0x04, 0x06, 0x13, 0x02, 0x52, 0x55, 0x31, 0x0f, 0x30,
    0x0d, 0x06, 0x03, 0x55, 0x04, 0x07, 0x13, 0x06, 0x4d, 0x6f, 0x73, 0x63, 0x6f, 0x77, 0x31, 0x17,
    0x30, 0x15, 0x06, 0x03, 0x55, 0x04, 0x0a, 0x13, 0x0e, 0x43, 0x52, 0x59, 0x50, 0x54, 0x4f, 0x2d,
    0x50, 0x52, 0x4f, 0x20, 0x4c, 0x4c, 0x43, 0x31, 0x21, 0x30, 0x1f, 0x06, 0x03, 0x55, 0x04, 0x03,
    0x13, 0x18, 0x43, 0x52, 0x59, 0x50, 0x54, 0x4f, 0x2d, 0x50, 0x52, 0x4f, 0x20, 0x54, 0x65, 0x73,
    0x74, 0x20, 0x43, 0x65, 0x6e, 0x74, 0x65, 0x72, 0x20, 0x32, 0x30, 0x1e, 0x17, 0x0d, 0x31, 0x39,
    0x30, 0x35, 0x32, 0x37, 0x30, 0x37, 0x32, 0x34, 0x32, 0x36, 0x5a, 0x17, 0x0d, 0x32, 0x34, 0x30,
    0x35, 0x32, 0x36, 0x30, 0x37, 0x33, 0x34, 0x30, 0x35, 0x5a, 0x30, 0x7f, 0x31, 0x23, 0x30, 0x21,
    0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x09, 0x01, 0x16, 0x14, 0x73, 0x75, 0x70,
    0x70, 0x6f, 0x72, 0x74, 0x40, 0x63, 0x72, 0x79, 0x70, 0x74, 0x6f, 0x70, 0x72, 0x6f, 0x2e, 0x72,
    0x75, 0x31, 0x0b, 0x30, 0x09, 0x06, 0x03, 0x55, 0x04, 0x06, 0x13, 0x02, 0x52, 0x55, 0x31, 0x0f,
    0x30, 0x0d, 0x06, 0x03, 0x55, 0x04, 0x07, 0x13, 0x06, 0x4d, 0x6f, 0x73, 0x63, 0x6f, 0x77, 0x31,
    0x17, 0x30, 0x15, 0x06, 0x03, 0x55, 0x04, 0x0a, 0x13, 0x0e, 0x43, 0x52, 0x59, 0x50, 0x54, 0x4f,
    0x2d, 0x50, 0x52, 0x4f, 0x20, 0x4c, 0x4c, 0x43, 0x31, 0x21, 0x30, 0x1f, 0x06, 0x03, 0x55, 0x04,
    0x03, 0x13, 0x18, 0x43, 0x52, 0x59, 0x50, 0x54, 0x4f, 0x2d, 0x50, 0x52, 0x4f, 0x20, 0x54, 0x65,
    0x73, 0x74, 0x20, 0x43, 0x65, 0x6e, 0x74, 0x65, 0x72, 0x20, 0x32, 0x30, 0x63, 0x30, 0x1c, 0x06,
    0x06, 0x2a, 0x85, 0x03, 0x02, 0x02, 0x13, 0x30, 0x12, 0x06, 0x07, 0x2a, 0x85, 0x03, 0x02, 0x02,
    0x23, 0x01, 0x06, 0x07, 0x2a, 0x85, 0x03, 0x02, 0x02, 0x1e, 0x01, 0x03, 0x43, 0x00, 0x04, 0x40,
    0x14, 0x9f, 0x16, 0x04, 0xa8, 0xab, 0x76, 0x51, 0x3b, 0x9f, 0x62, 0x3b, 0x91, 0xc4, 0xbc, 0xbc,
    0xc9, 0xac, 0x60, 0x2c, 0x67, 0x7a, 0xc3, 0x45, 0x05, 0xee, 0xe6, 0xa8, 0xca, 0x2e, 0xd5, 0xeb,
    0x7b, 0xc2, 0xf4, 0x89, 0x81, 0x33, 0x52, 0xb3, 0x2b, 0xc7, 0xca, 0xe0, 0x6d, 0xca, 0x04, 0xd6,
    0x2b, 0xb3, 0xd7, 0x11, 0xfe, 0xc3, 0xc3, 0xd4, 0x8d, 0xbc, 0x1b, 0x1b, 0xf3, 0x7b, 0xc3, 0x92,
    0xa3, 0x78, 0x30, 0x76, 0x30, 0x0b, 0x06, 0x03, 0x55, 0x1d, 0x0f, 0x04, 0x04, 0x03, 0x02, 0x01,
    0x86, 0x30, 0x0f, 0x06, 0x03, 0x55, 0x1d, 0x13, 0x01, 0x01, 0xff, 0x04, 0x05, 0x30, 0x03, 0x01,
    0x01, 0xff, 0x30, 0x1d, 0x06, 0x03, 0x55, 0x1d, 0x0e, 0x04, 0x16, 0x04, 0x14, 0x4e, 0x83, 0x3e,
    0x14, 0x69, 0xef, 0xec, 0x5d, 0x7a, 0x95, 0x2b, 0x5f, 0x11, 0xfe, 0x37, 0x32, 0x16, 0x49, 0x55,
    0x2b, 0x30, 0x12, 0x06, 0x09, 0x2b, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37, 0x15, 0x01, 0x04, 0x05,
    0x02, 0x03, 0x01, 0x00, 0x01, 0x30, 0x23, 0x06, 0x09, 0x2b, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37,
    0x15, 0x02, 0x04, 0x16, 0x04, 0x14, 0x04, 0x62, 0x55, 0x29, 0x0b, 0x0e, 0xb1, 0xcd, 0xd1, 0x79,
    0x7d, 0x9a, 0xb8, 0xc8, 0x1f, 0x69, 0x9e, 0x36, 0x87, 0xf3, 0x30, 0x08, 0x06, 0x06, 0x2a, 0x85,
    0x03, 0x02, 0x02, 0x03, 0x03, 0x41, 0x00, 0xc4, 0xc5, 0xb2, 0xd5, 0xb1, 0x3b, 0x7f, 0xa1, 0x28,
    0x2a, 0x83, 0xee, 0x73, 0x73, 0xf2, 0x6a, 0xd0, 0xf6, 0x68, 0x8e, 0x1d, 0x5f, 0x11, 0x75, 0x5a,
    0x7b, 0x75, 0x11, 0x4f, 0x03, 0x9f, 0x16, 0xe5, 0xee, 0x3e, 0x25, 0x58, 0x21, 0x52, 0x9c, 0x3e,
    0xed, 0xfc, 0x4e, 0x06, 0x43, 0xf1, 0xf5, 0x41, 0x5e, 0x29, 0x19, 0x67, 0x02, 0x24, 0xbb, 0x23,
    0xdd, 0xe4, 0xae, 0x58, 0x4a, 0x5a, 0x48
};


// Display dialog box
- (void) createTestFile
{
    self.content = @"Test123";
    __block NSArray* gCerts;
    
    __block void (^onFinal)(bool);
    __block void (^onErrorBlock)(NSError*, bool nfcWorks);
    __block void (^onSuccessBlock)(NSString*);
    __block void (^onCheckCertStatus)(DWORD);
    __block void (^signBlock)(DWORD);
    __block void (^verifyCertBlock)(NSArray*);
    __block void (^getCertBlock)();
    
    getCertBlock = ^() {
        [Cades getCertificatesWithSuccessCallback: verifyCertBlock
                                    errorCallback: ^(NSError* error){onErrorBlock(error, nfcSelected);} ];
    };
    
    verifyCertBlock = ^(NSArray* certs) {
        gCerts = certs;
        if (gCerts.count == 0) {
            NSDictionary* desc = [NSDictionary dictionaryWithObject : NSLocalizedString(@"Сертификаты не найдены", @"Не обнаружены контейнеры с сертификатами") forKey : NSLocalizedDescriptionKey];
            
            NSError* error = [[NSError alloc] initWithDomain:gCreateFileErrorDomain code:1 userInfo: desc];
            
            onErrorBlock(error, nfcSelected);
            return;
        }
        
        [Cades verifyCertificate:gCerts[0] successCallback:signBlock errorCallback:^(NSError* error){onErrorBlock(error, nfcSelected);}];
    };
    
    signBlock = ^(DWORD status) {
        if (status != CERT_TRUST_NO_ERROR) {
            onCheckCertStatus(status);
            return;
        }
        [Cades signData: [content dataUsingEncoding:NSUTF8StringEncoding]
               withCert: gCerts[0] withPin: @"12345678"
                withTSP: @"http://testca.cryptopro.ru/tsp/tsp.srf"
        successCallback: onSuccessBlock
          errorCallback: ^(NSError* error){onErrorBlock(error, nfcSelected);}];
   };
    
    onCheckCertStatus = ^(DWORD status) {
        self.signature = signature;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sign" message:[NSString stringWithFormat: @"Certificate verification is failed. Error code: 0x%x", status] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        
        onFinal(nfcSelected);
        
    };
    
    onSuccessBlock = ^(NSString* signature) {
        self.signature = signature;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sign" message:@"everything is ok." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        
        onFinal(nfcSelected);
        
    };
    
    onErrorBlock = ^(NSError* error, bool nfcWorks) {
        if (!nfcSelected || nfcWorks) {
           UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sign" message: [NSString stringWithFormat: @"sign failed. Error code: 0x%lx", error.code] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
           [alert show];
        }
       
        onFinal(nfcWorks);
   };
    
    onFinal = ^(bool nfcWorks) {
        if (gCerts) {
            [Cades closeCertificates:gCerts
                     successCallback:^(){}
                       errorCallback:^(NSError* error) {onErrorBlock(error, true);}];
            gCerts = nil;
        }
        
        if (nfcWorks)
            [RutokenNfcWorker stopNfcSessionWithSuccessCallback: ^(){}];
    };
    
    [self startCallbackForNfcOrBtTokenWithSucessCallback: getCertBlock errorCallback: onErrorBlock];
    
    
    __block void (^addCABlock)();
    addCABlock = ^() {
        NSData* certCA = [[NSData alloc] initWithBytes:cert_body length:sizeof(cert_body)];
        [Cades  addCACert: certCA
                successCallback:^() {onSuccessBlock(@"");}
                errorCallback:^(NSError* error) {onErrorBlock(error, true);}];
    };
    
    //[self startCallbackForNfcOrBtTokenWithSucessCallback: addCABlock errorCallback: onErrorBlock];
}

- (void) readTestFile
{
    void (^onErrorBlock)(NSError*) = ^(NSError* error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Verify" message: [NSString stringWithFormat: @"signature was not verified. Error code: 0x%lx", error.code]delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    };
    
    void (^onSuccessBlock)(NSInteger) = ^(NSInteger status) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Verify" message: [NSString stringWithFormat: @"signature verification status is 0x%lx", status] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    };
    
    if (!signature) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Verify" message: @"no signature found. Create signature firstly" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [Cades verifySignature: signature successCallback: onSuccessBlock errorCallback: onErrorBlock];
	
}

@end
