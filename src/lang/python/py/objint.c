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

#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "parsenum.h"
#include "smallint.h"
#include "mpz.h"
#include "objint.h"
#include "objstr.h"
#include "runtime0.h"
#include "runtime.h"

#if MICROPY_PY_BUILTINS_FLOAT
#include <math.h>
#endif

// This dispatcher function is expected to be independent of the implementation of long int
STATIC mp_obj_t mp_obj_int_make_new(mp_obj_t type_in, mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 0, 2, false);

    switch (n_args) {
        case 0:
            return MP_OBJ_NEW_SMALL_INT(0);

        case 1:
            if (MP_OBJ_IS_INT(args[0])) {
                // already an int (small or long), just return it
                return args[0];
            } else if (MP_OBJ_IS_STR_OR_BYTES(args[0])) {
                // a string, parse it
                mp_uint_t l;
                const char *s = mp_obj_str_get_data(args[0], &l);
                return mp_parse_num_integer(s, l, 0);
#if MICROPY_PY_BUILTINS_FLOAT
            } else if (MP_OBJ_IS_TYPE(args[0], &mp_type_float)) {
                return MP_OBJ_NEW_SMALL_INT((MICROPY_FLOAT_C_FUN(trunc)(mp_obj_float_get(args[0]))));
#endif
            } else {
                // try to convert to small int (eg from bool)
                return MP_OBJ_NEW_SMALL_INT(mp_obj_get_int(args[0]));
            }

        case 2:
        default: {
            // should be a string, parse it
            // TODO proper error checking of argument types
            mp_uint_t l;
            const char *s = mp_obj_str_get_data(args[0], &l);
            return mp_parse_num_integer(s, l, mp_obj_get_int(args[1]));
        }
    }
}

void mp_obj_int_print(void (*print)(void *env, const char *fmt, ...), void *env, mp_obj_t self_in, mp_print_kind_t kind) {
    // The size of this buffer is rather arbitrary. If it's not large
    // enough, a dynamic one will be allocated.
    char stack_buf[sizeof(mp_int_t) * 4];
    char *buf = stack_buf;
    mp_uint_t buf_size = sizeof(stack_buf);
    mp_uint_t fmt_size;

    char *str = mp_obj_int_formatted(&buf, &buf_size, &fmt_size, self_in, 10, NULL, '\0', '\0');
    print(env, "%s", str);

    if (buf != stack_buf) {
        m_free(buf, buf_size);
    }
}

#if MICROPY_LONGINT_IMPL == MICROPY_LONGINT_IMPL_LONGLONG
typedef mp_longint_impl_t fmt_int_t;
#else
typedef mp_int_t fmt_int_t;
#endif

STATIC const uint8_t log_base2_floor[] = {
    0,
    0, 1, 1, 2,
    2, 2, 2, 3,
    3, 3, 3, 3,
    3, 3, 3, 4,
    4, 4, 4, 4,
    4, 4, 4, 4,
    4, 4, 4, 4,
    4, 4, 4, 5
};

STATIC uint int_as_str_size_formatted(uint base, const char *prefix, char comma) {
    if (base < 2 || base > 32) {
        return 0;
    }

    uint num_digits = sizeof(fmt_int_t) * 8 / log_base2_floor[base] + 1;
    uint num_commas = comma ? num_digits / 3: 0;
    uint prefix_len = prefix ? strlen(prefix) : 0;
    return num_digits + num_commas + prefix_len + 2; // +1 for sign, +1 for null byte
}

