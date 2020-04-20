//
//  ControlFileParserFast.h
//  Sileo
//
//  Created by CoolStar on 9/2/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>

#ifndef ControlFileParserFast_h
#define ControlFileParserFast_h

void parseControlFile(const uint8_t *_Nonnull, size_t, bool, void (^__nonnull callback)(const char *_Nonnull key, const char *_Nonnull value), void (^__nonnull tagCallback)(int));

#endif /* ControlFileParserFast_h */
