/*-
 * Copyright (c) 2024 Marko Zec
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
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS_FILE_H_
#define _SYS_FILE_H_

/* fileops types */
typedef int fo_read_t(struct file *fp, void *buf, size_t nbytes);
typedef int fo_write_t(struct file *fp, const void *buf, size_t nbytes);
typedef int fo_lseek_t(struct file *fp, off_t offset, int whence);
typedef int fo_fcntl_t(struct file *fp, int cmd, void *data);
typedef int fo_ftruncate_t(struct file *fp, off_t length);
typedef int fo_fstat_t(struct file *fp, void *data);
typedef int fo_close_t(struct file *fp);

struct fileops {
	fo_read_t	*fo_read;
	fo_write_t	*fo_write;
	fo_lseek_t	*fo_lseek;
	fo_fcntl_t	*fo_fcntl;
	fo_ftruncate_t	*fo_ftruncate;
	fo_fstat_t	*fo_fstat;
	fo_close_t	*fo_close;
};

struct file {
	struct fileops	*f_ops;		/* file operations */
	void		*f_priv;	/* file descriptor specific data */
	uint16_t	f_mflags;	/* malloc flags */
	volatile uint16_t f_refc;	/* reference count */
	volatile uint16_t f_flags;	/* see fcntl.h */
}; 

#define	F_MF_FILE_MALLOCED	0x0001
#define	F_MF_PRIV_MALLOCED	0x0002

#endif /* _SYS_FILE_H_ */
