/*
 * This file is part of the Micro Python project, http://micropython.org/
 *
 * The MIT License (MIT)
 *
 * Copyright (c) 2013, 2014 Damien P. George
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include <stdbool.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>
#include "mpconfig.h"
#include "misc.h"

// returned value is always at least 1 greater than argument
#define ROUND_ALLOC(a) (((a) & ((~0) - 7)) + 8)

void vstr_init(vstr_t *vstr, size_t alloc) {
    if (alloc < 2) {
        // need at least 1 byte for the null byte at the end
        alloc = 2;
    }
    vstr->alloc = alloc;
    vstr->len = 0;
    vstr->buf = m_new(char, vstr->alloc);
    if (vstr->buf == NULL) {
        vstr->had_error = true;
        return;
    }
    vstr->buf[0] = 0;
    vstr->had_error = false;
    vstr->fixed_buf = false;
}

void vstr_init_fixed_buf(vstr_t *vstr, size_t alloc, char *buf) {
    assert(alloc > 0); // need at least room for the null byte
    vstr->alloc = alloc;
    vstr->len = 0;
    vstr->buf = buf;
    vstr->buf[0] = 0;
    vstr->had_error = false;
    vstr->fixed_buf = true;
}

void vstr_clear(vstr_t *vstr) {
    if (!vstr->fixed_buf) {
        m_del(char, vstr->buf, vstr->alloc);
    }
    vstr->buf = NULL;
}

vstr_t *vstr_new(void) {
    vstr_t *vstr = m_new(vstr_t, 1);
    if (vstr == NULL) {
        return NULL;
    }
    vstr_init(vstr, 32);
    return vstr;
}

vstr_t *vstr_new_size(size_t alloc) {
    vstr_t *vstr = m_new(vstr_t, 1);
    if (vstr == NULL) {
        return NULL;
    }
    vstr_init(vstr, alloc);
    return vstr;
}

void vstr_free(vstr_t *vstr) {
    if (vstr != NULL) {
        if (!vstr->fixed_buf) {
            m_del(char, vstr->buf, vstr->alloc);
        }
        m_del_obj(vstr_t, vstr);
    }
}

void vstr_reset(vstr_t *vstr) {
    vstr->len = 0;
    vstr->buf[0] = 0;
    vstr->had_error = false;
}

bool vstr_had_error(vstr_t *vstr) {
    return vstr->had_error;
}

char *vstr_str(vstr_t *vstr) {
    if (vstr->had_error) {
        return NULL;
    }
    return vstr->buf;
}

size_t vstr_len(vstr_t *vstr) {
    if (vstr->had_error) {
        return 0;
    }
    return vstr->len;
}

// Extend vstr strictly by requested size, return pointer to newly added chunk
char *vstr_extend(vstr_t *vstr, size_t size) {
    if (vstr->fixed_buf) {
        return NULL;
    }
    char *new_buf = m_renew(char, vstr->buf, vstr->alloc, vstr->alloc + size);
    if (new_buf == NULL) {
        vstr->had_error = true;
        return NULL;
    }
    char *p = new_buf + vstr->alloc;
    vstr->alloc += size;
    vstr->buf = new_buf;
    return p;
}

// Shrink vstr to be given size
bool vstr_set_size(vstr_t *vstr, size_t size) {
    if (vstr->fixed_buf) {
        return false;
    }
    char *new_buf = m_renew(char, vstr->buf, vstr->alloc, size);
    if (new_buf == NULL) {
        vstr->had_error = true;
        return false;
    }
    vstr->buf = new_buf;
    vstr->alloc = vstr->len = size;
    return true;
}

// Shrink vstr allocation to its actual length
bool vstr_shrink(vstr_t *vstr) {
    return vstr_set_size(vstr, vstr->len);
}

STATIC bool vstr_ensure_extra(vstr_t *vstr, size_t size) {
    if (vstr->len + size + 1 > vstr->alloc) {
        if (vstr->fixed_buf) {
            return false;
        }
        size_t new_alloc = ROUND_ALLOC((vstr->len + size + 1) * 2);
        char *new_buf = m_renew(char, vstr->buf, vstr->alloc, new_alloc);
        if (new_buf == NULL) {
            vstr->had_error = true;
            return false;
        }
        vstr->alloc = new_alloc;
        vstr->buf = new_buf;
    }
    return true;
}

void vstr_hint_size(vstr_t *vstr, size_t size) {
    // it's not an error if we fail to allocate for the size hint
    bool er = vstr->had_error;
    vstr_ensure_extra(vstr, size);
    vstr->had_error = er;
}

char *vstr_add_len(vstr_t *vstr, size_t len) {
    if (vstr->had_error || !vstr_ensure_extra(vstr, len)) {
        return NULL;
    }
    char *buf = vstr->buf + vstr->len;
    vstr->len += len;
    vstr->buf[vstr->len] = 0;
    return buf;
}

void vstr_add_byte(vstr_t *vstr, byte b) {
    byte *buf = (byte*)vstr_add_len(vstr, 1);
    if (buf == NULL) {
        return;
    }
    buf[0] = b;
}

void vstr_add_char(vstr_t *vstr, unichar c) {
#if MICROPY_PY_BUILTINS_STR_UNICODE
    // TODO: Can this be simplified and deduplicated?
    // Is it worth just calling vstr_add_len(vstr, 4)?
    if (c < 0x80) {
        byte *buf = (byte*)vstr_add_len(vstr, 1);
        if (buf == NULL) {
            return;
        }
        *buf = (byte)c;
    } else if (c < 0x800) {
        byte *buf = (byte*)vstr_add_len(vstr, 2);
        if (buf == NULL) {
            return;
        }
        buf[0] = (c >> 6) | 0xC0;
        buf[1] = (c & 0x3F) | 0x80;
    } else if (c < 0x10000) {
        byte *buf = (byte*)vstr_add_len(vstr, 3);
        if (buf == NULL) {
            return;
        }
        buf[0] = (c >> 12) | 0xE0;
        buf[1] = ((c >> 6) & 0x3F) | 0x80;
        buf[2] = (c & 0x3F) | 0x80;
    } else {
        assert(c < 0x110000);
        byte *buf = (byte*)vstr_add_len(vstr, 4);
        if (buf == NULL) {
            return;
        }
        buf[0] = (c >> 18) | 0xF0;
        buf[1] = ((c >> 12) & 0x3F) | 0x80;
        buf[2] = ((c >> 6) & 0x3F) | 0x80;
        buf[3] = (c & 0x3F) | 0x80;
    }
#else
    byte *buf = (byte*)vstr_add_len(vstr, 1);
    if (buf == NULL) {
        return;
    }
    buf[0] = c;
#endif
}

void vstr_add_str(vstr_t *vstr, const char *str) {
    vstr_add_strn(vstr, str, strlen(str));
}

void vstr_add_strn(vstr_t *vstr, const char *str, size_t len) {
    if (vstr->had_error || !vstr_ensure_extra(vstr, len)) {
        // if buf is fixed, we got here because there isn't enough room left
        // so just try to copy as much as we can, with room for null byte
        if (vstr->fixed_buf && vstr->len + 1 < vstr->alloc) {
            len = vstr->alloc - vstr->len - 1;
            goto copy;
        }
        return;
    }
copy:
    memmove(vstr->buf + vstr->len, str, len);
    vstr->len += len;
    vstr->buf[vstr->len] = 0;
}

char *vstr_ins_blank_bytes(vstr_t *vstr, size_t byte_pos, size_t byte_len) {
    if (vstr->had_error) {
        return NULL;
    }
    size_t l = vstr->len;
    if (byte_pos > l) {
        byte_pos = l;
    }
    if (byte_len > 0) {
        // ensure room for the new bytes
        if (!vstr_ensure_extra(vstr, byte_len)) {
            return NULL;
        }
        // copy up the string to make room for the new bytes; +1 for the null byte
        memmove(vstr->buf + byte_pos + byte_len, vstr->buf + byte_pos, l - byte_pos + 1);
        // increase the length
        vstr->len += byte_len;
    }
    return vstr->buf + byte_pos;
}

void vstr_ins_byte(vstr_t *vstr, size_t byte_pos, byte b) {
    char *s = vstr_ins_blank_bytes(vstr, byte_pos, 1);
    if (s != NULL) {
        *s = b;
    }
}

void vstr_ins_char(vstr_t *vstr, size_t char_pos, unichar chr) {
    // TODO UNICODE
    char *s = vstr_ins_blank_bytes(vstr, char_pos, 1);
    if (s != NULL) {
        *s = chr;
    }
}

void vstr_cut_head_bytes(vstr_t *vstr, size_t bytes_to_cut) {
    vstr_cut_out_bytes(vstr, 0, bytes_to_cut);
}

void vstr_cut_tail_bytes(vstr_t *vstr, size_t len) {
    if (vstr->had_error) {
        return;
    }
    if (len > vstr->len) {
        vstr->len = 0;
    } else {
        vstr->len -= len;
    }
    vstr->buf[vstr->len] = 0;
}

void vstr_cut_out_bytes(vstr_t *vstr, size_t byte_pos, size_t bytes_to_cut) {
    if (vstr->had_error || byte_pos >= vstr->len) {
        return;
    } else if (byte_pos + bytes_to_cut >= vstr->len) {
        vstr->len = byte_pos;
        vstr->buf[vstr->len] = 0;
    } else {
        // move includes +1 for null byte at the end
        memmove(vstr->buf + byte_pos, vstr->buf + byte_pos + bytes_to_cut, vstr->len - byte_pos - bytes_to_cut + 1);
        vstr->len -= bytes_to_cut;
    }
}

void vstr_printf(vstr_t *vstr, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vstr_vprintf(vstr, fmt, ap);
    va_end(ap);
}

void vstr_vprintf(vstr_t *vstr, const char *fmt, va_list ap) {
    if (vstr->had_error || !vstr_ensure_extra(vstr, strlen(fmt))) {
        return;
    }

    while (1) {
        // try to print in the allocated space
        // need to make a copy of the va_list because we may call vsnprintf multiple times
        size_t size = vstr->alloc - vstr->len;
        va_list ap2;
        va_copy(ap2, ap);
        int n = vsnprintf(vstr->buf + vstr->len, size, fmt, ap2);
        va_end(ap2);

        // if that worked, return
        if (n > -1 && n < size) {
            vstr->len += n;
            return;
        }

        // else try again with more space
        if (n > -1) { // glibc 2.1
            // n + 1 is precisely what is needed
            if (!vstr_ensure_extra(vstr, n + 1)) {
                return;
            }
        } else { // glibc 2.0
            // increase to twice the old size
            if (!vstr_ensure_extra(vstr, size * 2)) {
                return;
            }
        }
    }
}