// This routine expects you to pass in a buffer and size (in *buf and *buf_size).
// If, for some reason, this buffer is too small, then it will allocate a
// buffer and return the allocated buffer and size in *buf and *buf_size. It
// is the callers responsibility to free this allocated buffer.
//
// The resulting formatted string will be returned from this function and the
// formatted size will be in *fmt_size.
char *mp_obj_int_formatted(char **buf, mp_uint_t *buf_size, mp_uint_t *fmt_size, mp_const_obj_t self_in,
                           int base, const char *prefix, char base_char, char comma) {
    fmt_int_t num;
    if (MP_OBJ_IS_SMALL_INT(self_in)) {
        // A small int; get the integer value to format.
        num = mp_obj_get_int(self_in);
#if MICROPY_LONGINT_IMPL != MICROPY_LONGINT_IMPL_NONE
    } else if (MP_OBJ_IS_TYPE(self_in, &mp_type_int)) {
        // Not a small int.
#if MICROPY_LONGINT_IMPL == MICROPY_LONGINT_IMPL_LONGLONG
        const mp_obj_int_t *self = self_in;
        // Get the value to format; mp_obj_get_int truncates to mp_int_t.
        num = self->val;
#else
        // Delegate to the implementation for the long int.
        return mp_obj_int_formatted_impl(buf, buf_size, fmt_size, self_in, base, prefix, base_char, comma);
#endif
#endif
    } else {
        // Not an int.
        **buf = '\0';
        *fmt_size = 0;
        return *buf;
    }

    char sign = '\0';
    if (num < 0) {
        num = -num;
        sign = '-';
    }

    uint needed_size = int_as_str_size_formatted(base, prefix, comma);
    if (needed_size > *buf_size) {
        *buf = m_new(char, needed_size);
        *buf_size = needed_size;
    }
    char *str = *buf;

    char *b = str + needed_size;
    *(--b) = '\0';
    char *last_comma = b;

    if (num == 0) {
        *(--b) = '0';
    } else {
        do {
            int c = num % base;
            num /= base;
            if (c >= 10) {
                c += base_char - 10;
            } else {
                c += '0';
            }
            *(--b) = c;
            if (comma && num != 0 && b > str && (last_comma - b) == 3) {
                *(--b) = comma;
                last_comma = b;
            }
        }
        while (b > str && num != 0);
    }
    if (prefix) {
        size_t prefix_len = strlen(prefix);
        char *p = b - prefix_len;
        if (p > str) {
            b = p;
            while (*prefix) {
                *p++ = *prefix++;
            }
        }
    }
    if (sign && b > str) {
        *(--b) = sign;
    }
    *fmt_size = *buf + needed_size - b - 1;

    return b;
}

#if MICROPY_LONGINT_IMPL == MICROPY_LONGINT_IMPL_NONE

mp_int_t mp_obj_int_hash(mp_obj_t self_in) {
    return MP_OBJ_SMALL_INT_VALUE(self_in);
}

bool mp_obj_int_is_positive(mp_obj_t self_in) {
    return mp_obj_get_int(self_in) >= 0;
}

// This is called for operations on SMALL_INT that are not handled by mp_unary_op
mp_obj_t mp_obj_int_unary_op(mp_uint_t op, mp_obj_t o_in) {
    return MP_OBJ_NULL; // op not supported
}

// This is called for operations on SMALL_INT that are not handled by mp_binary_op
mp_obj_t mp_obj_int_binary_op(mp_uint_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    return mp_obj_int_binary_op_extra_cases(op, lhs_in, rhs_in);
}

// This is called only with strings whose value doesn't fit in SMALL_INT
mp_obj_t mp_obj_new_int_from_str_len(const char **str, mp_uint_t len, bool neg, mp_uint_t base) {
    nlr_raise(mp_obj_new_exception_msg(&mp_type_OverflowError, "long int not supported in this build"));
    return mp_const_none;
}

// This is called when an integer larger than a SMALL_INT is needed (although val might still fit in a SMALL_INT)
mp_obj_t mp_obj_new_int_from_ll(long long val) {
    nlr_raise(mp_obj_new_exception_msg(&mp_type_OverflowError, "small int overflow"));
    return mp_const_none;
}

// This is called when an integer larger than a SMALL_INT is needed (although val might still fit in a SMALL_INT)
mp_obj_t mp_obj_new_int_from_ull(unsigned long long val) {
    nlr_raise(mp_obj_new_exception_msg(&mp_type_OverflowError, "small int overflow"));
    return mp_const_none;
}

mp_obj_t mp_obj_new_int_from_uint(mp_uint_t value) {
    // SMALL_INT accepts only signed numbers, of one bit less size
    // then word size, which totals 2 bits less for unsigned numbers.
    if ((value & (WORD_MSBIT_HIGH | (WORD_MSBIT_HIGH >> 1))) == 0) {
        return MP_OBJ_NEW_SMALL_INT(value);
    }
    nlr_raise(mp_obj_new_exception_msg(&mp_type_OverflowError, "small int overflow"));
    return mp_const_none;
}

mp_obj_t mp_obj_new_int(mp_int_t value) {
    if (MP_SMALL_INT_FITS(value)) {
        return MP_OBJ_NEW_SMALL_INT(value);
    }
    nlr_raise(mp_obj_new_exception_msg(&mp_type_OverflowError, "small int overflow"));
    return mp_const_none;
}

