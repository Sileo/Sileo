//
//  Decompression.h
//  Sileo
//
//  Created by Amy While on 23/03/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

#ifndef Decompression_h
#define Decompression_h

#include <stdio.h>

uint8_t decompressGzip(FILE *input, FILE *output);
uint8_t decompressXz(FILE *input, FILE *output, uint8_t type);
uint8_t decompressBzip(FILE *input, FILE *output);
uint8_t decompressZst(FILE *input, FILE *output);

#endif /* Decompression */
