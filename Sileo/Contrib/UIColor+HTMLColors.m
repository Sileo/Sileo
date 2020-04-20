//
//  UIColor+HTMLColors.m
//
//  Created by James Lawton on 12/9/12.
//  Copyright (c) 2012 James Lawton. All rights reserved.
//

#import "UIColor+HTMLColors.h"

typedef struct {
    CGFloat a, b, c;
} CMRFloatTriple;

typedef struct {
    CGFloat a, b, c, d;
} CMRFloatQuad;

// CSS uses HSL, but we have to specify UIColor as HSB
static inline CMRFloatTriple HSB2HSL(CGFloat hue, CGFloat saturation, CGFloat brightness);
static inline CMRFloatTriple HSL2HSB(CGFloat hue, CGFloat saturation, CGFloat lightness);

static NSArray *CMRW3CColorNames(void);
static NSDictionary *CMRW3CNamedColors(void);


@implementation UIColor (HTMLColors)

#pragma mark - Reading

+ (UIColor *)colorWithCSS:(NSString *)cssColor
{
    UIColor *color = nil;
    NSScanner *scanner = [NSScanner scannerWithString:cssColor];
    [scanner scanCSSColor:&color];
    return (scanner.isAtEnd) ? color : nil;
}

+ (UIColor *)colorWithHexString:(NSString *)hexColor
{
    UIColor *color = nil;
    NSScanner *scanner = [NSScanner scannerWithString:hexColor];
    [scanner scanHexColor:&color];
    return (scanner.isAtEnd) ? color : nil;
}

+ (UIColor *)colorWithRGBString:(NSString *)rgbColor
{
    UIColor *color = nil;
    NSScanner *scanner = [NSScanner scannerWithString:rgbColor];
    [scanner scanRGBColor:&color];
    return (scanner.isAtEnd) ? color : nil;
}

+ (UIColor *)colorWithHSLString:(NSString *)hslColor
{
    UIColor *color = nil;
    NSScanner *scanner = [NSScanner scannerWithString:hslColor];
    [scanner scanHSLColor:&color];
    return (scanner.isAtEnd) ? color : nil;
}

+ (UIColor *)colorWithW3CNamedColor:(NSString *)namedColor
{
    UIColor *color = nil;
    NSScanner *scanner = [NSScanner scannerWithString:namedColor];
    [scanner scanW3CNamedColor:&color];
    return (scanner.isAtEnd) ? color : nil;
}

#pragma mark - Writing

static inline unsigned ToByte(CGFloat f)
{
    f = MAX(0, MIN(f, 1)); // Clamp
    return (unsigned)round(f * 255);
}

- (NSString *)hexStringValue
{
    NSString *hex = nil;
    CGFloat red, green, blue, alpha;
    if ([self cmr_getRed:&red green:&green blue:&blue alpha:&alpha]) {
        hex = [NSString stringWithFormat:@"#%02X%02X%02X",
               ToByte(red), ToByte(green), ToByte(blue)];
        if (alpha < 1.0) {
            hex = [hex stringByAppendingFormat:@"%02X", ToByte(alpha)];
        }
    }
    return hex;
}

