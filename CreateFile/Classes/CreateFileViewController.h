//
//  CreateFileViewController.h
//  CreateFile
//
//  Created by Кондакова Татьяна Андреевна on 03.12.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CPROCSP/CPROCSP.h>
#import <CPROCSP/PaneViewController.h>

@interface CreateFileViewController : UIViewController <UINavigationControllerDelegate> {
	PaneViewController *CPROPane;
}

@property (readwrite) NSString* content;
@property (readwrite) NSString* signature;

-(IBAction)startCreatingFile:(id)sender;
-(IBAction)startReadingFile:(id)sender;
-(IBAction)startPane:(id)sender;
-(IBAction)startEnumReaders:(id)sender;
-(void)createTestFile;
-(void)readTestFile;
-(void)launchPane;

@end
