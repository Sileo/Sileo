//
//  LaunchAsRoot.h
//  SileoRootWrapper
//
//  Created by Sileo Team on 27/05/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Authorization.h>

@interface LaunchAsRoot : NSObject
@property (class, readonly) LaunchAsRoot *shared;
@property AuthorizationRef authRef;
- (instancetype)init;
- (void)dealloc;
- (BOOL)authenticateIfNeeded;
- (NSString *)spawnWithPath:(NSString *)path args:(NSArray<NSString *> *)args;
@end