- (NSString *)rgbStringValue
{
    NSString *rgb = nil;
    CGFloat red, green, blue, alpha;
    if ([self cmr_getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if (alpha == 1.0) {
            rgb = [NSString stringWithFormat:@"rgb(%u, %u, %u)",
                   ToByte(red), ToByte(green), ToByte(blue)];
        } else {
            rgb = [NSString stringWithFormat:@"rgba(%u, %u, %u, %g)",
                   ToByte(red), ToByte(green), ToByte(blue), alpha];
        }
    }
    return rgb;
}

static inline unsigned ToDeg(CGFloat f)
{
    return (unsigned)round(f * 360) % 360;
}

static inline unsigned ToPercentage(CGFloat f)
{
    f = MAX(0, MIN(f, 1)); // Clamp
    return (unsigned)round(f * 100);
}

- (NSString *)hslStringValue
{
    NSString *hsl = nil;
    CGFloat hue, saturation, brightness, alpha;
    if ([self cmr_getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha]) {
        CMRFloatTriple hslVal = HSB2HSL(hue, saturation, brightness);
        if (alpha == 1.0) {
            hsl = [NSString stringWithFormat:@"hsl(%u, %u%%, %u%%)",
                   ToDeg(hslVal.a), ToPercentage(hslVal.b), ToPercentage(hslVal.c)];
        } else {
            hsl = [NSString stringWithFormat:@"hsla(%u, %u%%, %u%%, %g)",
                   ToDeg(hslVal.a), ToPercentage(hslVal.b), ToPercentage(hslVal.c), alpha];
        }
    }
    return hsl;
}

// Fix up getting color components
- (BOOL)cmr_getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha
{
    if ([self getRed:red green:green blue:blue alpha:alpha]) {
        return YES;
    }

    CGFloat white;
    if ([self getWhite:&white alpha:alpha]) {
        if (red)
            *red = white;
        if (green)
            *green = white;
        if (blue)
            *blue = white;
        return YES;
    }

    return NO;
}

- (BOOL)cmr_getHue:(CGFloat *)hue saturation:(CGFloat *)saturation brightness:(CGFloat *)brightness alpha:(CGFloat *)alpha
{
    if ([self getHue:hue saturation:saturation brightness:brightness alpha:alpha]) {
        return YES;
    }

    CGFloat white;
    if ([self getWhite:&white alpha:alpha]) {
        if (hue)
            *hue = 0;
        if (saturation)
            *saturation = 0;
        if (brightness)
            *brightness = white;
        return YES;
    }

    return NO;
}

+ (NSArray *)W3CColorNames
{
    return [[CMRW3CNamedColors() allKeys] sortedArrayUsingSelector:@selector(compare:)];
}

@end

#pragma mark -

@implementation NSScanner (HTMLColors)

- (BOOL)scanCSSColor:(UIColor **)color
{
    return [self scanHexColor:color]
        || [self scanRGBColor:color]
        || [self scanHSLColor:color]
        || [self scanGrayColor:color]
        || [self scanW3CNamedColor:color];
}

- (BOOL)scanRGBColor:(UIColor *__autoreleasing *)color
{
    return [self cmr_caseInsensitiveWithCleanup:^BOOL{
        if ([self scanString:@"rgba" intoString:NULL]) {
            CMRFloatQuad scale = {1.0/255.0, 1.0/255.0, 1.0/255.0, 1.0};
            CMRFloatQuad q;
            if ([self cmr_scanFloatQuad:&q scale:scale]) {
                if (color) {
                    *color = [UIColor colorWithRed:q.a green:q.b blue:q.c alpha:q.d];
                }
                return YES;
            }
        } else if ([self scanString:@"rgb" intoString:NULL]) {
            CMRFloatTriple scale = {1.0/255.0, 1.0/255.0, 1.0/255.0};
            CMRFloatTriple t;
            if ([self cmr_scanFloatTriple:&t scale:scale]) {
                if (color) {
                    *color = [UIColor colorWithRed:t.a green:t.b blue:t.c alpha:1.0];
                }
                return YES;
            }
        }
        return NO;
    }];
}

- (BOOL)scanGrayColor:(UIColor *__autoreleasing *)color
{
    return [self cmr_caseInsensitiveWithCleanup:^BOOL{
        if ([self scanString:@"gray" intoString:NULL]) {
            CGFloat grayValue = 0.f;
            BOOL success = [self scanString:@"(" intoString:NULL]
                && [self cmr_scanNum:&grayValue scale:1.0/255.0];

            if (!success) {
                return NO;
            }

            __block CGFloat alphaValue = 1;
            [self cmr_resetScanLocationOnFailure:^BOOL{
                return [self scanString:@"," intoString:NULL]
                    && [self cmr_scanNum:&alphaValue scale:1.0/255.0];
            }];

            success = [self scanString:@")" intoString:NULL];

            if (success) {
                if (color) {
                    *color = [UIColor colorWithWhite:grayValue alpha:alphaValue];
                }
                return YES;
            }
        }
        return NO;
    }];
}

// Wrap hues in a circle, where [0,1] = [0°,360°]
static inline CGFloat CMRNormHue(CGFloat hue)
{
    return hue - floor(hue);
}

#define DEG (1.0 / 360.0)

- (BOOL)scanHSLColor:(UIColor *__autoreleasing *)color
{
    return [self cmr_caseInsensitiveWithCleanup:^BOOL{
        if ([self scanString:@"hsla" intoString:NULL]) {
            CMRFloatQuad scale = {DEG, 1.0, 1.0, 1.0};
            CMRFloatQuad q;
            if ([self cmr_scanFloatQuad:&q scale:scale]) {
                if (color) {
                    CMRFloatTriple t = HSL2HSB(CMRNormHue(q.a), q.b, q.c);
                    *color = [UIColor colorWithHue:t.a saturation:t.b brightness:t.c alpha:q.d];
                }
                return YES;
            }
        } else if ([self scanString:@"hsl" intoString:NULL]) {
            CMRFloatTriple scale = {DEG, 1.0, 1.0};
            CMRFloatTriple t;
            if ([self cmr_scanFloatTriple:&t scale:scale]) {
                if (color) {
                    t = HSL2HSB(CMRNormHue(t.a), t.b, t.c);
                    *color = [UIColor colorWithHue:t.a saturation:t.b brightness:t.c alpha:1.0];
                }
                return YES;
            }
        }
        return NO;
    }];
}

- (BOOL)scanHexColor:(UIColor *__autoreleasing *)color
{
    return [self cmr_resetScanLocationOnFailure:^BOOL{
        return [self scanString:@"#" intoString:NULL]
            && [self cmr_scanHexTriple:color];
    }];
}

- (BOOL)scanW3CNamedColor:(UIColor *__autoreleasing *)color
{
    return [self cmr_caseInsensitiveWithCleanup:^BOOL{
        NSArray *colorNames = CMRW3CColorNames();
        NSDictionary *namedColors = CMRW3CNamedColors();
        for (NSString *name in colorNames) {
            if ([self scanString:name intoString:NULL]) {
                if (color) {
                    *color = [UIColor colorWithHexString:namedColors[name]];
                }
                return YES;
            }
        }
        return NO;
    }];
}

#pragma mark - General Parsing Helpers

- (void)cmr_withSkip:(NSCharacterSet *)chars run:(void (^)(void))block
{
    NSCharacterSet *skipped = self.charactersToBeSkipped;
    self.charactersToBeSkipped = chars;
    block();
    self.charactersToBeSkipped = skipped;
}

- (void)cmr_withNoSkip:(void (^)(void))block
{
    NSCharacterSet *skipped = self.charactersToBeSkipped;
    self.charactersToBeSkipped = nil;
    block();
    self.charactersToBeSkipped = skipped;
}

- (NSRange)cmr_rangeFromScanLocation
{
    NSUInteger loc = self.scanLocation;
    NSUInteger len = self.string.length - loc;
    return NSMakeRange(loc, len);
}

- (void)cmr_skipCharactersInSet:(NSCharacterSet *)chars
{
    [self cmr_withNoSkip:^{
        [self scanCharactersFromSet:chars intoString:NULL];
    }];
}

- (void)cmr_skip
{
    [self cmr_skipCharactersInSet:self.charactersToBeSkipped];
}

- (BOOL)cmr_resetScanLocationOnFailure:(BOOL (^)(void))block
{
    NSUInteger initialScanLocation = self.scanLocation;
    if (!block()) {
        self.scanLocation = initialScanLocation;
        return NO;
    }
    return YES;
}

- (BOOL)cmr_caseInsensitiveWithCleanup:(BOOL (^)(void))block
{
    NSUInteger initialScanLocation = self.scanLocation;
    BOOL caseSensitive = self.caseSensitive;
    self.caseSensitive = NO;

    BOOL success = block();
    if (!success) {
        self.scanLocation = initialScanLocation;
    }

    self.caseSensitive = caseSensitive;
    return success;
}

// Scan, but only so far
- (NSRange)cmr_scanCharactersInSet:(NSCharacterSet *)chars maxLength:(NSUInteger)maxLength intoString:(NSString **)outString
{
    NSRange range = [self cmr_rangeFromScanLocation];
    range.length = MIN(range.length, maxLength);

    NSUInteger len;
    for (len = 0; len < range.length; ++len) {
        if (![chars characterIsMember:[self.string characterAtIndex:(range.location + len)]]) {
            break;
        }
    }

    NSRange charRange = NSMakeRange(range.location, len);
    if (outString) {
        *outString = [self.string substringWithRange:charRange];
    }

    self.scanLocation = charRange.location + charRange.length;

    return charRange;
}

#pragma mark - Hex Parsing

// Hex characters
static NSCharacterSet *CMRHexCharacters() {
    static NSCharacterSet *hexChars;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hexChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    });
    return hexChars;
}

