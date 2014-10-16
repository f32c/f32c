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

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "runtime0.h"
#include "runtime.h"

typedef struct _mp_obj_bool_t {
    mp_obj_base_t base;
    bool value;
} mp_obj_bool_t;

STATIC void bool_print(void (*print)(void *env, const char *fmt, ...), void *env, mp_obj_t self_in, mp_print_kind_t kind) {
    mp_obj_bool_t *self = self_in;
    if (MICROPY_PY_UJSON && kind == PRINT_JSON) {
        if (self->value) {
            print(env, "true");
        } else {
            print(env, "false");
        }
    } else {
        if (self->value) {
            print(env, "True");
        } else {
            print(env, "False");
        }
    }
}

STATIC mp_obj_t bool_make_new(mp_obj_t type_in, mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 0, 1, false);

    switch (n_args) {
        case 0:
            return mp_const_false;
        case 1:
        default: // must be 0 or 1
            if (mp_obj_is_true(args[0])) { return mp_const_true; } else { return mp_const_false; }
    }
}

STATIC mp_obj_t bool_unary_op(mp_uint_t op, mp_obj_t o_in) {
    mp_int_t value = ((mp_obj_bool_t*)o_in)->value;
    switch (op) {
        case MP_UNARY_OP_BOOL: return o_in;
        case MP_UNARY_OP_POSITIVE: return MP_OBJ_NEW_SMALL_INT(value);
        case MP_UNARY_OP_NEGATIVE: return MP_OBJ_NEW_SMALL_INT(-value);
        case MP_UNARY_OP_INVERT: return MP_OBJ_NEW_SMALL_INT(~value);

        // only bool needs to implement MP_UNARY_OP_NOT
        case MP_UNARY_OP_NOT:
        default: // no other cases
            if (value) {
                return mp_const_false;
            } else {
                return mp_const_true;
            }
    }
}

STATIC mp_obj_t bool_binary_op(mp_uint_t op, mp_obj_t lhs_in, mp_obj_t rhs_in) {
    if (MP_BINARY_OP_OR <= op && op <= MP_BINARY_OP_NOT_EQUAL) {
        return mp_binary_op(op, MP_OBJ_NEW_SMALL_INT(mp_obj_is_true(lhs_in)), rhs_in);
    }
    return MP_OBJ_NULL; // op not supported
}

const mp_obj_type_t mp_type_bool = {
    { &mp_type_type },
    .name = MP_QSTR_bool,
    .print = bool_print,
    .make_new = bool_make_new,
    .unary_op = bool_unary_op,
    .binary_op = bool_binary_op,
};

const mp_obj_bool_t mp_const_false_obj = {{&mp_type_bool}, false};
const mp_obj_bool_t mp_const_true_obj = {{&mp_type_bool}, true};
