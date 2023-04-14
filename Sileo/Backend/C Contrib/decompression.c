//
//  Decompression.c
//  Sileo
//
//  Created by Amy While on 23/03/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

#include <stdio.h>
#include <stdint.h>

#import <bzlib.h>
#import <stdint.h>
#import <zlib.h>

#import "libzstd.h"
#import "lzma.h"

uint8_t decompressGzip(FILE *input, FILE *output) {
    uint8_t inBuf[16384];
    uint8_t outBuf[16384];
    memset(inBuf, 0, sizeof(inBuf));
    memset(outBuf, 0, sizeof(outBuf));
    uint32_t have = 0;
    
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    
    int32_t status = inflateInit2_(&stream, MAX_WBITS + 32, ZLIB_VERSION, sizeof(stream));
    if (status != Z_OK) {
        return 2;
    }
    uint8_t error = 0;
    do {
        stream.avail_in = (unsigned int)fread(inBuf, 1, 16384, input);
        if (ferror(input)) {
            error = 3;
            goto cleanup;
        }
        if (!stream.avail_in)
            break;
        stream.next_in = inBuf;
        do {
            stream.avail_out = 16384;
            stream.next_out = outBuf;
            status = inflate(&stream, Z_NO_FLUSH);
            switch (status) {
                case Z_NEED_DICT:
                    error = 4;
                    goto cleanup;
                case Z_DATA_ERROR:
                    error = 5;
                    goto cleanup;
                case Z_MEM_ERROR:
                    error = 6;
                    goto cleanup;
                case Z_STREAM_ERROR:
                    error = 7;
                    goto cleanup;
                default:
                    break;
            }
            have = 16384 - stream.avail_out;
            size_t wrote = fwrite(outBuf, 1, have, output);
            if (wrote != have) {
                error = 8;
                goto cleanup;
            }
        } while (stream.avail_out == 0);
    } while (status != Z_STREAM_END);
    
    if (status != Z_STREAM_END) {
        error = 9;
    }
cleanup:
    inflateEnd(&stream);
    return error;
}

uint8_t decompressXz(FILE *input, FILE *output, uint8_t type) {
    lzma_stream strm;
    memset(&strm, 0, sizeof(strm));
    
    uint8_t error = 0;
    int ret = (type == 0) ? lzma_stream_decoder(&strm, UINT64_MAX, 8) : lzma_alone_decoder(&strm, UINT64_MAX);
    switch (ret) {
        case LZMA_OK:
            break;
        case LZMA_MEM_ERROR:
            error = 1;
            goto cleanup;
        case LZMA_OPTIONS_ERROR:
            error = 2;
            goto cleanup;
        default:
            error = 3;
            goto cleanup;
    }
    
    int action = LZMA_RUN;
    uint8_t inBuf[BUFSIZ];
    uint8_t outBuf[BUFSIZ];
    memset(inBuf, 0, sizeof(inBuf));
    memset(outBuf, 0, sizeof(outBuf));
    
    strm.next_in = NULL;
    strm.avail_in = 0;
    strm.next_out = outBuf;
    strm.avail_out = sizeof(outBuf);
    
    while (1) {
        if (!strm.avail_in && !feof(input)) {
            strm.next_in = inBuf;
            strm.avail_in = fread(inBuf, 1, sizeof(inBuf), input);
            if (ferror(input)) {
                error = 4;
                goto cleanup;
            }
            if (feof(input)) {
                action = LZMA_FINISH;
            }
        }
        
        ret = lzma_code(&strm, action);
        if (!strm.avail_out || ret == LZMA_STREAM_END) {
            size_t writeSize = sizeof(outBuf) - strm.avail_out;
            size_t wrote = fwrite(outBuf, 1, writeSize, output);
            if (wrote != writeSize) {
                error = 5;
                goto cleanup;
            }
            strm.next_out = outBuf;
            strm.avail_out = sizeof(outBuf);
        }
        
        switch (ret) {
            case LZMA_OK:
                break;
            case LZMA_STREAM_END:
                error = 0;
                goto cleanup;
            case LZMA_MEM_ERROR:
                error = 1;
                goto cleanup;
            case LZMA_FORMAT_ERROR:
                error = 8;
                goto cleanup;
            case LZMA_DATA_ERROR:
                error = 9;
                goto cleanup;
            case LZMA_BUF_ERROR:
                error = 9;
                goto cleanup;
            default:
                error = 3;
                goto cleanup;
        }
    }
    
cleanup:
    lzma_end(&strm);
    return error;
}

uint8_t decompressBzip(FILE *input, FILE *output) {
    uint8_t error = 0;
    uint8_t buf[4096];
    memset(buf, 0, sizeof(buf));
    
    int bzError = 0;
    BZFILE *bzf = BZ2_bzReadOpen(&bzError, input, 0, 0, NULL, 0);
    if (bzError != BZ_OK) {
        error = 1;
        goto cleanup;
    }
    while (bzError == BZ_OK) {
        int read = BZ2_bzRead(&bzError, bzf, buf, sizeof(buf));
        if (bzError == BZ_OK || bzError == BZ_STREAM_END) {
            size_t wrote = fwrite(buf, 1, read, output);
            if (wrote != read) {
                error = 2;
                goto cleanup;
            }
        }
    }
    if (bzError != BZ_STREAM_END) {
        error = 3;
    }
cleanup:
    BZ2_bzReadClose(NULL, bzf);
    return error;
}

#if !TARGET_SANDBOX
uint8_t decompressZst(FILE *input, FILE *output) {
    size_t buffInSize = ZSTD_DStreamInSize();
    size_t buffOutSize = ZSTD_DStreamOutSize();
    uint8_t inBuf[buffInSize];
    uint8_t outBuf[buffOutSize];
    memset(inBuf, 0, buffInSize);
    memset(outBuf, 0, buffOutSize);
    
    ZSTD_DCtx *dctx = ZSTD_createDCtx();
    if (!dctx) {
        return 1;
    }
    uint8_t error = 0;
    size_t read = 0;
    size_t lastRet = 0;
    uint8_t isEmpty = 1;
    
    while (1) {
        read = fread(inBuf, 1, buffInSize, input);
        if (!read)
            break;
        isEmpty = 0;
        
        ZSTD_inBuffer input;
        input.src = inBuf;
        input.size = read;
        input.pos = 0;
        
        while (input.pos <input.size) {
            ZSTD_outBuffer out;
            out.dst = outBuf;
            out.size = buffOutSize;
            out.pos = 0;
            
            size_t ret = ZSTD_decompressStream(dctx, &out, &input);
            if (ZSTD_isError(ret)) {
                error = 5;
                goto cleanup;
            }
            size_t written = fwrite(outBuf, 1, out.pos, output);
            if (written != out.pos) {
                error = 2;
                goto cleanup;
            }
            lastRet = ret;
        }
    }
    if (isEmpty) {
        error = 3;
        goto cleanup;
    }
    if (lastRet) {
        error = 4;
    }
cleanup:
    ZSTD_freeDCtx(dctx);
    return error;
}
#endif