// We know we've got hex already, so assume this works
static NSUInteger CMRParseHex(NSString *str, BOOL repeated)
{
    unsigned int ans = 0;
    if (repeated) {
        str = [NSString stringWithFormat:@"%@%@", str, str];
    }
    NSScanner *scanner = [NSScanner scannerWithString:str];
    [scanner scanHexInt:&ans];
    return (NSUInteger)ans;
}

// Scan FFF, FFFF, FFFFFF or FFFFFFFF, doesn't reset scan location on failure
- (BOOL)cmr_scanHexTriple:(UIColor **)color
{
    NSString *hex = nil;
    NSRange range = [self cmr_scanCharactersInSet:CMRHexCharacters() maxLength:8 intoString:&hex];
    CGFloat red, green, blue, alpha;
    if (hex.length >= 6) {
        // Parse 2 chars per component
        red   = CMRParseHex([hex substringWithRange:NSMakeRange(0, 2)], NO) / 255.0;
        green = CMRParseHex([hex substringWithRange:NSMakeRange(2, 2)], NO) / 255.0;
        blue  = CMRParseHex([hex substringWithRange:NSMakeRange(4, 2)], NO) / 255.0;
        if (hex.length == 8) {
            alpha = CMRParseHex([hex substringWithRange:NSMakeRange(6, 2)], NO) / 255.0;
        } else {
            alpha = 1;
        }
    } else if (hex.length >= 3) {
        // Parse 1 char per component, but repeat it to calculate hex value
        red   = CMRParseHex([hex substringWithRange:NSMakeRange(0, 1)], YES) / 255.0;
        green = CMRParseHex([hex substringWithRange:NSMakeRange(1, 1)], YES) / 255.0;
        blue  = CMRParseHex([hex substringWithRange:NSMakeRange(2, 1)], YES) / 255.0;
        if (hex.length >= 4) {
            alpha = CMRParseHex([hex substringWithRange:NSMakeRange(3, 1)], YES) / 255.0;
            self.scanLocation = range.location + 4;
        } else {
            alpha = 1;
            self.scanLocation = range.location + 3;
        }
    } else {
        return NO; // Fail
    }
    if (color) {
        *color = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }
    return YES;
}

