#ifndef COMPOSITING_LINE_H
#define COMPOSITING_LINE_H

#include <inttypes.h>

// bits per pixel
#ifndef SOC_VIDEO_BPP
#define BPP 8
#else
#define BPP SOC_VIDEO_BPP
#endif

// RGB2PIXEL converts from 24-bit RGB888 to actual pixel_t format (8/16/32 bit)
#if BPP == 8
typedef uint8_t pixel_t;
#define RGB2PIXEL(x) ( (((x) & 0xE00000) >> (24-3-5)) | (((x) & 0xE000) >> (16-3-2)) | (((x) & 0xC0) >> (8-2)) )
#endif

#if BPP == 16
typedef uint16_t pixel_t;
#define RGB2PIXEL(x) ( (((x) & 0xF80000) >> (24-5-11)) | (((x) & 0xFC00) >> (16-6-5)) | (((x) & 0xF8) >> (8-5)) )
#endif

#if BPP == 32
typedef uint32_t pixel_t;
#define RGB2PIXEL(x) x
#endif

struct compositing_line
{
   struct compositing_line *next; // 32-bit continuation of the same structure, NULL if no more
   int16_t x; // where to start on screen (can be negative)
   uint16_t n; // number of pixels -1 contained here (0: 1 pixel)
   // pixels can be multiple of 4 (n lower 2 bits discarded)
   // for 8bpp minimum is 4 pixels
   pixel_t *bmp; // pointer to array of pixels (could be more than 1 element)
};

#endif
