//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <stdint.h>
#import <Flurry.h>

#import "UIColor+HTMLColors.h"
#import "WhiteBlur.h"
#import "ControlFileParserFast.h"
#import "DFContinuousForceTouchGestureRecognizer.h"
@import LNPopupController;

@interface LNPopupBar ()
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, assign) UIBarStyle systemBarStyle;
@end

@interface UITabBar (Private)
@property (assign, setter=_setBlurEnabled:, nonatomic) BOOL _blurEnabled;
@end

@interface UITabBarItem (Private)
- (UIView *)view;
@end

@interface UINavigationBar (Private)
@property (assign, setter=_setBackgroundOpacity:, nonatomic) CGFloat _backgroundOpacity API_AVAILABLE(ios(11.0));
@end

@interface UIImage (Private)
+ (UIImage *)kitImageNamed:(NSString *)imageName;
@end
