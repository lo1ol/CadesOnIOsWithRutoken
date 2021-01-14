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
#import <RtPcsc/rtnfc.h>

extern bool USE_CACHE_DIR;
bool USE_CACHE_DIR = false;

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

-(IBAction)getCerts:(id)sender{
//    startNFC(^(NSError* error) {
//        NSLog(@"%@",[error localizedDescription]);
//             });
//    [CProReader waitForNfcInsert];
    [CProReader installCerts];
//    stopNFC();
}

-(IBAction)startEnumReaders:(id)sender {
//    startNFC(^(NSError* error) {
//        NSLog(@"%@",[error localizedDescription]);
//             });
//    [CProReader waitForNfcInsert];
    [CProReader getReaderList];
//    stopNFC();
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
//    startNFC(^(NSError* error) { NSLog(@"%@", error.localizedDescription); });
//    [CProReader waitForNfcInsert];
    
    self.content = @"Test123";
    __block NSArray* gCerts;
    
    __block void (^onFinal)();
    __block void (^onErrorBlock)(NSError*);
    __block void (^onSuccessBlock)(NSString*);
    __block void (^signBlock)(NSArray*);
    
    signBlock = ^(NSArray* certs) {
       gCerts = certs;
        [Cades signData: [content dataUsingEncoding:NSUTF8StringEncoding] withCert: certs[0] withPin: nil withTSP: @"http://testca.cryptopro.ru/tsp/tsp.srf" successCallback: onSuccessBlock errorCallback: onErrorBlock];
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
        
//        stopNFC();
    };
    
    [Cades getCertificatesWithSuccessCallback: signBlock errorCallback:onErrorBlock ];
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
