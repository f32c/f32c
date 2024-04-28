#ifndef SUMMARY_H
#define SUMMARY_H

// struct used for debugging
struct summary
{
  uint32_t total_scanlines,
           total_c2lines,
           total_pixels,
           min_scanline_c2lines, // line with minimal number of pixels
           min_scanline_c2lines_count, // min pixel count in line
           max_scanline_c2lines, // line with maximal number of pixels
           max_scanline_c2lines_count, // max pixel count in line
           min_scanline_pixels, // line with minimal count of compositing lines
           min_scanline_pixels_count, // min compositing lines count in line
           max_scanline_pixels, // line with maximal count of compositing lines
           max_scanline_pixels_count; // max compositing lines count in line
};

#endif // SUMMARY_H
