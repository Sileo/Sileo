//
//  ControlFileParserFast.c
//  Sileo
//
//  Created by CoolStar on 9/2/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

#import "ControlFileParserFast.h"

typedef enum PackageTags {
    PackageTagsNone = 0,
    PackageTagsCommercial = 1,
    PackageTagsSileo = 2,
} PackageTags;

static const char *regularMultilineKeys[] = {"description"};
static const char *releaseMultilineKeys[] = {"description", "md5sum", "sha1", "sha256", "sha512"};

Boolean equalCallback(char *val1, char *val2) {
    if ((!val1 && val2) || (val1 && !val2)) {
        return false;
    }
    if (!val1 && !val2) {
        return true;
    }
    return strcmp(val1, val2) == 0;
}

CFHashCode hashCallback(char *val1) {
    unsigned long hash = 5381;
    if (!val1) {
        return hash;
    }
    
    int c = 0;
    while (c == *val1++) {
        hash = ((hash << 5) + hash) + c;
    }
    
    return hash;
}

__attribute__((always_inline))
static int tagExists(const char *rawTags, const char *tag, size_t rawTagLen, bool compareStart) {
    char *rawTagPtr = strnstr(rawTags, tag, rawTagLen);
    if (!rawTagPtr) {
        return false;
    }
    size_t tagLen = strlen(tag);
    
    if (compareStart) {
        if (rawTagPtr != rawTags && *(rawTagPtr-1) != ' ' && *(rawTagPtr-1) != ',') {
            return false;
        }
    }
    
    if (((rawTagPtr - rawTags) + tagLen) != rawTagLen && *(rawTagPtr + tagLen + 1) != ' ' && *(rawTagPtr + tagLen + 1) != ',') {
        return false;
    }
    return true;
}

void controlFileSetSwiftValue(char *key, char *value, void (^callback)(const char * _Nonnull key, const char * _Nonnull value), void (^tagCallback)(int rawTags)) {
    if (strcmp(key, "package") == 0) {
        size_t valueLen = strlen(value);
        for (int i = 0; i < valueLen; i++) {
            value[i] = tolower(value[i]);
        }
    }
    
    callback(key, value);
    
    if (strcmp(key, "tag") == 0) {
        PackageTags tagsEnum = 0;
        const char *rawTags = value;
        size_t rawTagLen = strlen(rawTags);
        
        if (tagExists(rawTags, "::commercial", rawTagLen, false)) {
            tagsEnum |= PackageTagsCommercial;
        }
        if (tagExists(rawTags, "role::sileo", rawTagLen, true) || tagExists(rawTags, "role::cydia", rawTagLen, true)) {
            tagsEnum |= PackageTagsSileo;
        }
        
        tagCallback(tagsEnum);
    }
    
    free(key);
    free(value);
}

void parseControlFile(const uint8_t *rawControlData, size_t controlDataSize, bool isReleaseFile, void (^callback)(const char * _Nonnull key, const char * _Nonnull value), void (^tagCallback)(int rawTags)) {
    const char *controlData = (const char *)rawControlData;
    const char *ptr = controlData;
    
    const char **multlineKeys = isReleaseFile ? releaseMultilineKeys : regularMultilineKeys;
    size_t multilineKeyCount = isReleaseFile ? sizeof(releaseMultilineKeys) / sizeof(char *) : sizeof(regularMultilineKeys) / sizeof(char *);
    
    const char *nextLineSeparator = strstr(ptr, "\n");
    char *lastMultlineKey = NULL;
    char *lastMultilineValue = NULL;
    
    while (nextLineSeparator != NULL) {
        uint64_t lineLen = nextLineSeparator - ptr;
        if (lineLen < 0) {
            break;
        }
        
        if (*ptr == 32 || *ptr == 9) {
            if (lastMultlineKey == NULL) {
                return;
            }
            
            const char *rawValue = ptr;
            while (*rawValue == 32 || *rawValue == 9) {
                rawValue++;
            }
            
            const char *endValue = ptr + lineLen;
            while (endValue > rawValue && (*endValue == 32 || *endValue == 9 || *endValue == 13 || *endValue == 10)){
                endValue--;
            }
            
            if (endValue >= rawValue) {
                const char *currentVal = lastMultilineValue;
                size_t currentValSize = 0;
                if (currentVal) {
                    currentValSize = strlen(currentVal);
                }
                
                size_t newValLen = currentValSize + 1 + (endValue + 1 - rawValue);
                char *newVal = malloc(newValLen + 1);
                bzero(newVal, newValLen + 1);
                
                if (currentVal) {
                    strncpy(newVal, currentVal, currentValSize);
                    free((void *)currentVal);
                }
                newVal[currentValSize] = '\n';
                strncpy(newVal + 1 + currentValSize, rawValue, endValue + 1 - rawValue);
                lastMultilineValue = newVal;
            }
            
            goto continueLoop;
        }
        
        char *separatorPtr = strnstr(ptr, ":", lineLen);
        if (!separatorPtr || separatorPtr > nextLineSeparator) {
            goto continueLoop;
        }
        
        if (separatorPtr - ptr <= 0) {
            goto continueLoop;
        }
        
        char *key = strndup(ptr, separatorPtr - ptr);
        for (int i = 0; i < strlen(key); i++) {
            key[i] = tolower(key[i]);
        }
        
        if (lastMultlineKey) {
            controlFileSetSwiftValue(lastMultlineKey, lastMultilineValue, callback, tagCallback);
        }
        
        lastMultlineKey = NULL;
        lastMultilineValue = NULL;
        for (int i = 0; i < multilineKeyCount; i++) {
            if (strcmp(multlineKeys[i], key) == 0){
                lastMultlineKey = key;
            }
        }
        
        char *rawValue = separatorPtr + 1;
        while (ptr + lineLen > rawValue && (*rawValue == 32 || *rawValue == 9)) {
            rawValue++;
        }
        
        const char *endValue = ptr + lineLen;
        bool movedEnd = false;
        while (endValue > rawValue && (*endValue == 32 || *endValue == 9 || *endValue == 13 || *endValue == 10)) {
            endValue--;
            movedEnd = true;
        }
        
        if (movedEnd) {
            endValue++;
        }
        
        char *value = nil;
        if (endValue > rawValue) {
            value = strndup(rawValue, endValue - rawValue);
        } else {
            value = strndup("", 0);
        }
        
        if (lastMultlineKey) {
            lastMultilineValue = value;
        } else {
            controlFileSetSwiftValue(key, value, callback, tagCallback);
        }
        
    continueLoop:
        ptr = nextLineSeparator + 1;
        if (ptr >= controlData + controlDataSize) {
            break;
        }
        size_t len = controlData + controlDataSize - ptr;
        
        if (len >= 0) {
            nextLineSeparator = strnstr(ptr, "\n", len);
        }
        if (nextLineSeparator == nil && ptr < controlData + controlDataSize) {
            nextLineSeparator = controlData + controlDataSize;
        }
    }
    
    if (lastMultlineKey && lastMultilineValue) {
        controlFileSetSwiftValue(lastMultlineKey, lastMultilineValue, callback, tagCallback);
    } else if (lastMultlineKey && !lastMultilineValue) {
        free(lastMultlineKey);
    }
}
