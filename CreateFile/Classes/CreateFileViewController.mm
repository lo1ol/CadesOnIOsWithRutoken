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
#import "NfcWorker.h"
#import <RtPcsc/rtnfc.h>

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

-(void) startCallbackForNfcOtBtTokenWithSucessCallback: (void (^)(void)) successCallback errorCallback: (void (^)(void)) errorCallback
{
    UIAlertController * alert = [UIAlertController
                                alertControllerWithTitle:@"Тип Рутокена"
                                message:@"Выберете тип Вашего Рутокена:"
                                preferredStyle:UIAlertControllerStyleActionSheet];

   void (^nfcHandler)(UIAlertAction* action) =
       ^void(UIAlertAction* action) {
           [NfcWorker
            startNfcSessionWithNfcErrorCallback: ^void(NSError* error)
            {
                NSLog(@"%@",[error localizedDescription]);
                errorCallback();
            }
            
            sucessCallback: successCallback
       
            errorCallback: errorCallback
        ];
       };
   
   UIAlertAction* nfcButton = [UIAlertAction
                               actionWithTitle:@"NFC Рутокен"
                               style:UIAlertActionStyleDefault
                               handler:nfcHandler];

   void (^btHandler)(UIAlertAction * action) =
       ^void(UIAlertAction* action) {
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
     startCallbackForNfcOtBtTokenWithSucessCallback:
        ^() {
            [CProReader getReaderList];
            [NfcWorker stopNfcSessionWithSuccessCallback: ^(){}];
        
        }
     
     errorCallback:
        ^() {
            [NfcWorker stopNfcSessionWithSuccessCallback: ^(){}];
        
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


// Display dialog box
- (void) createTestFile
{
    self.content = @"Test123";
    __block NSArray* gCerts;
    
    __block void (^onFinal)();
    __block void (^onErrorBlock)(NSError*);
    __block void (^onSuccessBlock)(NSString*);
    __block void (^signBlock)(NSArray*);
    
    signBlock = ^(NSArray* certs) {
       gCerts = certs;
        [Cades signData: [content dataUsingEncoding:NSUTF8StringEncoding] withCert: certs[0] withPin: @"12345678" withTSP: @"http://testca.cryptopro.ru/tsp/tsp.srf" successCallback: onSuccessBlock errorCallback: onErrorBlock];
   };
    
    onSuccessBlock = ^(NSString* signature) {
        self.signature = signature;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sign" message:@"everything is ok." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        
        onFinal();
    };
    
    onErrorBlock = ^(NSError* error) {
       UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sign" message: [NSString stringWithFormat: @"sign failed. Error code: 0x%lx", error.code] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
       [alert show];
       
        onFinal();
   };
    
    onFinal = ^() {
        if (gCerts) {
            NSArray* certs = gCerts;
            gCerts = nil;
            [Cades closeCertificates:certs successCallback:^(){} errorCallback:onErrorBlock];
        }
        [NfcWorker stopNfcSessionWithSuccessCallback: ^(){}];
    };
    
    [self startCallbackForNfcOtBtTokenWithSucessCallback: ^() {
        [Cades getCertificatesWithSuccessCallback: signBlock errorCallback:onErrorBlock ]
        ;} errorCallback: ^(){}];
    
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
    
    [Cades verifySignature: signature successCallback: onSuccessBlock errorCallback: onErrorBlock];
	
}

@end
