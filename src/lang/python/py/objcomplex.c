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
#include <stdio.h>
#include <assert.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "parsenum.h"
#include "runtime0.h"
#include "runtime.h"

#if MICROPY_PY_BUILTINS_COMPLEX

#include <math.h>

#if MICROPY_FLOAT_IMPL == MICROPY_FLOAT_IMPL_FLOAT
#include "formatfloat.h"
#endif

typedef struct _mp_obj_complex_t {
    mp_obj_base_t base;
    mp_float_t real;
    mp_float_t imag;
} mp_obj_complex_t;

mp_obj_t mp_obj_new_complex(mp_float_t real, mp_float_t imag);

STATIC void complex_print(void (*print)(void *env, const char *fmt, ...), void *env, mp_obj_t o_in, mp_print_kind_t kind) {
    mp_obj_complex_t *o = o_in;
#if MICROPY_FLOAT_IMPL == MICROPY_FLOAT_IMPL_FLOAT
    char buf[16];
    if (o->real == 0) {
        format_float(o->imag, buf, sizeof(buf), 'g', 7, '\0');
        print(env, "%sj", buf);
    } else {
        format_float(o->real, buf, sizeof(buf), 'g', 7, '\0');
        print(env, "(%s+", buf);
        format_float(o->imag, buf, sizeof(buf), 'g', 7, '\0');
        print(env, "%sj)", buf);
    }
#else
    char buf[32];
    if (o->real == 0) {
        sprintf(buf, "%.16g", (double)o->imag);
        print(env, "%sj", buf);
    } else {
        sprintf(buf, "%.16g", (double)o->real);
        print(env, "(%s+", buf);
        sprintf(buf, "%.16g", (double)o->imag);
        print(env, "%sj)", buf);
    }
#endif
}

STATIC mp_obj_t complex_make_new(mp_obj_t type_in, mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 0, 2, false);

    switch (n_args) {
        case 0:
            return mp_obj_new_complex(0, 0);

        case 1:
            if (MP_OBJ_IS_STR(args[0])) {
                // a string, parse it
                mp_uint_t l;
                const char *s = mp_obj_str_get_data(args[0], &l);
                return mp_parse_num_decimal(s, l, true, true);
            } else if (MP_OBJ_IS_TYPE(args[0], &mp_type_complex)) {
                // a complex, just return it
                return args[0];
            } else {
                // something else, try to cast it to a complex
                return mp_obj_new_complex(mp_obj_get_float(args[0]), 0);
            }

        case 2:
        default: {
            mp_float_t real, imag;
            if (MP_OBJ_IS_TYPE(args[0], &mp_type_complex)) {
                mp_obj_complex_get(args[0], &real, &imag);
            } else {
                real = mp_obj_get_float(args[0]);
                imag = 0;
            }
            if (MP_OBJ_IS_TYPE(args[1], &mp_type_complex)) {
                mp_float_t real2, imag2;
                mp_obj_complex_get(args[1], &real2, &imag2);
                real -= imag2;
                imag += real2;
            } else {
                imag += mp_obj_get_float(args[1]);
            }
            return mp_obj_new_complex(real, imag);
        }
    }
}

STATIC mp_obj_t complex_unary_op(mp_uint_t op, mp_obj_t o_in) {
    mp_obj_complex_t *o = o_in;
    switch (op) {
        case MP_UNARY_OP_BOOL: return MP_BOOL(o->real != 0 || o->imag != 0);
        case MP_UNARY_OP_POSITIVE: return o_in;
        case MP_UNARY_OP_NEGATIVE: return mp_obj_new_complex(-o->real, -o->imag);
        default: return MP_OBJ_NULL; // op not supported
    }
}

STATIC mp_obj_t complex_binary_op(mp_uint_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    mp_obj_complex_t *lhs = lhs_in;
    return mp_obj_complex_binary_op(op, lhs->real, lhs->imag, rhs_in);
}

STATIC void complex_load_attr(mp_obj_t self_in, qstr attr, mp_obj_t *dest) {
    mp_obj_complex_t *self = self_in;
    if (attr == MP_QSTR_real) {
        dest[0] = mp_obj_new_float(self->real);
    } else if (attr == MP_QSTR_imag) {
        dest[0] = mp_obj_new_float(self->imag);
    }
}

const mp_obj_type_t mp_type_complex = {
    { &mp_type_type },
    .name = MP_QSTR_complex,
    .print = complex_print,
    .make_new = complex_make_new,
    .unary_op = complex_unary_op,
    .binary_op = complex_binary_op,
    .load_attr = complex_load_attr,
};

