#ifndef CORE_H
#define CORE_H

#include "hls_video.h"
#include "ap_fixed.h"
#define IMG_WIDTH_OR_COLS 320
#define IMG_HEIGHT_OR_ROWS 240

#define KERNEL_DIM 3

#define INPUT_IMAGE_CORE "image_320X240.bmp"
#define OUTPUT_IMAGE_CORE "image_320X240_filter.bmp"

// use the axi-stream side channel
#include <ap_axi_sdata.h>
typedef ap_axiu<8,2,5,6> uint8_sidechannel;
typedef ap_axiu<32,2,5,6> int32_sidechannel;

// AXI stream types for image I/O
typedef hls::stream<ap_axiu<24,2,5,6>> AXI_IN_STREAM;
typedef hls::stream<ap_axiu<8,2,5,6>>  AXI_OUT_STREAM;

// Fixed-point types for the anisotropic diffusion exponential table
typedef float fixed_exp;
typedef float fixed_exp_sum;

// Gray image type alias
typedef hls::Mat<IMG_HEIGHT_OR_ROWS, IMG_WIDTH_OR_COLS, HLS_8UC1> GRAY_IMAGE;

short sumWindow(hls::Window<KERNEL_DIM,KERNEL_DIM,short> *window);
unsigned int CEIL(unsigned int value);

void anisotropic_diffusion(GRAY_IMAGE& img_in, GRAY_IMAGE& img_out, const fixed_exp expArray5[]);

#endif // CORE_H