#pragma mark - Component Parsing

// Scan a float or percentage. Multiply float by `scale` if it was not a
// percentage.
- (BOOL)cmr_scanNum:(CGFloat *)value scale:(CGFloat)scale
{
    float f = 0.0;
    if ([self scanFloat:&f]) {
        if ([self scanString:@"%" intoString:NULL]) {
            f *= 0.01;
        } else {
            f *= scale;
        }
        if (value) {
            *value = f;
        }
        return YES;
    }
    return NO;
}

// Scan a triple of numbers "(10, 10, 10)". If they are not percentages, multiply
// by the corresponding `scale` component.
- (BOOL)cmr_scanFloatTriple:(CMRFloatTriple *)triple scale:(CMRFloatTriple)scale
{
    __block BOOL success = NO;
    __block CMRFloatTriple t;
    [self cmr_withSkip:[NSCharacterSet whitespaceAndNewlineCharacterSet] run:^{
        success = [self scanString:@"(" intoString:NULL]
            && [self cmr_scanNum:&(t.a) scale:scale.a]
            && [self scanString:@"," intoString:NULL]
            && [self cmr_scanNum:&(t.b) scale:scale.b]
            && [self scanString:@"," intoString:NULL]
            && [self cmr_scanNum:&(t.c) scale:scale.c]
            && [self scanString:@")" intoString:NULL];
    }];
    if (triple) {
        *triple = t;
    }
    return success;
}

// Scan a quad of numbers "(10, 10, 10, 10)". If they are not percentages,
// multiply by the corresponding `scale` component.
- (BOOL)cmr_scanFloatQuad:(CMRFloatQuad *)quad scale:(CMRFloatQuad)scale
{
    __block BOOL success = NO;
    __block CMRFloatQuad q;
    [self cmr_withSkip:[NSCharacterSet whitespaceAndNewlineCharacterSet] run:^{
        success = [self scanString:@"(" intoString:NULL]
            && [self cmr_scanNum:&(q.a) scale:scale.a]
            && [self scanString:@"," intoString:NULL]
            && [self cmr_scanNum:&(q.b) scale:scale.b]
            && [self scanString:@"," intoString:NULL]
            && [self cmr_scanNum:&(q.c) scale:scale.c]
            && [self scanString:@"," intoString:NULL]
            && [self cmr_scanNum:&(q.d) scale:scale.d]
            && [self scanString:@")" intoString:NULL];
    }];
    if (quad) {
        *quad = q;
    }
    return success;
}

@end

#pragma mark - Colorspace Transforms

