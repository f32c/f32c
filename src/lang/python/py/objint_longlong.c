/*
 * This file is part of the Micro Python project, http://micropython.org/
 *
 * The MIT License (MIT)
 *
 * Copyright (c) 2013, 2014 Damien P. George
 * Copyright (c) 2014 Paul Sokolovsky
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

#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "smallint.h"
#include "mpz.h"
#include "objint.h"
#include "runtime0.h"
#include "runtime.h"

#if MICROPY_LONGINT_IMPL == MICROPY_LONGINT_IMPL_LONGLONG

// Python3 no longer has "l" suffix for long ints. We allow to use it
// for debugging purpose though.
#ifdef DEBUG
#define SUFFIX "l"
#else
#define SUFFIX ""
#endif

#if MICROPY_PY_SYS_MAXSIZE
// Export value for sys.maxsize
const mp_obj_int_t mp_maxsize_obj = {{&mp_type_int}, MP_SSIZE_MAX};
#endif

mp_int_t mp_obj_int_hash(mp_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in);
    }
    mp_obj_int_t *self = self_in;
    // truncate value to fit in mp_int_t, which gives the same hash as
    // small int if the value fits without truncation
    return self->val;
}

bool mp_obj_int_is_positive(mp_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in) >= 0;
    }
    mp_obj_int_t *self = self_in;
    return self->val >= 0;
}

mp_obj_t mp_obj_int_unary_op(mp_uint_t op, mp_obj_t o_in) {
    mp_obj_int_t *o = o_in;
    switch (op) {
        case MP_UNARY_OP_BOOL: return MP_BOOL(o->val != 0);
        case MP_UNARY_OP_POSITIVE: return o_in;
        case MP_UNARY_OP_NEGATIVE: return mp_obj_new_int_from_ll(-o->val);
        case MP_UNARY_OP_INVERT: return mp_obj_new_int_from_ll(~o->val);
        default: return MP_OBJ_NULL; // op not supported
    }
}

mp_obj_t mp_obj_int_binary_op(mp_uint_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    long long lhs_val;
    long long rhs_val;

    if (MP_OBJ_IS_SMALL_INT(lhs_in)) {
        lhs_val = MP_OBJ_SMALL_INT_VALUE(lhs_in);
    } else if (MP_OBJ_IS_TYPE(lhs_in, &mp_type_int)) {
        lhs_val = ((mp_obj_int_t*)lhs_in)->val;
    } else {
        return MP_OBJ_NULL; // op not supported
    }

    if (MP_OBJ_IS_SMALL_INT(rhs_in)) {
        rhs_val = MP_OBJ_SMALL_INT_VALUE(rhs_in);
    } else if (MP_OBJ_IS_TYPE(rhs_in, &mp_type_int)) {
        rhs_val = ((mp_obj_int_t*)rhs_in)->val;
    } else {
        // delegate to generic function to check for extra cases
        return mp_obj_int_binary_op_extra_cases(op, lhs_in, rhs_in);
    }

    switch (op) {
        case MP_BINARY_OP_ADD:
        case MP_BINARY_OP_INPLACE_ADD:
            return mp_obj_new_int_from_ll(lhs_val + rhs_val);
        case MP_BINARY_OP_SUBTRACT:
        case MP_BINARY_OP_INPLACE_SUBTRACT:
            return mp_obj_new_int_from_ll(lhs_val - rhs_val);
        case MP_BINARY_OP_MULTIPLY:
        case MP_BINARY_OP_INPLACE_MULTIPLY:
            return mp_obj_new_int_from_ll(lhs_val * rhs_val);
        case MP_BINARY_OP_FLOOR_DIVIDE:
        case MP_BINARY_OP_INPLACE_FLOOR_DIVIDE:
            return mp_obj_new_int_from_ll(lhs_val / rhs_val);
        case MP_BINARY_OP_MODULO:
        case MP_BINARY_OP_INPLACE_MODULO:
            return mp_obj_new_int_from_ll(lhs_val % rhs_val);

        case MP_BINARY_OP_AND:
        case MP_BINARY_OP_INPLACE_AND:
            return mp_obj_new_int_from_ll(lhs_val & rhs_val);
        case MP_BINARY_OP_OR:
        case MP_BINARY_OP_INPLACE_OR:
            return mp_obj_new_int_from_ll(lhs_val | rhs_val);
        case MP_BINARY_OP_XOR:
        case MP_BINARY_OP_INPLACE_XOR:
            return mp_obj_new_int_from_ll(lhs_val ^ rhs_val);

        case MP_BINARY_OP_LSHIFT:
        case MP_BINARY_OP_INPLACE_LSHIFT:
            return mp_obj_new_int_from_ll(lhs_val << (int)rhs_val);
        case MP_BINARY_OP_RSHIFT:
        case MP_BINARY_OP_INPLACE_RSHIFT:
            return mp_obj_new_int_from_ll(lhs_val >> (int)rhs_val);

        case MP_BINARY_OP_LESS:
            return MP_BOOL(lhs_val < rhs_val);
        case MP_BINARY_OP_MORE:
            return MP_BOOL(lhs_val > rhs_val);
        case MP_BINARY_OP_LESS_EQUAL:
            return MP_BOOL(lhs_val <= rhs_val);
        case MP_BINARY_OP_MORE_EQUAL:
            return MP_BOOL(lhs_val >= rhs_val);
        case MP_BINARY_OP_EQUAL:
            return MP_BOOL(lhs_val == rhs_val);

        default:
            return MP_OBJ_NULL; // op not supported
    }
}

mp_obj_t mp_obj_new_int(mp_int_t value) {
    if (MP_SMALL_INT_FITS(value)) {
        return MP_OBJ_NEW_SMALL_INT(value);
    }
    return mp_obj_new_int_from_ll(value);
}

mp_obj_t mp_obj_new_int_from_uint(mp_uint_t value) {
    // SMALL_INT accepts only signed numbers, of one bit less size
    // than word size, which totals 2 bits less for unsigned numbers.
    if ((value & (WORD_MSBIT_HIGH | (WORD_MSBIT_HIGH >> 1))) == 0) {
        return MP_OBJ_NEW_SMALL_INT(value);
    }
    return mp_obj_new_int_from_ll(value);
}

mp_obj_t mp_obj_new_int_from_ll(long long val) {
    mp_obj_int_t *o = m_new_obj(mp_obj_int_t);
    o->base.type = &mp_type_int;
    o->val = val;
    return o;
}

mp_obj_t mp_obj_new_int_from_ull(unsigned long long val) {
    // TODO raise an exception if the unsigned long long won't fit
    assert(val >> (sizeof(unsigned long long) * 8 - 1) == 0);
    mp_obj_int_t *o = m_new_obj(mp_obj_int_t);
    o->base.type = &mp_type_int;
    o->val = val;
    return o;
}

mp_obj_t mp_obj_new_int_from_str_len(const char **str, mp_uint_t len, bool neg, mp_uint_t base) {
    // TODO this does not honor the given length of the string, but it all cases it should anyway be null terminated
    // TODO check overflow
    mp_obj_int_t *o = m_new_obj(mp_obj_int_t);
    o->base.type = &mp_type_int;
    char *endptr;
    o->val = strtoll(*str, &endptr, base);
    *str = endptr;
    return o;
}

mp_int_t mp_obj_int_get(mp_const_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in);
    } else {
        const mp_obj_int_t *self = self_in;
        return self->val;
    }
}

mp_int_t mp_obj_int_get_checked(mp_const_obj_t self_in) {
    // TODO: Check overflow
    return mp_obj_int_get(self_in);
}

#if MICROPY_PY_BUILTINS_FLOAT
mp_float_t mp_obj_int_as_float(mp_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in);
    } else {
        mp_obj_int_t *self = self_in;
        return self->val;
    }
}
#endif

#endif
