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

-(void)startCallbackWithNfcOrNone: (void(^)(void)) callback
{
    UIAlertController * alert = [UIAlertController
                                alertControllerWithTitle:@"Распознавание Рутокен NFC"
                                message:@"Включить NFC для распознавания Рутокен NFC?"
                                preferredStyle:UIAlertControllerStyleActionSheet];

    void (^nfcHandler)(UIAlertAction* action) =
       ^void(UIAlertAction* action) {
           __block NSLock* lock = [NSLock new];
           __block bool stopFlag = false;
           
           startNFC(^void(NSError* error){
                [lock lock];
                stopFlag = true;
                [lock unlock];
                        
                NSLog(@"%@", error.localizedDescription);
            });
           
           [RutokenNfcWorker waitForTokenWithStopFlag: &stopFlag lock: lock];
           [lock lock];
           if (stopFlag) {
               [lock unlock];
               return;
           }
           [lock unlock];
           
           callback();
           stopNFC();
       };
   
    UIAlertAction* nfcButton = [UIAlertAction
                               actionWithTitle:@"Да"
                               style:UIAlertActionStyleDefault
                               handler:nfcHandler];

    void (^nonNfcHandler)(UIAlertAction * action) =
       ^void(UIAlertAction* action) {
           callback();
       };
   
    UIAlertAction* nonNfcButton = [UIAlertAction
                              actionWithTitle:@"Нет"
                              style:UIAlertActionStyleDefault
                              handler:nonNfcHandler];
   
    [alert addAction:nfcButton];
    [alert addAction:nonNfcButton];

    [self presentViewController:alert animated:YES completion:nil];
}

-(IBAction)startEnumReaders:(id)sender {
    [self startCallbackWithNfcOrNone: ^(){ [CProReader getReaderList]; }];
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

-(void)startCallbackWithNfcOrNoneWithPinAsking: (void(^)(NSString* pinCode)) callback
{
    UIAlertController * alert = [UIAlertController
                                alertControllerWithTitle:@"Распознавание Рутокен NFC"
                                message:@"Включить NFC для распознавания Рутокен NFC?"
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    __block UIAlertController* pinCodeAlert = [UIAlertController alertControllerWithTitle:@"Пин-код"
                                                               message:@"Введите ПИН-код"
                                                              preferredStyle:UIAlertControllerStyleAlert];

    void(^nfcHeandlerAfterAskPinCode)(UIAlertAction * action) =
    ^(UIAlertAction * action) {
        __block NSLock* lock = [NSLock new];
        __block bool stopFlag = false;
        
        startNFC(^void(NSError* error){
            [lock lock];
            stopFlag = true;
            [lock unlock];

            NSLog(@"%@", error.localizedDescription);
        });

        [RutokenNfcWorker waitForTokenWithStopFlag: &stopFlag lock: lock];
        [lock lock];
        if (stopFlag) {
            [lock unlock];
            return;
        }
        [lock unlock];

        callback(pinCodeAlert.textFields[0].text);
        stopNFC();
    };
    
    void (^nfcHandler)(UIAlertAction* action) =
       ^void(UIAlertAction* action) {
           UIAlertAction* okAction =
           [UIAlertAction actionWithTitle:@"OK"
                                    style:UIAlertActionStyleDefault
                                  handler:nfcHeandlerAfterAskPinCode];
           
           [pinCodeAlert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
               textField.secureTextEntry = true;
           }];
           [pinCodeAlert addAction:okAction];
           [self presentViewController:pinCodeAlert animated:YES completion:nil];
       };
   
    UIAlertAction* nfcButton = [UIAlertAction
                               actionWithTitle:@"Да"
                               style:UIAlertActionStyleDefault
                               handler:nfcHandler];

    void (^nonNfcHandler)(UIAlertAction * action) =
       ^void(UIAlertAction* action) {
           callback(nil);
       };
   
    UIAlertAction* nonNfcButton = [UIAlertAction
                              actionWithTitle:@"Нет"
                              style:UIAlertActionStyleDefault
                              handler:nonNfcHandler];
   
    [alert addAction:nfcButton];
    [alert addAction:nonNfcButton];

    [self presentViewController:alert animated:YES completion:nil];
}

// Display dialog box
- (void) createTestFile
{
    __block void (^callback)(NSString*) = ^(NSString* pin) {
        UIAlertView *alert;
        NSString* res = nil;
        self.content = @"Test123";
        NSArray* certs = nil;
        DWORD rv = ERROR_SUCCESS;
        
        if (pin)
            rv = [Cades getReaderCertificates:&certs];
        else
            rv = [Cades getStoreCertificates:&certs];
        
        if (rv != ERROR_SUCCESS)
            goto cades_error;
    
        if (certs.count == 0) {
            goto certs_error;
        }
        
        rv = [Cades signData: [content dataUsingEncoding:NSUTF8StringEncoding]
               withCert: certs[0] withPin: pin
                withTSP: @"http://testca.cryptopro.ru/tsp/tsp.srf"
              signature: &res ];
        signature = res;
        
        if (rv != ERROR_SUCCESS)
            goto cades_error;
        
        goto sucess;

cades_error:
        alert = [[UIAlertView alloc] initWithTitle:@"Sign" message: [NSString stringWithFormat: @"sign failed. Error code: 0x%x", rv] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        goto finish;
        
certs_error:
        alert = [[UIAlertView alloc] initWithTitle:@"Sign" message: [NSString stringWithFormat: @"No certs found", rv] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        goto finish;
        
sucess:
        alert = [[UIAlertView alloc] initWithTitle:@"Sign" message:@"everything is ok." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        goto finish;
        
finish:
        [alert show];
        if (certs)
            [Cades closeCertificates:certs];
    };
    
    [self startCallbackWithNfcOrNoneWithPinAsking: callback];
    
}

- (void) readTestFile
{
    if (!signature) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Verify" message: @"no signature found. Create signature firstly" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    NSInteger status;
    DWORD rv =[Cades verifySignature: signature status:status];
    
    if (rv != ERROR_SUCCESS) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Verify" message: [NSString stringWithFormat: @"signature was not verified. Error code: 0x%x", rv]delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    } else if (status == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Verify" message: @"Signature is valid" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Verify" message: [NSString stringWithFormat: @"signature is not valid. status: 0x%lx", (long) status] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
	
}

@end