static inline CMRFloatTriple HSB2HSL(CGFloat hue, CGFloat saturation, CGFloat brightness)
{
    CGFloat l = (2.0 - saturation) * brightness;
    saturation *= brightness;
    CGFloat satDiv = (l <= 1.0) ? l : (2.0 - l);
    if (satDiv != 0.0) {
        saturation /= satDiv;
    }
    l *= 0.5;
    CMRFloatTriple hsl = {
        hue,
        saturation,
        l
    };
    return hsl;
}

static inline CMRFloatTriple HSL2HSB(CGFloat hue, CGFloat saturation, CGFloat l)
{
    l *= 2.0;
    CGFloat s = saturation * ((l <= 1.0) ? l : (2.0 - l));
    CGFloat brightness = (l + s) * 0.5;
    if (s != 0.0) {
        s = (2.0 * s) / (l + s);
    }
    CMRFloatTriple hsb = {
        hue,
        s,
        brightness
    };
    return hsb;
}

// Color names, longest first
static NSArray *CMRW3CColorNames() {
    static NSArray *colorNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorNames = [[CMRW3CNamedColors() allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *k1, NSString *k2) {
            NSInteger diff = k1.length - k2.length;
            if (!diff) {
                return NSOrderedSame;
            } else if (diff > 0) {
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        }];
    });
    return colorNames;
}

