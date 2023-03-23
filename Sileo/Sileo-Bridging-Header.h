#import "UIColor+HTMLColors.h"
#import "WhiteBlur.h"
#import "ControlFileParserFast.h"

#include <spawn.h>
#import "dpkgversion.h"
#import "decompression.h"

#if TARGET_OS_MACCATALYST
#import "LaunchAsRoot.h"
#endif

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
int posix_spawnattr_set_persona_np(const posix_spawnattr_t* __restrict, uid_t, uint32_t);
int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t* __restrict, uid_t);
int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t* __restrict, uid_t);

@interface UITabBar (Private)
@property (assign, setter=_setBlurEnabled:, nonatomic) BOOL _blurEnabled;
@end

@interface UIApplication (Private)
-(void)_setForcedUserInterfaceLayoutDirection:(long long)arg1 ;
@end

@interface UITabBarItem (Private)
- (UIView *)view;
-(void)_setInternalTitle:(id)arg1 ;
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
