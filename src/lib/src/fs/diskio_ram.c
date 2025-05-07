/*-
 * Copyright (c) 2013-2024 Marko Zec
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <stdio.h>
#include <time.h>

#include <fatfs/ff.h>
#include <fatfs/diskio.h>


static DRESULT ramdisk_read(diskio_t, BYTE *, LBA_t, UINT);
static DRESULT ramdisk_write(diskio_t, const BYTE *, LBA_t, UINT);
static DRESULT ramdisk_ioctl(diskio_t, BYTE, void *);
static DSTATUS ramdisk_init_status(diskio_t);

static struct diskio_sw ramdisk_sw = {
        .read	= ramdisk_read,
        .write	= ramdisk_write,
        .ioctl	= ramdisk_ioctl,
        .status	= ramdisk_init_status,
        .init	= ramdisk_init_status
};

struct ramdisk_priv {
	void		*base;
	uint32_t	size;
};

#define	RAM_BASE(d)	((struct ramdisk_priv *) DISKIO2PRIV(d))->base
#define	RAM_SIZE(d)	((struct ramdisk_priv *) DISKIO2PRIV(d))->size

#define	RAMDISK_SS	512


static void
ram_cpy(void *dst, const void *src, int seccnt)
{
	const uint32_t *r = src;
	uint32_t *w = dst;
	int cnt = seccnt * RAMDISK_SS / 4 / 4;
	uint32_t a, b, c, d;

	do {
		a = r[0]; b = r[1]; c = r[2]; d = r[3];
		r = &r[4];
		w[0] = a; w[1] = b; w[2] = c; w[3] = d;
		w = &w[4];
	} while (--cnt != 0);
}


static DSTATUS
ramdisk_init_status(diskio_t di)
{

	if (RAM_BASE(di) == NULL || RAM_SIZE(di) == 0)
		return STA_NOINIT;
	return 0;
}


static DRESULT
ramdisk_read(diskio_t di, BYTE *buf, LBA_t sector, UINT count)
{
	char *ramdisk = RAM_BASE(di);

	ram_cpy(buf, &ramdisk[sector * RAMDISK_SS], count);
	return RES_OK;
}


static DRESULT
ramdisk_write(diskio_t di, const BYTE *buf, LBA_t sector, UINT count)
{
	char *ramdisk = RAM_BASE(di);

	ram_cpy(&ramdisk[sector * RAMDISK_SS], buf, count);
	return RES_OK;
}


static DRESULT
ramdisk_ioctl(diskio_t di, BYTE cmd, void *buf)
{
	WORD *up = buf;

	switch (cmd) {
	case GET_SECTOR_SIZE:
		*up = RAMDISK_SS;
		return (RES_OK);
#ifndef DISKIO_RO
	case GET_SECTOR_COUNT:
		*up = RAM_SIZE(di) / RAMDISK_SS;
		return (RES_OK);
	case GET_BLOCK_SIZE:
		*up = 1;
		return (RES_OK);
#endif /* !DISKIO_RO */
	case CTRL_SYNC:
		return (RES_OK);
	default:
		return (RES_ERROR);
	}
}


void
diskio_attach_ram(diskio_t di, void *base, uint32_t size)
{
	struct ramdisk_priv *priv = DISKIO2PRIV(di);

	di->d_sw = &ramdisk_sw;
	di->d_mntfrom = "RAM";
	priv->base = base;
	priv->size = size;
	diskio_attach_generic(di);
}
