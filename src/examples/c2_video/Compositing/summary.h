#ifndef SUMMARY_H
#define SUMMARY_H

// struct used for debugging
struct summary
{
  uint32_t total_scanlines,
           total_compositing_lines,
           total_pixels,
           min_scanline, // line with minimal number of pixels
           min_scanline_pixels, // min pixel count in line
           max_scanline, // line with maximal number of pixels
           max_scanline_pixels; // max pixel count in line
};

#endif // SUMMARY_H
