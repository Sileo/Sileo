#import <bzlib.h>
#import <stdint.h>
#import <zlib.h>

#import "libzstd.h"
#import "lzma.h"
#import "UIColor+HTMLColors.h"
#import "WhiteBlur.h"
#import "ControlFileParserFast.h"
#import "DFContinuousForceTouchGestureRecognizer.h"

@import LNPopupController;
@import WebKit;

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

@interface UIPickerView (Private)
@property (setter=_setTextColor:,getter=_textColor,nonatomic,retain) UIColor* textColor;
@end

@interface UITableView (Private)
-(BOOL)allowsFooterViewsToFloat;
@end

@interface WKWebViewConfiguration (Private)
@property (nonatomic, setter=_setOverrideContentSecurityPolicy:) NSString *_overrideContentSecurityPolicy API_AVAILABLE(macos(10.12.3), ios(10.3));
@property (nonatomic, setter=_setLoadsFromNetwork:) BOOL _loadsFromNetwork API_AVAILABLE(macos(11.0), ios(14.0));
@property (nonatomic, copy, setter=_setAllowedNetworkHosts:) NSSet <NSString *> *_allowedNetworkHosts API_AVAILABLE(macos(11.0), ios(15.0));
@property (nonatomic, setter=_setLoadsSubresources:) BOOL _loadsSubresources API_AVAILABLE(macos(11.0), ios(14.0));
@end
