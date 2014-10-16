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

#include <assert.h>
#include <string.h>

#include "mpconfig.h"
#include "misc.h"
#include "qstr.h"

// NOTE: we are using linear arrays to store and search for qstr's (unique strings, interned strings)
// ultimately we will replace this with a static hash table of some kind
// also probably need to include the length in the string data, to allow null bytes in the string

#if 0 // print debugging info
#define DEBUG_printf DEBUG_printf
#else // don't print debugging info
#define DEBUG_printf(...) (void)0
#endif

// A qstr is an index into the qstr pool.
// The data for a qstr contains (hash, length, data).
// For now we use very simple encoding, just to get the framework correct:
//  - hash is 2 bytes (see function below)
//  - length is 2 bytes
//  - data follows
//  - \0 terminated (for now, so they can be printed using printf)

#define Q_GET_HASH(q)   ((q)[0] | ((q)[1] << 8))
#define Q_GET_ALLOC(q)  (4 + Q_GET_LENGTH(q) + 1)
#define Q_GET_LENGTH(q) ((q)[2] | ((q)[3] << 8))
#define Q_GET_DATA(q)   ((q) + 4)

// this must match the equivalent function in makeqstrdata.py
mp_uint_t qstr_compute_hash(const byte *data, mp_uint_t len) {
    // djb2 algorithm; see http://www.cse.yorku.ca/~oz/hash.html
    mp_uint_t hash = 5381;
    for (const byte *top = data + len; data < top; data++) {
        hash = ((hash << 5) + hash) ^ (*data); // hash * 33 ^ data
    }
    hash &= 0xffff;
    // Make sure that valid hash is never zero, zero means "hash not computed"
    if (hash == 0) {
        hash++;
    }
    return hash;
}

typedef struct _qstr_pool_t {
    struct _qstr_pool_t *prev;
    mp_uint_t total_prev_len;
    mp_uint_t alloc;
    mp_uint_t len;
    const byte *qstrs[];
} qstr_pool_t;

STATIC const qstr_pool_t const_pool = {
    NULL,               // no previous pool
    0,                  // no previous pool
    10,                 // set so that the first dynamically allocated pool is twice this size; must be <= the len (just below)
    MP_QSTR_number_of,  // corresponds to number of strings in array just below
    {
        (const byte*) "\0\0\0\0", // invalid/no qstr has empty data
        (const byte*) "\0\0\0\0", // empty qstr
#define Q(id, str) str,
#include "genhdr/qstrdefs.generated.h"
#undef Q
    },
};

STATIC qstr_pool_t *last_pool;

void qstr_init(void) {
    last_pool = (qstr_pool_t*)&const_pool; // we won't modify the const_pool since it has no allocated room left
}

STATIC const byte *find_qstr(qstr q) {
    // search pool for this qstr
    for (qstr_pool_t *pool = last_pool; pool != NULL; pool = pool->prev) {
        if (q >= pool->total_prev_len) {
            return pool->qstrs[q - pool->total_prev_len];
        }
    }

    // not found
    return 0;
}

STATIC qstr qstr_add(const byte *q_ptr) {
    DEBUG_printf("QSTR: add hash=%d len=%d data=%.*s\n", Q_GET_HASH(q_ptr), Q_GET_LENGTH(q_ptr), Q_GET_LENGTH(q_ptr), Q_GET_DATA(q_ptr));

    // make sure we have room in the pool for a new qstr
    if (last_pool->len >= last_pool->alloc) {
        qstr_pool_t *pool = m_new_obj_var(qstr_pool_t, const char*, last_pool->alloc * 2);
        pool->prev = last_pool;
        pool->total_prev_len = last_pool->total_prev_len + last_pool->len;
        pool->alloc = last_pool->alloc * 2;
        pool->len = 0;
        last_pool = pool;
        DEBUG_printf("QSTR: allocate new pool of size %d\n", last_pool->alloc);
    }

    // add the new qstr
    last_pool->qstrs[last_pool->len++] = q_ptr;

    // return id for the newly-added qstr
    return last_pool->total_prev_len + last_pool->len - 1;
}

