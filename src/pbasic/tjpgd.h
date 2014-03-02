/*----------------------------------------------------------------------------/
/ TJpgDec - Tiny JPEG Decompressor include file               (C)ChaN, 2012
/----------------------------------------------------------------------------*/
#ifndef _TJPGDEC
#define _TJPGDEC
/*---------------------------------------------------------------------------*/
/* System Configurations */

#define	JD_FMT_RGB24	0	/* RGB888, 3 bytes / pixel */
#define	JD_FMT_RGB16	1	/* RGB565, 2 bytes / pixel */
#define	JD_FMT_RGB32	2	/* RGB888 word-aligned, 4 bytes / pixel */

//#define JD_FORMAT	JD_FMT_RGB32
#define JD_FORMAT	JD_FMT_RGB24

#define	JD_SZBUF	4096	/* Size of stream input buffer */
#define	JD_USE_SCALE	1	/* Use descaling feature for output */
#define JD_TBLCLIP	1	/* Use table for saturation (might be a bit faster but increases 1K bytes of code size) */

/*---------------------------------------------------------------------------*/

#ifdef __cplusplus
extern "C" {
#endif


#ifdef _WIN32	/* FatFs development platform */

#include <windows.h>
#include <tchar.h>

#else			/* Embedded platform */

/* These types must be 16-bit, 32-bit or larger integer */
typedef int32_t		INT;
typedef uint32_t	UINT;

/* These types must be 8-bit integer */
//typedef char		CHAR;
typedef unsigned char	UCHAR;
typedef unsigned char	BYTE;

/* These types must be 16-bit integer */
typedef short		SHORT;
typedef unsigned short	USHORT;
typedef unsigned short	WORD;
typedef unsigned short	WCHAR;

/* These types must be 32-bit integer */
typedef int32_t		LONG;
typedef uint32_t	ULONG;
typedef uint32_t	DWORD;

#endif


/* Error code */
typedef enum {
	JDR_OK = 0,	/* 0: Succeeded */
	JDR_INTR,	/* 1: Interrupted by output function */	
	JDR_INP,	/* 2: Device error or wrong termination of input stream */
	JDR_MEM1,	/* 3: Insufficient memory pool for the image */
	JDR_MEM2,	/* 4: Insufficient stream input buffer */
	JDR_PAR,	/* 5: Parameter error */
	JDR_FMT1,	/* 6: Data format error (may be damaged data) */
	JDR_FMT2,	/* 7: Right format but not supported */
	JDR_FMT3	/* 8: Not supported JPEG standard */
} JRESULT;



/* Rectangular structure */
typedef struct {
	WORD left, right, top, bottom;
} JRECT;



/* Decompressor object structure */
typedef struct JDEC JDEC;
struct JDEC {
	UINT dctr;		/* Number of bytes available in the input buffer */
	BYTE* dptr;		/* Current data read ptr */
	BYTE* inbuf;		/* Bit stream input buffer */
	BYTE dmsk;		/* Current bit in the current read byte */
	BYTE scale;		/* Output scaling ratio */
	BYTE msx, msy;		/* MCU size in unit of block (width, height) */
	BYTE qtid[3];		/* Quantization table ID of each component */
	SHORT dcv[3];		/* Previous DC element of each component */
	WORD nrst;		/* Restart inverval */
	UINT width, height;	/* Size of the input image (pixel) */
	BYTE* huffbits[2][2];	/* Huffman bit distribution tables [id][dcac] */
	WORD* huffcode[2][2];	/* Huffman code word tables [id][dcac] */
	BYTE* huffdata[2][2];	/* Huffman decoded data tables [id][dcac] */
	LONG* qttbl[4];		/* Dequaitizer tables [id] */
	void* workbuf;		/* Working buffer for IDCT and RGB output */
	BYTE* mcubuf;		/* Working buffer for the MCU */
	void* pool;		/* Pointer to available memory pool */
	UINT sz_pool;		/* Size of memory pool (bytes available) */
	UINT (*infunc)(JDEC*, BYTE*, UINT);/* Pointer to jpeg stream input function */
	void* device;		/* Pointer to I/O device identifiler for the session */
};



/* TJpgDec API functions */
JRESULT jd_prepare (JDEC*, UINT(*)(JDEC*,BYTE*,UINT), void*, UINT, void*);
JRESULT jd_decomp (JDEC*, UINT(*)(JDEC*,void*,JRECT*), BYTE);


#ifdef __cplusplus
}
#endif

#endif /* _TJPGDEC */
