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

#include <string.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "objtuple.h"
#include "runtime.h"

typedef struct _mp_obj_closure_t {
    mp_obj_base_t base;
    mp_obj_t fun;
    mp_uint_t n_closed;
    mp_obj_t closed[];
} mp_obj_closure_t;

mp_obj_t closure_call(mp_obj_t self_in, mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args) {
    mp_obj_closure_t *self = self_in;

    // need to concatenate closed-over-vars and args

    mp_uint_t n_total = self->n_closed + n_args + 2 * n_kw;
    if (n_total <= 5) {
        // use stack to allocate temporary args array
        mp_obj_t args2[5];
        memcpy(args2, self->closed, self->n_closed * sizeof(mp_obj_t));
        memcpy(args2 + self->n_closed, args, (n_args + 2 * n_kw) * sizeof(mp_obj_t));
        return mp_call_function_n_kw(self->fun, self->n_closed + n_args, n_kw, args2);
    } else {
        // use heap to allocate temporary args array
        mp_obj_t *args2 = m_new(mp_obj_t, n_total);
        memcpy(args2, self->closed, self->n_closed * sizeof(mp_obj_t));
        memcpy(args2 + self->n_closed, args, (n_args + 2 * n_kw) * sizeof(mp_obj_t));
        mp_obj_t res = mp_call_function_n_kw(self->fun, self->n_closed + n_args, n_kw, args2);
        m_del(mp_obj_t, args2, n_total);
        return res;
    }
}

#if MICROPY_ERROR_REPORTING == MICROPY_ERROR_REPORTING_DETAILED
STATIC void closure_print(void (*print)(void *env, const char *fmt, ...), void *env, mp_obj_t o_in, mp_print_kind_t kind) {
    mp_obj_closure_t *o = o_in;
    print(env, "<closure ");
    mp_obj_print_helper(print, env, o->fun, PRINT_REPR);
    print(env, " at %p, n_closed=%u ", o, o->n_closed);
    for (mp_uint_t i = 0; i < o->n_closed; i++) {
        if (o->closed[i] == MP_OBJ_NULL) {
            print(env, "(nil)");
        } else {
            mp_obj_print_helper(print, env, o->closed[i], PRINT_REPR);
        }
        print(env, " ");
    }
    print(env, ">");
}
#endif

const mp_obj_type_t closure_type = {
    { &mp_type_type },
    .name = MP_QSTR_closure,
#if MICROPY_ERROR_REPORTING == MICROPY_ERROR_REPORTING_DETAILED
    .print = closure_print,
#endif
    .call = closure_call,
};

mp_obj_t mp_obj_new_closure(mp_obj_t fun, mp_uint_t n_closed_over, const mp_obj_t *closed) {
    mp_obj_closure_t *o = m_new_obj_var(mp_obj_closure_t, mp_obj_t, n_closed_over);
    o->base.type = &closure_type;
    o->fun = fun;
    o->n_closed = n_closed_over;
    memcpy(o->closed, closed, n_closed_over * sizeof(mp_obj_t));
    return o;
}
