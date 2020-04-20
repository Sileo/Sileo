//
//  CydiaAccountUIWebView.m
//  Sileo
//
//  Created by CoolStar on 7/23/18.
//  Copyright © 2018 CoolStar. All rights reserved.
//

#import "CydiaAccountUIWebView.h"
#import "Sileo-Swift.h"

//User Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_3 like Mac OS X) AppleWebKit/603.3.8 (KHTML, like Gecko) Version/10.0 Mobile/14G60 Safari/602.1

@class WebView;
@class WebDataSource;

@interface UIWebView ()
- (NSMutableURLRequest *)webThreadWebView:(WebView *)webView resource:(NSObject *)resource willSendRequest:(NSMutableURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource;
@end

@implementation CydiaAccountUIWebView

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        
    }
    return self;
}

- (void)loadRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = request.mutableCopy;
    self.KeysOnMutableURLRequest = mutableRequest;
    [super loadRequest:mutableRequest];
}

- (void)setKeysOnMutableURLRequest:(NSMutableURLRequest *)request {
    if ([request.URL.host hasSuffix:@"saurik.com"]) {
        [request setValue:[UIDevice currentDevice].platform forHTTPHeaderField:@"X-Machine"];
        [request setValue:[UIDevice currentDevice].uniqueIdentifier forHTTPHeaderField:@"X-Unique-ID"];
        //[request setValue:@"Cydia/0.9 CFNetwork/811.5.4 Darwin/16.7.0" forHTTPHeaderField:@"User-Agent"];
    }
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_3 like Mac OS X) AppleWebKit/603.3.8 (KHTML, like Gecko) Version/10.0 Mobile/14G60 Safari/602.1" forHTTPHeaderField:@"User-Agent"];
}

- (NSMutableURLRequest *)webThreadWebView:(WebView *)webView resource:(NSObject *)resource willSendRequest:(NSMutableURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
    self.KeysOnMutableURLRequest = request;
    NSMutableURLRequest *returnRequest = [super webThreadWebView:webView resource:resource willSendRequest:request redirectResponse:redirectResponse fromDataSource:dataSource];
    return returnRequest;
}
@end
