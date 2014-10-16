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

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "parsenumbase.h"
#include "obj.h"
#include "smallint.h"
#include "mpz.h"
#include "objint.h"
#include "runtime0.h"
#include "runtime.h"

#if MICROPY_LONGINT_IMPL == MICROPY_LONGINT_IMPL_MPZ

#if MICROPY_PY_SYS_MAXSIZE
// Export value for sys.maxsize
#define DIG_MASK ((1L << MPZ_DIG_SIZE) - 1)
STATIC const mpz_dig_t maxsize_dig[MPZ_NUM_DIG_FOR_INT] = {
    (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 0) & DIG_MASK,
    #if (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 0) > DIG_MASK
    (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 1) & DIG_MASK,
    #if (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 1) > DIG_MASK
    (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 2) & DIG_MASK,
    (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 3) & DIG_MASK,
    (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 4) & DIG_MASK,
//    (MP_SSIZE_MAX >> MPZ_DIG_SIZE * 5) & DIG_MASK,
    #endif
    #endif
};
const mp_obj_int_t mp_maxsize_obj = {
    {&mp_type_int},
    {.fixed_dig = 1, .len = MPZ_NUM_DIG_FOR_INT, .alloc = MPZ_NUM_DIG_FOR_INT, .dig = (mpz_dig_t*)maxsize_dig}
};
#undef DIG_MASK
#endif

STATIC mp_obj_int_t *mp_obj_int_new_mpz(void) {
    mp_obj_int_t *o = m_new_obj(mp_obj_int_t);
    o->base.type = &mp_type_int;
    mpz_init_zero(&o->mpz);
    return o;
}

// This routine expects you to pass in a buffer and size (in *buf and buf_size).
// If, for some reason, this buffer is too small, then it will allocate a
// buffer and return the allocated buffer and size in *buf and *buf_size. It
// is the callers responsibility to free this allocated buffer.
//
// The resulting formatted string will be returned from this function and the
// formatted size will be in *fmt_size.
//
// This particular routine should only be called for the mpz representation of the int.
char *mp_obj_int_formatted_impl(char **buf, mp_uint_t *buf_size, mp_uint_t *fmt_size, mp_const_obj_t self_in,
                                int base, const char *prefix, char base_char, char comma) {
    assert(MP_OBJ_IS_TYPE(self_in, &mp_type_int));
    const mp_obj_int_t *self = self_in;

    mp_uint_t needed_size = mpz_as_str_size(&self->mpz, base, prefix, comma);
    if (needed_size > *buf_size) {
        *buf = m_new(char, needed_size);
        *buf_size = needed_size;
    }
    char *str = *buf;

    *fmt_size = mpz_as_str_inpl(&self->mpz, base, prefix, base_char, comma, str);

    return str;
}

mp_int_t mp_obj_int_hash(mp_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in);
    }
    mp_obj_int_t *self = self_in;
    return mpz_hash(&self->mpz);
}

bool mp_obj_int_is_positive(mp_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in) >= 0;
    }
    mp_obj_int_t *self = self_in;
    return !self->mpz.neg;
}

mp_obj_t mp_obj_int_unary_op(mp_uint_t op, mp_obj_t o_in) {
    mp_obj_int_t *o = o_in;
    switch (op) {
        case MP_UNARY_OP_BOOL: return MP_BOOL(!mpz_is_zero(&o->mpz));
        case MP_UNARY_OP_POSITIVE: return o_in;
        case MP_UNARY_OP_NEGATIVE: { mp_obj_int_t *o2 = mp_obj_int_new_mpz(); mpz_neg_inpl(&o2->mpz, &o->mpz); return o2; }
        case MP_UNARY_OP_INVERT: { mp_obj_int_t *o2 = mp_obj_int_new_mpz(); mpz_not_inpl(&o2->mpz, &o->mpz); return o2; }
        default: return MP_OBJ_NULL; // op not supported
    }
}