qstr qstr_find_strn(const char *str, mp_uint_t str_len) {
    // work out hash of str
    mp_uint_t str_hash = qstr_compute_hash((const byte*)str, str_len);

    // search pools for the data
    for (qstr_pool_t *pool = last_pool; pool != NULL; pool = pool->prev) {
        for (const byte **q = pool->qstrs, **q_top = pool->qstrs + pool->len; q < q_top; q++) {
            if (Q_GET_HASH(*q) == str_hash && Q_GET_LENGTH(*q) == str_len && memcmp(Q_GET_DATA(*q), str, str_len) == 0) {
                return pool->total_prev_len + (q - pool->qstrs);
            }
        }
    }

    // not found; return null qstr
    return 0;
}

qstr qstr_from_str(const char *str) {
    return qstr_from_strn(str, strlen(str));
}

qstr qstr_from_strn(const char *str, mp_uint_t len) {
    qstr q = qstr_find_strn(str, len);
    if (q == 0) {
        mp_uint_t hash = qstr_compute_hash((const byte*)str, len);
        byte *q_ptr = m_new(byte, 4 + len + 1);
        q_ptr[0] = hash;
        q_ptr[1] = hash >> 8;
        q_ptr[2] = len;
        q_ptr[3] = len >> 8;
        memcpy(q_ptr + 4, str, len);
        q_ptr[4 + len] = '\0';
        q = qstr_add(q_ptr);
    }
    return q;
}

byte *qstr_build_start(mp_uint_t len, byte **q_ptr) {
    assert(len <= 65535);
    *q_ptr = m_new(byte, 4 + len + 1);
    (*q_ptr)[2] = len;
    (*q_ptr)[3] = len >> 8;
    return Q_GET_DATA(*q_ptr);
}

qstr qstr_build_end(byte *q_ptr) {
    qstr q = qstr_find_strn((const char*)Q_GET_DATA(q_ptr), Q_GET_LENGTH(q_ptr));
    if (q == 0) {
        mp_uint_t len = Q_GET_LENGTH(q_ptr);
        mp_uint_t hash = qstr_compute_hash(Q_GET_DATA(q_ptr), len);
        q_ptr[0] = hash;
        q_ptr[1] = hash >> 8;
        q_ptr[4 + len] = '\0';
        q = qstr_add(q_ptr);
    } else {
        m_del(byte, q_ptr, Q_GET_ALLOC(q_ptr));
    }
    return q;
}

mp_uint_t qstr_hash(qstr q) {
    return Q_GET_HASH(find_qstr(q));
}

mp_uint_t qstr_len(qstr q) {
    const byte *qd = find_qstr(q);
    return Q_GET_LENGTH(qd);
}

// XXX to remove!
const char *qstr_str(qstr q) {
    const byte *qd = find_qstr(q);
    return (const char*)Q_GET_DATA(qd);
}

const byte *qstr_data(qstr q, mp_uint_t *len) {
    const byte *qd = find_qstr(q);
    *len = Q_GET_LENGTH(qd);
    return Q_GET_DATA(qd);
}

void qstr_pool_info(mp_uint_t *n_pool, mp_uint_t *n_qstr, mp_uint_t *n_str_data_bytes, mp_uint_t *n_total_bytes) {
    *n_pool = 0;
    *n_qstr = 0;
    *n_str_data_bytes = 0;
    *n_total_bytes = 0;
    for (qstr_pool_t *pool = last_pool; pool != NULL && pool != &const_pool; pool = pool->prev) {
        *n_pool += 1;
        *n_qstr += pool->len;
        for (const byte **q = pool->qstrs, **q_top = pool->qstrs + pool->len; q < q_top; q++) {
            *n_str_data_bytes += Q_GET_ALLOC(*q);
        }
        *n_total_bytes += sizeof(qstr_pool_t) + sizeof(qstr) * pool->alloc;
    }
    *n_total_bytes += *n_str_data_bytes;
}