mp_obj_t mp_obj_new_complex(mp_float_t real, mp_float_t imag) {
    mp_obj_complex_t *o = m_new_obj(mp_obj_complex_t);
    o->base.type = &mp_type_complex;
    o->real = real;
    o->imag = imag;
    return o;
}

void mp_obj_complex_get(mp_obj_t self_in, mp_float_t *real, mp_float_t *imag) {
    assert(MP_OBJ_IS_TYPE(self_in, &mp_type_complex));
    mp_obj_complex_t *self = self_in;
    *real = self->real;
    *imag = self->imag;
}

mp_obj_t mp_obj_complex_binary_op(mp_uint_t op, mp_float_t lhs_real, mp_float_t lhs_imag, mp_obj_t rhs_in) {
    mp_float_t rhs_real, rhs_imag;
    mp_obj_get_complex(rhs_in, &rhs_real, &rhs_imag); // can be any type, this function will convert to float (if possible)
    switch (op) {
        case MP_BINARY_OP_ADD:
        case MP_BINARY_OP_INPLACE_ADD:
            lhs_real += rhs_real;
            lhs_imag += rhs_imag;
            break;
        case MP_BINARY_OP_SUBTRACT:
        case MP_BINARY_OP_INPLACE_SUBTRACT:
            lhs_real -= rhs_real;
            lhs_imag -= rhs_imag;
            break;
        case MP_BINARY_OP_MULTIPLY:
        case MP_BINARY_OP_INPLACE_MULTIPLY: {
            mp_float_t real;
            multiply:
            real = lhs_real * rhs_real - lhs_imag * rhs_imag;
            lhs_imag = lhs_real * rhs_imag + lhs_imag * rhs_real;
            lhs_real = real;
            break;
        }
        case MP_BINARY_OP_FLOOR_DIVIDE:
        case MP_BINARY_OP_INPLACE_FLOOR_DIVIDE:
            nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "can't do truncated division of a complex number"));

        case MP_BINARY_OP_TRUE_DIVIDE:
        case MP_BINARY_OP_INPLACE_TRUE_DIVIDE:
            if (rhs_imag == 0) {
                if (rhs_real == 0) {
                    nlr_raise(mp_obj_new_exception_msg(&mp_type_ZeroDivisionError, "complex division by zero"));
                }
                lhs_real /= rhs_real;
                lhs_imag /= rhs_real;
            } else if (rhs_real == 0) {
                mp_float_t real = lhs_imag / rhs_imag;
                lhs_imag = -lhs_real / rhs_imag;
                lhs_real = real;
            } else {
                mp_float_t rhs_len_sq = rhs_real*rhs_real + rhs_imag*rhs_imag;
                rhs_real /= rhs_len_sq;
                rhs_imag /= -rhs_len_sq;
                goto multiply;
            }
            break;

        case MP_BINARY_OP_POWER:
        case MP_BINARY_OP_INPLACE_POWER: {
            // z1**z2 = exp(z2*ln(z1))
            //        = exp(z2*(ln(|z1|)+i*arg(z1)))
            //        = exp( (x2*ln1 - y2*arg1) + i*(y2*ln1 + x2*arg1) )
            //        = exp(x3 + i*y3)
            //        = exp(x3)*(cos(y3) + i*sin(y3))
            mp_float_t abs1 = MICROPY_FLOAT_C_FUN(sqrt)(lhs_real*lhs_real + lhs_imag*lhs_imag);
            if (abs1 == 0) {
                if (rhs_imag == 0) {
                    lhs_real = 1;
                    rhs_real = 0;
                } else {
                    nlr_raise(mp_obj_new_exception_msg(&mp_type_ZeroDivisionError, "0.0 to a complex power"));
                }
            } else {
                mp_float_t ln1 = MICROPY_FLOAT_C_FUN(log)(abs1);
                mp_float_t arg1 = MICROPY_FLOAT_C_FUN(atan2)(lhs_imag, lhs_real);
                mp_float_t x3 = rhs_real * ln1 - rhs_imag * arg1;
                mp_float_t y3 = rhs_imag * ln1 + rhs_real * arg1;
                mp_float_t exp_x3 = MICROPY_FLOAT_C_FUN(exp)(x3);
                lhs_real = exp_x3 * MICROPY_FLOAT_C_FUN(cos)(y3);
                lhs_imag = exp_x3 * MICROPY_FLOAT_C_FUN(sin)(y3);
            }
            break;
        }

        case MP_BINARY_OP_EQUAL: return MP_BOOL(lhs_real == rhs_real && lhs_imag == rhs_imag);

        default:
            return MP_OBJ_NULL; // op not supported
    }
    return mp_obj_new_complex(lhs_real, lhs_imag);
}

#endif
