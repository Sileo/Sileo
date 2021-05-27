#import <stdint.h>

#import "UIColor+HTMLColors.h"
#import "WhiteBlur.h"
#import "ControlFileParserFast.h"
#import "DFContinuousForceTouchGestureRecognizer.h"
@import LNPopupController;

#if TARGET_OS_MACCATALYST
#import "LaunchAsRoot.h"
#endif

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
