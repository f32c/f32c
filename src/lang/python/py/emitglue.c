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

// This code glues the code emitters to the runtime.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "mpconfig.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "runtime0.h"
#include "runtime.h"
#include "emitglue.h"
#include "bc.h"

#if 0 // print debugging info
#define DEBUG_PRINT (1)
#define WRITE_CODE (1)
#define DEBUG_printf DEBUG_printf
#define DEBUG_OP_printf(...) DEBUG_printf(__VA_ARGS__)
#else // don't print debugging info
#define DEBUG_printf(...) (void)0
#define DEBUG_OP_printf(...) (void)0
#endif

mp_raw_code_t *mp_emit_glue_new_raw_code(void) {
    mp_raw_code_t *rc = m_new0(mp_raw_code_t, 1);
    rc->kind = MP_CODE_RESERVED;
    return rc;
}

void mp_emit_glue_assign_bytecode(mp_raw_code_t *rc, byte *code, mp_uint_t len, mp_uint_t n_pos_args, mp_uint_t n_kwonly_args, qstr *arg_names, mp_uint_t scope_flags) {
    rc->kind = MP_CODE_BYTECODE;
    rc->scope_flags = scope_flags;
    rc->n_pos_args = n_pos_args;
    rc->n_kwonly_args = n_kwonly_args;
    rc->arg_names = arg_names;
    rc->u_byte.code = code;
    rc->u_byte.len = len;

#ifdef DEBUG_PRINT
    DEBUG_printf("assign byte code: code=%p len=" UINT_FMT " n_pos_args=" UINT_FMT " n_kwonly_args=" UINT_FMT " flags=%x\n", code, len, n_pos_args, n_kwonly_args, (uint)scope_flags);
    DEBUG_printf("  arg names:");
    for (int i = 0; i < n_pos_args + n_kwonly_args; i++) {
        DEBUG_printf(" %s", qstr_str(arg_names[i]));
    }
    DEBUG_printf("\n");
#endif
#if MICROPY_DEBUG_PRINTERS
    if (mp_verbose_flag > 0) {
        for (mp_uint_t i = 0; i < len; i++) {
            if (i > 0 && i % 16 == 0) {
                printf("\n");
            }
            printf(" %02x", code[i]);
        }
        printf("\n");
        mp_bytecode_print(rc, code, len);
    }
#endif
}

#if MICROPY_EMIT_NATIVE || MICROPY_EMIT_INLINE_THUMB
void mp_emit_glue_assign_native(mp_raw_code_t *rc, mp_raw_code_kind_t kind, void *fun_data, mp_uint_t fun_len, mp_uint_t n_args, mp_uint_t type_sig) {
    assert(kind == MP_CODE_NATIVE_PY || kind == MP_CODE_NATIVE_VIPER || kind == MP_CODE_NATIVE_ASM);
    rc->kind = kind;
    rc->scope_flags = 0;
    rc->n_pos_args = n_args;
    rc->u_native.fun_data = fun_data;
    rc->u_native.type_sig = type_sig;

#ifdef DEBUG_PRINT
    DEBUG_printf("assign native: kind=%d fun=%p len=" UINT_FMT " n_args=" UINT_FMT "\n", kind, fun_data, fun_len, n_args);
    for (mp_uint_t i = 0; i < fun_len; i++) {
        if (i > 0 && i % 16 == 0) {
            DEBUG_printf("\n");
        }
        DEBUG_printf(" %02x", ((byte*)fun_data)[i]);
    }
    DEBUG_printf("\n");

#ifdef WRITE_CODE
    FILE *fp_write_code = fopen("out-code", "wb");
    fwrite(fun_data, fun_len, 1, fp_write_code);
    fclose(fp_write_code);
#endif
#endif
}
#endif

mp_obj_t mp_make_function_from_raw_code(mp_raw_code_t *rc, mp_obj_t def_args, mp_obj_t def_kw_args) {
    DEBUG_OP_printf("make_function_from_raw_code %p\n", rc);
    assert(rc != NULL);

    // def_args must be MP_OBJ_NULL or a tuple
    assert(def_args == MP_OBJ_NULL || MP_OBJ_IS_TYPE(def_args, &mp_type_tuple));

    // def_kw_args must be MP_OBJ_NULL or a dict
    assert(def_kw_args == MP_OBJ_NULL || MP_OBJ_IS_TYPE(def_kw_args, &mp_type_dict));

    // make the function, depending on the raw code kind
    mp_obj_t fun;
    switch (rc->kind) {
        case MP_CODE_BYTECODE:
            fun = mp_obj_new_fun_bc(rc->scope_flags, rc->arg_names, rc->n_pos_args, rc->n_kwonly_args, def_args, def_kw_args, rc->u_byte.code);
            break;
        #if MICROPY_EMIT_NATIVE
        case MP_CODE_NATIVE_PY:
            fun = mp_obj_new_fun_native(rc->n_pos_args, rc->u_native.fun_data);
            break;
        case MP_CODE_NATIVE_VIPER:
            fun = mp_obj_new_fun_viper(rc->n_pos_args, rc->u_native.fun_data, rc->u_native.type_sig);
            break;
        #endif
        #if MICROPY_EMIT_INLINE_THUMB
        case MP_CODE_NATIVE_ASM:
            fun = mp_obj_new_fun_asm(rc->n_pos_args, rc->u_native.fun_data);
            break;
        #endif
        default:
            // raw code was never set (this should not happen)
            assert(0);
            return mp_const_none;
    }

    // check for generator functions and if so wrap in generator object
    if ((rc->scope_flags & MP_SCOPE_FLAG_GENERATOR) != 0) {
        fun = mp_obj_new_gen_wrap(fun);
    }

    return fun;
}

mp_obj_t mp_make_closure_from_raw_code(mp_raw_code_t *rc, mp_uint_t n_closed_over, const mp_obj_t *args) {
    DEBUG_OP_printf("make_closure_from_raw_code %p " UINT_FMT " %p\n", rc, n_closed_over, args);
    // make function object
    mp_obj_t ffun;
    if (n_closed_over & 0x100) {
        // default positional and keyword args given
        ffun = mp_make_function_from_raw_code(rc, args[0], args[1]);
    } else {
        // default positional and keyword args not given
        ffun = mp_make_function_from_raw_code(rc, MP_OBJ_NULL, MP_OBJ_NULL);
    }
    // wrap function in closure object
    return mp_obj_new_closure(ffun, n_closed_over & 0xff, args + ((n_closed_over >> 7) & 2));
}
