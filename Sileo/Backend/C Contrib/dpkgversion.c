//
//  dpkgversion.c
//  Sileo
//
//  Created by Amy While on 21/07/2022.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

#include "dpkgversion.h"

int order(char ch) {
    if (isalpha(ch)) {
        return ch;
    } else if (ch == 126) {
        return -1;
    } else if (ch > 0) {
        return (int)ch + 256;
    }
    return 0;
}

int validate(char *string, int *length) {
    for (int i = 0; i < *length; i++) {
        char character = string[i];
        if (!(isdigit(character) || isalpha(character) || strrchr(".-+~:", character))) {
            return 1;
        }
    }
    return 0;
}

int verrevcmp(const char *val, const char *ref) {
    int firstDiff = 0;
    if (!val)
        val = "";
    if (!ref || !(*ref))
        ref = "";
    while (*val || *ref) {
        // If not a digit, assume parenthesis
        while ((*val && !isdigit(*val)) || (*ref && !isdigit(*ref))) {
            int valord = order(*val);
            int reford = order(*ref);
            if (valord != reford)
                return valord - reford;
            val++;
            ref++;
        }
        
        // Skip past 0
        while (*val == 48 && *val)
            val++;
        while (*ref == 48 && *ref)
            ref++;
        
        // If both a digit, compare which is larger
        while (isdigit(*val) && isdigit(*ref)) {
            if (!firstDiff)
                firstDiff = *val - *ref;
            val++;
            ref++;
        }
        
        // Return whichever value is larger
        if (isdigit(*val))
            return 1;
        if (isdigit(*ref))
            return -1;
        if (firstDiff)
            return firstDiff;
    }
    
    return 0;
}

void parseVersion(char *version, int *length, char **error, struct DpkgVersion *dpkgVersion) {
    int found = 0;
    int searchIdx = 0;
    for (; searchIdx < *length; searchIdx++) {
        if (version[searchIdx] == 58) {
            found = 1;
            break;
        }
    }
    
    long epochNum = 0;
    if (found) {
        if (searchIdx == 0) {
            *error = "epoch cannot be blank";
            return;
        }
        char epochString[searchIdx];
        memcpy(epochString, version, searchIdx);
        
        *length -= (searchIdx + 1);
        version += (searchIdx + 1);
        
        if (!*length) {
            *error = "nothing after colon in version number";
            return;
        }
        
        errno = 0;
        char *ret;
        epochNum = strtol(epochString, &ret, 10);
        if (strcmp(ret, epochString) == 0) {
            *error = "epoch is not a number";
            return;
        }
        
        if (epochNum > INT_MAX || errno == ERANGE) {
            *error = "epoch version is too big";
            return;
        }
        if (epochNum < 0) {
            *error = "epoch is negative";
            return;
        }
    }
    
    searchIdx = *length - 1;
    found = 0;

    for (; searchIdx >= 0; searchIdx--) {
        if (version[searchIdx] == 45) {
            found = 1;
            break;
        }
    }
    if (found) {
        version[searchIdx] = 0;
    }
    
    char *versionStr = version;
    int versionStrCount = *length;
    
    char *revisionStr = "";
    int revisionStrCount = 1;
    
    if (found) {
        versionStrCount = searchIdx + 1;
        versionStr = malloc(versionStrCount);
        memcpy(versionStr, version, versionStrCount);

        revisionStrCount = *length - (searchIdx + 1);
        revisionStr = malloc(revisionStrCount);
        memcpy(revisionStr, version + searchIdx + 1, revisionStrCount);
    }

    if (validate(versionStr, &versionStrCount) || validate(revisionStr, &revisionStrCount)) {
        *error = "invalid character in version number";
        if (found) {
            free(versionStr);
            free(revisionStr);
        }
        return;
    }
    
    if ((versionStrCount && versionStr[versionStrCount - 1]) || (revisionStrCount && revisionStr[revisionStrCount - 1])) {
        *error = "needs null termination";
        if (found) {
            free(versionStr);
            free(revisionStr);
        }
        return;
    }

    dpkgVersion->requiresFree = found;
    dpkgVersion->epoch = (unsigned int)epochNum;
    dpkgVersion->version = versionStr;
    dpkgVersion->revision = revisionStr;
}

int compareVersion(const char *version1, int version1Count, const char *version2, int version2Count) {
    if (strcmp(version1, version2) == 0)
        return 0;

    char *_version1 = (char *)version1;
    char *_version2 = (char *)version2;

    struct DpkgVersion package1 = { 0 };
    struct DpkgVersion package2 = { 0 };
    package1.requiresFree = 0;
    package2.requiresFree = 0;
    
    char *error = NULL;
    
    int cmp = 0;
    
    parseVersion(_version1, &version1Count, &error, &package1);
    if (error)
        goto cleanup;
    parseVersion(_version2, &version2Count, &error, &package2);
    if (error)
        goto cleanup;
    if (package1.epoch > package2.epoch) {
        cmp = 1;
        goto cleanup;
    }
        
    if (package1.epoch < package2.epoch) {
        cmp = -1;
        goto cleanup;
    }
    
    int retVal = verrevcmp(package1.version, package2.version);
    if (retVal) {
        cmp = retVal;
        goto cleanup;
    }
    cmp = verrevcmp(package1.revision, package2.revision);
    
cleanup:
    if (package1.requiresFree) {
        free(package1.version);
        free(package1.revision);
    }
    if (package2.requiresFree) {
        free(package2.version);
        free(package2.revision);
    }
    return cmp;
}
