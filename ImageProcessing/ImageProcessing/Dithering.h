#ifndef DITHERING_H
#define DITHERING_H

#include <utility>
#include <iostream>
#include <limits>
#include <algorithm>
#include <intrin.h>

uint64_t applyJohnSteinberg(const uint32_t& numberOfColors, unsigned char* colorTable,  uint32_t& size, const uint32_t& width, const uint32_t& height, unsigned char* dataIn, uint32_t& sizeOut, unsigned char* dataOut, double* errorBuffer);

#endif