// Color values as defined in CSS3 spec.
// See: http://www.w3.org/TR/css3-color/#svg-color
static NSDictionary *CMRW3CNamedColors() {
    static NSDictionary *namedColors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        namedColors = @{
            @"AliceBlue" : @"#F0F8FF",
            @"AntiqueWhite" : @"#FAEBD7",
            @"Aqua" : @"#00FFFF",
            @"Aquamarine" : @"#7FFFD4",
            @"Azure" : @"#F0FFFF",
            @"Beige" : @"#F5F5DC",
            @"Bisque" : @"#FFE4C4",
            @"Black" : @"#000000",
            @"BlanchedAlmond" : @"#FFEBCD",
            @"Blue" : @"#0000FF",
            @"BlueViolet" : @"#8A2BE2",
            @"Brown" : @"#A52A2A",
            @"BurlyWood" : @"#DEB887",
            @"CadetBlue" : @"#5F9EA0",
            @"Chartreuse" : @"#7FFF00",
            @"Chocolate" : @"#D2691E",
            @"Coral" : @"#FF7F50",
            @"CornflowerBlue" : @"#6495ED",
            @"Cornsilk" : @"#FFF8DC",
            @"Crimson" : @"#DC143C",
            @"Cyan" : @"#00FFFF",
            @"DarkBlue" : @"#00008B",
            @"DarkCyan" : @"#008B8B",
            @"DarkGoldenRod" : @"#B8860B",
            @"DarkGray" : @"#A9A9A9",
            @"DarkGrey" : @"#A9A9A9",
            @"DarkGreen" : @"#006400",
            @"DarkKhaki" : @"#BDB76B",
            @"DarkMagenta" : @"#8B008B",
            @"DarkOliveGreen" : @"#556B2F",
            @"DarkOrange" : @"#FF8C00",
            @"DarkOrchid" : @"#9932CC",
            @"DarkRed" : @"#8B0000",
            @"DarkSalmon" : @"#E9967A",
            @"DarkSeaGreen" : @"#8FBC8F",
            @"DarkSlateBlue" : @"#483D8B",
            @"DarkSlateGray" : @"#2F4F4F",
            @"DarkSlateGrey" : @"#2F4F4F",
            @"DarkTurquoise" : @"#00CED1",
            @"DarkViolet" : @"#9400D3",
            @"DeepPink" : @"#FF1493",
            @"DeepSkyBlue" : @"#00BFFF",
            @"DimGray" : @"#696969",
            @"DimGrey" : @"#696969",
            @"DodgerBlue" : @"#1E90FF",
            @"FireBrick" : @"#B22222",
            @"FloralWhite" : @"#FFFAF0",
            @"ForestGreen" : @"#228B22",
            @"Fuchsia" : @"#FF00FF",
            @"Gainsboro" : @"#DCDCDC",
            @"GhostWhite" : @"#F8F8FF",
            @"Gold" : @"#FFD700",
            @"GoldenRod" : @"#DAA520",
            @"Gray" : @"#808080",
            @"Grey" : @"#808080",
            @"Green" : @"#008000",
            @"GreenYellow" : @"#ADFF2F",
            @"HoneyDew" : @"#F0FFF0",
            @"HotPink" : @"#FF69B4",
            @"IndianRed" : @"#CD5C5C",
            @"Indigo" : @"#4B0082",
            @"Ivory" : @"#FFFFF0",
            @"Khaki" : @"#F0E68C",
            @"Lavender" : @"#E6E6FA",
            @"LavenderBlush" : @"#FFF0F5",
            @"LawnGreen" : @"#7CFC00",
            @"LemonChiffon" : @"#FFFACD",
            @"LightBlue" : @"#ADD8E6",
            @"LightCoral" : @"#F08080",
            @"LightCyan" : @"#E0FFFF",
            @"LightGoldenRodYellow" : @"#FAFAD2",
            @"LightGray" : @"#D3D3D3",
            @"LightGrey" : @"#D3D3D3",
            @"LightGreen" : @"#90EE90",
            @"LightPink" : @"#FFB6C1",
            @"LightSalmon" : @"#FFA07A",
            @"LightSeaGreen" : @"#20B2AA",
            @"LightSkyBlue" : @"#87CEFA",
            @"LightSlateGray" : @"#778899",
            @"LightSlateGrey" : @"#778899",
            @"LightSteelBlue" : @"#B0C4DE",
            @"LightYellow" : @"#FFFFE0",
            @"Lime" : @"#00FF00",
            @"LimeGreen" : @"#32CD32",
            @"Linen" : @"#FAF0E6",
            @"Magenta" : @"#FF00FF",
            @"Maroon" : @"#800000",
            @"MediumAquaMarine" : @"#66CDAA",
            @"MediumBlue" : @"#0000CD",
            @"MediumOrchid" : @"#BA55D3",
            @"MediumPurple" : @"#9370DB",
            @"MediumSeaGreen" : @"#3CB371",
            @"MediumSlateBlue" : @"#7B68EE",
            @"MediumSpringGreen" : @"#00FA9A",
            @"MediumTurquoise" : @"#48D1CC",
            @"MediumVioletRed" : @"#C71585",
            @"MidnightBlue" : @"#191970",
            @"MintCream" : @"#F5FFFA",
            @"MistyRose" : @"#FFE4E1",
            @"Moccasin" : @"#FFE4B5",
            @"NavajoWhite" : @"#FFDEAD",
            @"Navy" : @"#000080",
            @"OldLace" : @"#FDF5E6",
            @"Olive" : @"#808000",
            @"OliveDrab" : @"#6B8E23",
            @"Orange" : @"#FFA500",
            @"OrangeRed" : @"#FF4500",
            @"Orchid" : @"#DA70D6",
            @"PaleGoldenRod" : @"#EEE8AA",
            @"PaleGreen" : @"#98FB98",
            @"PaleTurquoise" : @"#AFEEEE",
            @"PaleVioletRed" : @"#DB7093",
            @"PapayaWhip" : @"#FFEFD5",
            @"PeachPuff" : @"#FFDAB9",
            @"Peru" : @"#CD853F",
            @"Pink" : @"#FFC0CB",
            @"Plum" : @"#DDA0DD",
            @"PowderBlue" : @"#B0E0E6",
            @"Purple" : @"#800080",
            @"RebeccaPurple": @"#663399",
            @"Red" : @"#FF0000",
            @"RosyBrown" : @"#BC8F8F",
            @"RoyalBlue" : @"#4169E1",
            @"SaddleBrown" : @"#8B4513",
            @"Salmon" : @"#FA8072",
            @"SandyBrown" : @"#F4A460",
            @"SeaGreen" : @"#2E8B57",
            @"SeaShell" : @"#FFF5EE",
            @"Sienna" : @"#A0522D",
            @"Silver" : @"#C0C0C0",
            @"SkyBlue" : @"#87CEEB",
            @"SlateBlue" : @"#6A5ACD",
            @"SlateGray" : @"#708090",
            @"SlateGrey" : @"#708090",
            @"Snow" : @"#FFFAFA",
            @"SpringGreen" : @"#00FF7F",
            @"SteelBlue" : @"#4682B4",
            @"Tan" : @"#D2B48C",
            @"Teal" : @"#008080",
            @"Thistle" : @"#D8BFD8",
            @"Tomato" : @"#FF6347",
            @"Turquoise" : @"#40E0D0",
            @"Violet" : @"#EE82EE",
            @"Wheat" : @"#F5DEB3",
            @"White" : @"#FFFFFF",
            @"WhiteSmoke" : @"#F5F5F5",
            @"Yellow" : @"#FFFF00",
            @"YellowGreen" : @"#9ACD32",
            @"transparent": @"#0000", // Transparent black
        };
    });
    return namedColors;
}