mp_obj_t mp_obj_int_binary_op(mp_uint_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    const mpz_t *zlhs;
    const mpz_t *zrhs;
    mpz_t z_int;
    mpz_dig_t z_int_dig[MPZ_NUM_DIG_FOR_INT];

    // lhs could be a small int (eg small-int + mpz)
    if (MP_OBJ_IS_SMALL_INT(lhs_in)) {
        mpz_init_fixed_from_int(&z_int, z_int_dig, MPZ_NUM_DIG_FOR_INT, MP_OBJ_SMALL_INT_VALUE(lhs_in));
        zlhs = &z_int;
    } else if (MP_OBJ_IS_TYPE(lhs_in, &mp_type_int)) {
        zlhs = &((mp_obj_int_t*)lhs_in)->mpz;
    } else {
        // unsupported type
        return MP_OBJ_NULL;
    }

    // if rhs is small int, then lhs was not (otherwise mp_binary_op handles it)
    if (MP_OBJ_IS_SMALL_INT(rhs_in)) {
        mpz_init_fixed_from_int(&z_int, z_int_dig, MPZ_NUM_DIG_FOR_INT, MP_OBJ_SMALL_INT_VALUE(rhs_in));
        zrhs = &z_int;
    } else if (MP_OBJ_IS_TYPE(rhs_in, &mp_type_int)) {
        zrhs = &((mp_obj_int_t*)rhs_in)->mpz;
#if MICROPY_PY_BUILTINS_FLOAT
    } else if (MP_OBJ_IS_TYPE(rhs_in, &mp_type_float)) {
        return mp_obj_float_binary_op(op, mpz_as_float(zlhs), rhs_in);
#if MICROPY_PY_BUILTINS_COMPLEX
    } else if (MP_OBJ_IS_TYPE(rhs_in, &mp_type_complex)) {
        return mp_obj_complex_binary_op(op, mpz_as_float(zlhs), 0, rhs_in);
#endif
#endif
    } else {
        // delegate to generic function to check for extra cases
        return mp_obj_int_binary_op_extra_cases(op, lhs_in, rhs_in);
    }

    if (0) {
#if MICROPY_PY_BUILTINS_FLOAT
    } else if (op == MP_BINARY_OP_TRUE_DIVIDE || op == MP_BINARY_OP_INPLACE_TRUE_DIVIDE) {
        mp_float_t flhs = mpz_as_float(zlhs);
        mp_float_t frhs = mpz_as_float(zrhs);
        return mp_obj_new_float(flhs / frhs);
#endif

    } else if (op <= MP_BINARY_OP_INPLACE_POWER) {
        mp_obj_int_t *res = mp_obj_int_new_mpz();

        switch (op) {
            case MP_BINARY_OP_ADD:
            case MP_BINARY_OP_INPLACE_ADD:
                mpz_add_inpl(&res->mpz, zlhs, zrhs);
                break;
            case MP_BINARY_OP_SUBTRACT:
            case MP_BINARY_OP_INPLACE_SUBTRACT:
                mpz_sub_inpl(&res->mpz, zlhs, zrhs);
                break;
            case MP_BINARY_OP_MULTIPLY:
            case MP_BINARY_OP_INPLACE_MULTIPLY:
                mpz_mul_inpl(&res->mpz, zlhs, zrhs);
                break;
            case MP_BINARY_OP_FLOOR_DIVIDE:
            case MP_BINARY_OP_INPLACE_FLOOR_DIVIDE: {
                mpz_t rem; mpz_init_zero(&rem);
                mpz_divmod_inpl(&res->mpz, &rem, zlhs, zrhs);
                if (zlhs->neg != zrhs->neg) {
                    if (!mpz_is_zero(&rem)) {
                        mpz_t mpzone; mpz_init_from_int(&mpzone, -1);
                        mpz_add_inpl(&res->mpz, &res->mpz, &mpzone);
                    }
                }
                mpz_deinit(&rem);
                break;
            }
            case MP_BINARY_OP_MODULO:
            case MP_BINARY_OP_INPLACE_MODULO: {
                mpz_t quo; mpz_init_zero(&quo);
                mpz_divmod_inpl(&quo, &res->mpz, zlhs, zrhs);
                mpz_deinit(&quo);
                // Check signs and do Python style modulo
                if (zlhs->neg != zrhs->neg) {
                    mpz_add_inpl(&res->mpz, &res->mpz, zrhs);
                }
                break;
            }

            case MP_BINARY_OP_AND:
            case MP_BINARY_OP_INPLACE_AND:
                mpz_and_inpl(&res->mpz, zlhs, zrhs);
                break;
            case MP_BINARY_OP_OR:
            case MP_BINARY_OP_INPLACE_OR:
                mpz_or_inpl(&res->mpz, zlhs, zrhs);
                break;
            case MP_BINARY_OP_XOR:
            case MP_BINARY_OP_INPLACE_XOR:
                mpz_xor_inpl(&res->mpz, zlhs, zrhs);
                break;

            case MP_BINARY_OP_LSHIFT:
            case MP_BINARY_OP_INPLACE_LSHIFT:
            case MP_BINARY_OP_RSHIFT:
            case MP_BINARY_OP_INPLACE_RSHIFT: {
                mp_int_t irhs = mp_obj_int_get_checked(rhs_in);
                if (irhs < 0) {
                    nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "negative shift count"));
                }
                if (op == MP_BINARY_OP_LSHIFT || op == MP_BINARY_OP_INPLACE_LSHIFT) {
                    mpz_shl_inpl(&res->mpz, zlhs, irhs);
                } else {
                    mpz_shr_inpl(&res->mpz, zlhs, irhs);
                }
                break;
            }

            case MP_BINARY_OP_POWER:
            case MP_BINARY_OP_INPLACE_POWER:
                mpz_pow_inpl(&res->mpz, zlhs, zrhs);
                break;

            default:
                return MP_OBJ_NULL; // op not supported
        }

        return res;

    } else {
        int cmp = mpz_cmp(zlhs, zrhs);
        switch (op) {
            case MP_BINARY_OP_LESS:
                return MP_BOOL(cmp < 0);
            case MP_BINARY_OP_MORE:
                return MP_BOOL(cmp > 0);
            case MP_BINARY_OP_LESS_EQUAL:
                return MP_BOOL(cmp <= 0);
            case MP_BINARY_OP_MORE_EQUAL:
                return MP_BOOL(cmp >= 0);
            case MP_BINARY_OP_EQUAL:
                return MP_BOOL(cmp == 0);

            default:
                return MP_OBJ_NULL; // op not supported
        }
    }
}

