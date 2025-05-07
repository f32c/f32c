/*-
 * Copyright (c) 2013, 2014 Marko Zec
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
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <fatfs/ff.h>
#include <fatfs/diskio.h>


static struct diskio_inst *diskio[FF_VOLUMES];


void
diskio_attach_generic(diskio_t di)
{
	int i;

	for (i = 0; i < FF_VOLUMES; i++) {
		if (diskio[i] != NULL)
			continue;
		diskio[i] = di;
		return;
	}
}


DSTATUS
disk_initialize(BYTE drive)
{
	diskio_t di = diskio[drive];

	if (di == NULL)
		return STA_NOINIT;
	return di->d_sw->init(di);
}


DSTATUS
disk_status(BYTE drive)
{
	diskio_t di = diskio[drive];

	if (di == NULL)
		return STA_NOINIT;
	return di->d_sw->status(di);
}


DRESULT
disk_read(BYTE drive, BYTE* buf, LBA_t sector, UINT count)
{
	diskio_t di = diskio[drive];

	if (di == NULL)
		return STA_NOINIT;
	return di->d_sw->read(di, buf, sector, count);
}


DRESULT
disk_write(BYTE drive, const BYTE* buf, LBA_t sector, UINT count)
{
	diskio_t di = diskio[drive];

	if (di == NULL)
		return STA_NOINIT;
	return di->d_sw->write(di, buf, sector, count);
}


DRESULT
disk_ioctl(BYTE drive, BYTE cmd, void* buf)
{
	diskio_t di = diskio[drive];

	if (di == NULL)
		return STA_NOINIT;
	return di->d_sw->ioctl(di, cmd, buf);
}


DWORD
get_fattime(void)
{
	time_t t;
	struct tm tm;
	DWORD res;

	t = time(NULL);
	gmtime_r(&t, &tm);

	res = (tm.tm_year - 80) << 25 | (tm.tm_mon + 1) << 21
	    | tm.tm_mday << 16 | tm.tm_hour << 11
	    | tm.tm_min << 5 | tm.tm_sec >> 1;

	return (res);
}


char *
diskio_devstr(const char *descr, int port, int slave, int offset)
{
	char buf[128];
	char *res;
	int len;

	len = sprintf(buf, "%s(%d,%d)", descr, port, slave);
	if (offset)
		len += sprintf(&buf[len], "+%dK", offset / 1024);
	res = malloc(len + 1);
	if (res != NULL)
		memcpy(res, buf, len + 1);
	return (res);
}