mp_int_t mp_obj_int_get(mp_const_obj_t self_in) {
    return MP_OBJ_SMALL_INT_VALUE(self_in);
}

mp_int_t mp_obj_int_get_checked(mp_const_obj_t self_in) {
    return MP_OBJ_SMALL_INT_VALUE(self_in);
}

#if MICROPY_PY_BUILTINS_FLOAT
mp_float_t mp_obj_int_as_float(mp_obj_t self_in) {
    return MP_OBJ_SMALL_INT_VALUE(self_in);
}
#endif

#endif // MICROPY_LONGINT_IMPL == MICROPY_LONGINT_IMPL_NONE

// This dispatcher function is expected to be independent of the implementation of long int
// It handles the extra cases for integer-like arithmetic
mp_obj_t mp_obj_int_binary_op_extra_cases(mp_uint_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    if (rhs_in == mp_const_false) {
        // false acts as 0
        return mp_binary_op(op, lhs_in, MP_OBJ_NEW_SMALL_INT(0));
    } else if (rhs_in == mp_const_true) {
        // true acts as 0
        return mp_binary_op(op, lhs_in, MP_OBJ_NEW_SMALL_INT(1));
    } else if (op == MP_BINARY_OP_MULTIPLY) {
        if (MP_OBJ_IS_STR(rhs_in) || MP_OBJ_IS_TYPE(rhs_in, &mp_type_bytes) || MP_OBJ_IS_TYPE(rhs_in, &mp_type_tuple) || MP_OBJ_IS_TYPE(rhs_in, &mp_type_list)) {
            // multiply is commutative for these types, so delegate to them
            return mp_binary_op(op, rhs_in, lhs_in);
        }
    }
    return MP_OBJ_NULL; // op not supported
}

// this is a classmethod
STATIC mp_obj_t int_from_bytes(mp_uint_t n_args, const mp_obj_t *args) {
    // TODO: Support long ints
    // TODO: Support byteorder param (assumes 'little' at the moment)
    // TODO: Support signed param (assumes signed=False at the moment)

    // get the buffer info
    mp_buffer_info_t bufinfo;
    mp_get_buffer_raise(args[1], &bufinfo, MP_BUFFER_READ);

    // convert the bytes to an integer
    mp_uint_t value = 0;
    for (const byte* buf = (const byte*)bufinfo.buf + bufinfo.len - 1; buf >= (byte*)bufinfo.buf; buf--) {
        value = (value << 8) | *buf;
    }

    return mp_obj_new_int_from_uint(value);
}

STATIC MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(int_from_bytes_fun_obj, 2, 3, int_from_bytes);
STATIC MP_DEFINE_CONST_CLASSMETHOD_OBJ(int_from_bytes_obj, (const mp_obj_t)&int_from_bytes_fun_obj);

STATIC mp_obj_t int_to_bytes(mp_uint_t n_args, const mp_obj_t *args) {
    // TODO: Support long ints
    // TODO: Support byteorder param (assumes 'little')
    // TODO: Support signed param (assumes signed=False)

    mp_int_t val = mp_obj_int_get_checked(args[0]);
    mp_int_t len = MP_OBJ_SMALL_INT_VALUE(args[1]);

    byte *data;
    mp_obj_t o = mp_obj_str_builder_start(&mp_type_bytes, len, &data);
    memset(data, 0, len);

    if (MP_ENDIANNESS_LITTLE) {
        memcpy(data, &val, len < sizeof(mp_int_t) ? len : sizeof(mp_int_t));
    } else {
        while (len--) {
            *data++ = val;
            val >>= 8;
        }
    }

    return mp_obj_str_builder_end(o);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(int_to_bytes_obj, 2, 4, int_to_bytes);

STATIC const mp_map_elem_t int_locals_dict_table[] = {
    { MP_OBJ_NEW_QSTR(MP_QSTR_from_bytes), (mp_obj_t)&int_from_bytes_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_to_bytes), (mp_obj_t)&int_to_bytes_obj },
};

STATIC MP_DEFINE_CONST_DICT(int_locals_dict, int_locals_dict_table);

const mp_obj_type_t mp_type_int = {
    { &mp_type_type },
    .name = MP_QSTR_int,
    .print = mp_obj_int_print,
    .make_new = mp_obj_int_make_new,
    .unary_op = mp_obj_int_unary_op,
    .binary_op = mp_obj_int_binary_op,
    .locals_dict = (mp_obj_t)&int_locals_dict,
};