mp_obj_t mp_obj_new_int(mp_int_t value) {
    if (MP_SMALL_INT_FITS(value)) {
        return MP_OBJ_NEW_SMALL_INT(value);
    }
    return mp_obj_new_int_from_ll(value);
}

mp_obj_t mp_obj_new_int_from_ll(long long val) {
    mp_obj_int_t *o = mp_obj_int_new_mpz();
    mpz_set_from_ll(&o->mpz, val, true);
    return o;
}

mp_obj_t mp_obj_new_int_from_ull(unsigned long long val) {
    mp_obj_int_t *o = mp_obj_int_new_mpz();
    mpz_set_from_ll(&o->mpz, val, false);
    return o;
}

mp_obj_t mp_obj_new_int_from_uint(mp_uint_t value) {
    // SMALL_INT accepts only signed numbers, of one bit less size
    // than word size, which totals 2 bits less for unsigned numbers.
    if ((value & (WORD_MSBIT_HIGH | (WORD_MSBIT_HIGH >> 1))) == 0) {
        return MP_OBJ_NEW_SMALL_INT(value);
    }
    return mp_obj_new_int_from_ll(value);
}

mp_obj_t mp_obj_new_int_from_str_len(const char **str, mp_uint_t len, bool neg, mp_uint_t base) {
    mp_obj_int_t *o = mp_obj_int_new_mpz();
    mp_uint_t n = mpz_set_from_str(&o->mpz, *str, len, neg, base);
    *str += n;
    return o;
}

mp_int_t mp_obj_int_get(mp_const_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in);
    } else {
        const mp_obj_int_t *self = self_in;
        // TODO this is a hack until we remove mp_obj_int_get function entirely
        return mpz_hash(&self->mpz);
    }
}

mp_int_t mp_obj_int_get_checked(mp_const_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in);
    } else {
        const mp_obj_int_t *self = self_in;
        mp_int_t value;
        if (mpz_as_int_checked(&self->mpz, &value)) {
            return value;
        } else {
            // overflow
            nlr_raise(mp_obj_new_exception_msg(&mp_type_OverflowError, "overflow converting long int to machine word"));
        }
    }
}

#if MICROPY_PY_BUILTINS_FLOAT
mp_float_t mp_obj_int_as_float(mp_obj_t self_in) {
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        return MP_OBJ_SMALL_INT_VALUE(self_in);
    } else {
        mp_obj_int_t *self = self_in;
        return mpz_as_float(&self->mpz);
    }
}
#endif

#endif
