/*************************************************************************
* Rutoken                                                                *
* Copyright (c) 2003-2020, Aktiv-Soft JSC. All rights reserved.          *
* Подробная информация:  http://www.rutoken.ru                           *
*************************************************************************/

//
//  rtnfc.h
//  pcsc-ios
//
//  Created by Андрей Трифонов on 13.04.2020.
//  Copyright © 2020 Aktiv Co. All rights reserved.
//

#ifndef rtnfc_h
#define rtnfc_h

#import <Foundation/Foundation.h>

typedef void (^ ErrorCallback)(NSError*);

void startNFC(ErrorCallback onError);
void stopNFC(void);

#endif /* rtnfc_h */
