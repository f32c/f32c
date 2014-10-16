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

void gc_init(void *start, void *end);

// These lock/unlock functions can be nested.
// They can be used to prevent the GC from allocating/freeing.
void gc_lock(void);
void gc_unlock(void);
bool gc_is_locked(void);

// A given port must implement gc_collect by using the other collect functions.
void gc_collect(void);
void gc_collect_start(void);
void gc_collect_root(void **ptrs, mp_uint_t len);
void gc_collect_end(void);

void *gc_alloc(mp_uint_t n_bytes, bool has_finaliser);
void gc_free(void *ptr);
mp_uint_t gc_nbytes(void *ptr);
void *gc_realloc(void *ptr, mp_uint_t n_bytes);

typedef struct _gc_info_t {
    mp_uint_t total;
    mp_uint_t used;
    mp_uint_t free;
    mp_uint_t num_1block;
    mp_uint_t num_2block;
    mp_uint_t max_block;
} gc_info_t;

void gc_info(gc_info_t *info);
void gc_dump_info(void);
void gc_dump_alloc_table(void);
