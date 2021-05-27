//
//  CydiaAccountUIWebView.h
//  Sileo
//
//  Created by CoolStar on 7/23/18.
//  Copyright © 2018 CoolStar. All rights reserved.
//

#import <UIKit/UIKit.h>

#if TARGET_OS_MACCATALYST
#else
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface CydiaAccountUIWebView : UIWebView

@end
#endif
#pragma clang diagnostic pop
