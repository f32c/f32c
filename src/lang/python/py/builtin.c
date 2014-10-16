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

#include <stdio.h>
#include <assert.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "objstr.h"
#include "runtime0.h"
#include "runtime.h"
#include "builtin.h"
#include "stream.h"
#include "pfenv.h"

#if MICROPY_PY_BUILTINS_FLOAT
#include <math.h>
#endif

// args[0] is function from class body
// args[1] is class name
// args[2:] are base objects
STATIC mp_obj_t mp_builtin___build_class__(mp_uint_t n_args, const mp_obj_t *args) {
    assert(2 <= n_args);

    // set the new classes __locals__ object
    mp_obj_dict_t *old_locals = mp_locals_get();
    mp_obj_t class_locals = mp_obj_new_dict(0);
    mp_locals_set(class_locals);

    // call the class code
    mp_obj_t cell = mp_call_function_0(args[0]);

    // restore old __locals__ object
    mp_locals_set(old_locals);

    // get the class type (meta object) from the base objects
    mp_obj_t meta;
    if (n_args == 2) {
        // no explicit bases, so use 'type'
        meta = (mp_obj_t)&mp_type_type;
    } else {
        // use type of first base object
        meta = mp_obj_get_type(args[2]);
    }

    // TODO do proper metaclass resolution for multiple base objects

    // create the new class using a call to the meta object
    mp_obj_t meta_args[3];
    meta_args[0] = args[1]; // class name
    meta_args[1] = mp_obj_new_tuple(n_args - 2, args + 2); // tuple of bases
    meta_args[2] = class_locals; // dict of members
    mp_obj_t new_class = mp_call_function_n_kw(meta, 3, 0, meta_args);

    // store into cell if neede
    if (cell != mp_const_none) {
        mp_obj_cell_set(cell, new_class);
    }

    return new_class;
}
MP_DEFINE_CONST_FUN_OBJ_VAR(mp_builtin___build_class___obj, 2, mp_builtin___build_class__);

STATIC mp_obj_t mp_builtin___repl_print__(mp_obj_t o) {
    if (o != mp_const_none) {
        mp_obj_print(o, PRINT_REPR);
        printf("\n");
    }
    return mp_const_none;
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin___repl_print___obj, mp_builtin___repl_print__);

STATIC mp_obj_t mp_builtin_abs(mp_obj_t o_in) {
    if (MP_OBJ_IS_SMALL_INT(o_in)) {
        mp_int_t val = MP_OBJ_SMALL_INT_VALUE(o_in);
        if (val < 0) {
            val = -val;
        }
        return MP_OBJ_NEW_SMALL_INT(val);
#if MICROPY_PY_BUILTINS_FLOAT
    } else if (MP_OBJ_IS_TYPE(o_in, &mp_type_float)) {
        mp_float_t value = mp_obj_float_get(o_in);
        // TODO check for NaN etc
        if (value < 0) {
            return mp_obj_new_float(-value);
        } else {
            return o_in;
        }
#if MICROPY_PY_BUILTINS_COMPLEX
    } else if (MP_OBJ_IS_TYPE(o_in, &mp_type_complex)) {
        mp_float_t real, imag;
        mp_obj_complex_get(o_in, &real, &imag);
        return mp_obj_new_float(MICROPY_FLOAT_C_FUN(sqrt)(real*real + imag*imag));
#endif
#endif
    } else {
        assert(0);
        return mp_const_none;
    }
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_abs_obj, mp_builtin_abs);

STATIC mp_obj_t mp_builtin_all(mp_obj_t o_in) {
    mp_obj_t iterable = mp_getiter(o_in);
    mp_obj_t item;
    while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
        if (!mp_obj_is_true(item)) {
            return mp_const_false;
        }
    }
    return mp_const_true;
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_all_obj, mp_builtin_all);

STATIC mp_obj_t mp_builtin_any(mp_obj_t o_in) {
    mp_obj_t iterable = mp_getiter(o_in);
    mp_obj_t item;
    while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
        if (mp_obj_is_true(item)) {
            return mp_const_true;
        }
    }
    return mp_const_false;
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_any_obj, mp_builtin_any);

STATIC mp_obj_t mp_builtin_bin(mp_obj_t o_in) {
    mp_obj_t args[] = { MP_OBJ_NEW_QSTR(MP_QSTR__brace_open__colon__hash_b_brace_close_), o_in };
    return mp_obj_str_format(MP_ARRAY_SIZE(args), args);
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_bin_obj, mp_builtin_bin);

STATIC mp_obj_t mp_builtin_callable(mp_obj_t o_in) {
    if (mp_obj_is_callable(o_in)) {
        return mp_const_true;
    } else {
        return mp_const_false;
    }
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_callable_obj, mp_builtin_callable);

STATIC mp_obj_t mp_builtin_chr(mp_obj_t o_in) {
    #if MICROPY_PY_BUILTINS_STR_UNICODE
    mp_uint_t c = mp_obj_get_int(o_in);
    char str[4];
    int len = 0;
    if (c < 0x80) {
        *str = c; len = 1;
    } else if (c < 0x800) {
        str[0] = (c >> 6) | 0xC0;
        str[1] = (c & 0x3F) | 0x80;
        len = 2;
    } else if (c < 0x10000) {
        str[0] = (c >> 12) | 0xE0;
        str[1] = ((c >> 6) & 0x3F) | 0x80;
        str[2] = (c & 0x3F) | 0x80;
        len = 3;
    } else if (c < 0x110000) {
        str[0] = (c >> 18) | 0xF0;
        str[1] = ((c >> 12) & 0x3F) | 0x80;
        str[2] = ((c >> 6) & 0x3F) | 0x80;
        str[3] = (c & 0x3F) | 0x80;
        len = 4;
    } else {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "chr() arg not in range(0x110000)"));
    }
    return mp_obj_new_str(str, len, true);
    #else
    mp_int_t ord = mp_obj_get_int(o_in);
    if (0 <= ord && ord <= 0x10ffff) {
        char str[1] = {ord};
        return mp_obj_new_str(str, 1, true);
    } else {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "chr() arg not in range(0x110000)"));
    }
    #endif
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_chr_obj, mp_builtin_chr);

STATIC mp_obj_t mp_builtin_dir(mp_uint_t n_args, const mp_obj_t *args) {
    // TODO make this function more general and less of a hack

    mp_obj_dict_t *dict = NULL;
    if (n_args == 0) {
        // make a list of names in the local name space
        dict = mp_locals_get();
    } else { // n_args == 1
        // make a list of names in the given object
        if (MP_OBJ_IS_TYPE(args[0], &mp_type_module)) {
            dict = mp_obj_module_get_globals(args[0]);
        } else {
            mp_obj_type_t *type;
            if (MP_OBJ_IS_TYPE(args[0], &mp_type_type)) {
                type = args[0];
            } else {
                type = mp_obj_get_type(args[0]);
            }
            if (type->locals_dict != MP_OBJ_NULL && MP_OBJ_IS_TYPE(type->locals_dict, &mp_type_dict)) {
                dict = type->locals_dict;
            }
        }
    }

    mp_obj_t dir = mp_obj_new_list(0, NULL);
    if (dict != NULL) {
        for (mp_uint_t i = 0; i < dict->map.alloc; i++) {
            if (MP_MAP_SLOT_IS_FILLED(&dict->map, i)) {
                mp_obj_list_append(dir, dict->map.table[i].key);
            }
        }
    }

    return dir;
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mp_builtin_dir_obj, 0, 1, mp_builtin_dir);

STATIC mp_obj_t mp_builtin_divmod(mp_obj_t o1_in, mp_obj_t o2_in) {
    // TODO handle big int
    if (MP_OBJ_IS_SMALL_INT(o1_in) && MP_OBJ_IS_SMALL_INT(o2_in)) {
        mp_int_t i1 = MP_OBJ_SMALL_INT_VALUE(o1_in);
        mp_int_t i2 = MP_OBJ_SMALL_INT_VALUE(o2_in);
        if (i2 == 0) {
            #if MICROPY_PY_BUILTINS_FLOAT
            zero_division_error:
            #endif
            nlr_raise(mp_obj_new_exception_msg(&mp_type_ZeroDivisionError, "division by zero"));
        }
        mp_obj_t args[2];
        args[0] = MP_OBJ_NEW_SMALL_INT(i1 / i2);
        args[1] = MP_OBJ_NEW_SMALL_INT(i1 % i2);
        return mp_obj_new_tuple(2, args);
    #if MICROPY_PY_BUILTINS_FLOAT
    } else if (MP_OBJ_IS_TYPE(o1_in, &mp_type_float) || MP_OBJ_IS_TYPE(o2_in, &mp_type_float)) {
        mp_float_t f1 = mp_obj_get_float(o1_in);
        mp_float_t f2 = mp_obj_get_float(o2_in);
        if (f2 == 0.0) {
            goto zero_division_error;
        }
        mp_obj_float_divmod(&f1, &f2);
        mp_obj_t tuple[2] = {
            mp_obj_new_float(f1),
            mp_obj_new_float(f2),
        };
        return mp_obj_new_tuple(2, tuple);
    #endif
    } else {
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "unsupported operand type(s) for divmod(): '%s' and '%s'", mp_obj_get_type_str(o1_in), mp_obj_get_type_str(o2_in)));
    }
}
MP_DEFINE_CONST_FUN_OBJ_2(mp_builtin_divmod_obj, mp_builtin_divmod);

STATIC mp_obj_t mp_builtin_hash(mp_obj_t o_in) {
    // TODO hash will generally overflow small integer; can we safely truncate it?
    return mp_obj_new_int(mp_obj_hash(o_in));
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_hash_obj, mp_builtin_hash);

STATIC mp_obj_t mp_builtin_hex(mp_obj_t o_in) {
    return mp_binary_op(MP_BINARY_OP_MODULO, MP_OBJ_NEW_QSTR(MP_QSTR__percent__hash_x), o_in);
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_hex_obj, mp_builtin_hex);

STATIC mp_obj_t mp_builtin_iter(mp_obj_t o_in) {
    return mp_getiter(o_in);
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_iter_obj, mp_builtin_iter);

STATIC mp_obj_t mp_builtin_min_max(mp_uint_t n_args, const mp_obj_t *args, mp_map_t *kwargs, mp_uint_t op) {
    mp_map_elem_t *key_elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_key), MP_MAP_LOOKUP);
    mp_obj_t key_fn = key_elem == NULL ? MP_OBJ_NULL : key_elem->value;
    if (n_args == 1) {
        // given an iterable
        mp_obj_t iterable = mp_getiter(args[0]);
        mp_obj_t best_key = MP_OBJ_NULL;
        mp_obj_t best_obj = MP_OBJ_NULL;
        mp_obj_t item;
        while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
            mp_obj_t key = key_fn == MP_OBJ_NULL ? item : mp_call_function_1(key_fn, item);
            if (best_obj == MP_OBJ_NULL || (mp_binary_op(op, key, best_key) == mp_const_true)) {
                best_key = key;
                best_obj = item;
            }
        }
        if (best_obj == MP_OBJ_NULL) {
            nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "arg is an empty sequence"));
        }
        return best_obj;
    } else {
        // given many args
        mp_obj_t best_key = MP_OBJ_NULL;
        mp_obj_t best_obj = MP_OBJ_NULL;
        for (mp_uint_t i = 0; i < n_args; i++) {
            mp_obj_t key = key_fn == MP_OBJ_NULL ? args[i] : mp_call_function_1(key_fn, args[i]);
            if (best_obj == MP_OBJ_NULL || (mp_binary_op(op, key, best_key) == mp_const_true)) {
                best_key = key;
                best_obj = args[i];
            }
        }
        return best_obj;
    }
}

STATIC mp_obj_t mp_builtin_max(mp_uint_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    return mp_builtin_min_max(n_args, args, kwargs, MP_BINARY_OP_MORE);
}
MP_DEFINE_CONST_FUN_OBJ_KW(mp_builtin_max_obj, 1, mp_builtin_max);

STATIC mp_obj_t mp_builtin_min(mp_uint_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    return mp_builtin_min_max(n_args, args, kwargs, MP_BINARY_OP_LESS);
}
MP_DEFINE_CONST_FUN_OBJ_KW(mp_builtin_min_obj, 1, mp_builtin_min);

STATIC mp_obj_t mp_builtin_next(mp_obj_t o) {
    mp_obj_t ret = mp_iternext_allow_raise(o);
    if (ret == MP_OBJ_STOP_ITERATION) {
        nlr_raise(mp_obj_new_exception(&mp_type_StopIteration));
    } else {
        return ret;
    }
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_next_obj, mp_builtin_next);

STATIC mp_obj_t mp_builtin_oct(mp_obj_t o_in) {
    return mp_binary_op(MP_BINARY_OP_MODULO, MP_OBJ_NEW_QSTR(MP_QSTR__percent__hash_o), o_in);
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_oct_obj, mp_builtin_oct);

STATIC mp_obj_t mp_builtin_ord(mp_obj_t o_in) {
    mp_uint_t len;
    const char *str = mp_obj_str_get_data(o_in, &len);
    #if MICROPY_PY_BUILTINS_STR_UNICODE
    mp_uint_t charlen = unichar_charlen(str, len);
    if (charlen == 1) {
        if (MP_OBJ_IS_STR(o_in) && UTF8_IS_NONASCII(*str)) {
            mp_int_t ord = *str++ & 0x7F;
            for (mp_int_t mask = 0x40; ord & mask; mask >>= 1) {
                ord &= ~mask;
            }
            while (UTF8_IS_CONT(*str)) {
                ord = (ord << 6) | (*str++ & 0x3F);
            }
            return mp_obj_new_int(ord);
        } else {
            return mp_obj_new_int(((const byte*)str)[0]);
        }
    } else {
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "ord() expected a character, but string of length %d found", charlen));
    }
    #else
    if (len == 1) {
        // don't sign extend when converting to ord
        return mp_obj_new_int(((const byte*)str)[0]);
    } else {
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "ord() expected a character, but string of length %d found", len));
    }
    #endif
}
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_ord_obj, mp_builtin_ord);

STATIC mp_obj_t mp_builtin_pow(mp_uint_t n_args, const mp_obj_t *args) {
    assert(2 <= n_args && n_args <= 3);
    switch (n_args) {
        case 2: return mp_binary_op(MP_BINARY_OP_POWER, args[0], args[1]);
        default: return mp_binary_op(MP_BINARY_OP_MODULO, mp_binary_op(MP_BINARY_OP_POWER, args[0], args[1]), args[2]); // TODO optimise...
    }
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mp_builtin_pow_obj, 2, 3, mp_builtin_pow);

STATIC mp_obj_t mp_builtin_print(mp_uint_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    mp_map_elem_t *sep_elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_sep), MP_MAP_LOOKUP);
    mp_map_elem_t *end_elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_end), MP_MAP_LOOKUP);
    const char *sep_data = " ";
    mp_uint_t sep_len = 1;
    const char *end_data = "\n";
    mp_uint_t end_len = 1;
    if (sep_elem != NULL && sep_elem->value != mp_const_none) {
        sep_data = mp_obj_str_get_data(sep_elem->value, &sep_len);
    }
    if (end_elem != NULL && end_elem->value != mp_const_none) {
        end_data = mp_obj_str_get_data(end_elem->value, &end_len);
    }
    #if MICROPY_PY_IO
    mp_obj_t stream_obj = &mp_sys_stdout_obj;
    mp_map_elem_t *file_elem = mp_map_lookup(kwargs, MP_OBJ_NEW_QSTR(MP_QSTR_file), MP_MAP_LOOKUP);
    if (file_elem != NULL && file_elem->value != mp_const_none) {
        stream_obj = file_elem->value;
    }

    pfenv_t pfenv;
    pfenv.data = stream_obj;
    pfenv.print_strn = (void (*)(void *, const char *, mp_uint_t))mp_stream_write;
    #endif
    for (mp_uint_t i = 0; i < n_args; i++) {
        if (i > 0) {
            #if MICROPY_PY_IO
            mp_stream_write(stream_obj, sep_data, sep_len);
            #else
            printf("%.*s", (int)sep_len, sep_data);
            #endif
        }
        #if MICROPY_PY_IO
        mp_obj_print_helper((void (*)(void *env, const char *fmt, ...))pfenv_printf, &pfenv, args[i], PRINT_STR);
        #else
        mp_obj_print(args[i], PRINT_STR);
        #endif
    }
    #if MICROPY_PY_IO
    mp_stream_write(stream_obj, end_data, end_len);
    #else
    printf("%.*s", (int)end_len, end_data);
    #endif
    return mp_const_none;
}
MP_DEFINE_CONST_FUN_OBJ_KW(mp_builtin_print_obj, 0, mp_builtin_print);

STATIC mp_obj_t mp_builtin_repr(mp_obj_t o_in) {
    vstr_t *vstr = vstr_new();
    mp_obj_print_helper((void (*)(void *env, const char *fmt, ...))vstr_printf, vstr, o_in, PRINT_REPR);
    mp_obj_t s = mp_obj_new_str(vstr->buf, vstr->len, false);
    vstr_free(vstr);
    return s;
}

MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_repr_obj, mp_builtin_repr);

STATIC mp_obj_t mp_builtin_sum(mp_uint_t n_args, const mp_obj_t *args) {
    assert(1 <= n_args && n_args <= 2);
    mp_obj_t value;
    switch (n_args) {
        case 1: value = mp_obj_new_int(0); break;
        default: value = args[1]; break;
    }
    mp_obj_t iterable = mp_getiter(args[0]);
    mp_obj_t item;
    while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
        value = mp_binary_op(MP_BINARY_OP_ADD, value, item);
    }
    return value;
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mp_builtin_sum_obj, 1, 2, mp_builtin_sum);

STATIC mp_obj_t mp_builtin_sorted(mp_uint_t n_args, const mp_obj_t *args, mp_map_t *kwargs) {
    assert(n_args >= 1);
    if (n_args > 1) {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_TypeError,
                                          "must use keyword argument for key function"));
    }
    mp_obj_t self = mp_type_list.make_new((mp_obj_t)&mp_type_list, 1, 0, args);
    mp_obj_list_sort(1, &self, kwargs);

    return self;
}
MP_DEFINE_CONST_FUN_OBJ_KW(mp_builtin_sorted_obj, 1, mp_builtin_sorted);

// See mp_load_attr() if making any changes
STATIC inline mp_obj_t mp_load_attr_default(mp_obj_t base, qstr attr, mp_obj_t defval) {
    mp_obj_t dest[2];
    // use load_method, raising or not raising exception
    ((defval == MP_OBJ_NULL) ? mp_load_method : mp_load_method_maybe)(base, attr, dest);
    if (dest[0] == MP_OBJ_NULL) {
        return defval;
    } else if (dest[1] == MP_OBJ_NULL) {
        // load_method returned just a normal attribute
        return dest[0];
    } else {
        // load_method returned a method, so build a bound method object
        return mp_obj_new_bound_meth(dest[0], dest[1]);
    }
}

STATIC mp_obj_t mp_builtin_getattr(mp_uint_t n_args, const mp_obj_t *args) {
    mp_obj_t attr = args[1];
    if (MP_OBJ_IS_TYPE(attr, &mp_type_str)) {
        attr = mp_obj_str_intern(attr);
    } else if (!MP_OBJ_IS_QSTR(attr)) {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_TypeError, "string required"));
    }
    mp_obj_t defval = MP_OBJ_NULL;
    if (n_args > 2) {
        defval = args[2];
    }
    return mp_load_attr_default(args[0], MP_OBJ_QSTR_VALUE(attr), defval);
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mp_builtin_getattr_obj, 2, 3, mp_builtin_getattr);

STATIC mp_obj_t mp_builtin_hasattr(mp_obj_t object_in, mp_obj_t attr_in) {
    assert(MP_OBJ_IS_QSTR(attr_in));

    mp_obj_t dest[2];
    // TODO: https://docs.python.org/3/library/functions.html?highlight=hasattr#hasattr
    // explicitly says "This is implemented by calling getattr(object, name) and seeing
    // whether it raises an AttributeError or not.", so we should explicitly wrap this
    // in nlr_push and handle exception.
    mp_load_method_maybe(object_in, MP_OBJ_QSTR_VALUE(attr_in), dest);

    return MP_BOOL(dest[0] != MP_OBJ_NULL);
}
MP_DEFINE_CONST_FUN_OBJ_2(mp_builtin_hasattr_obj, mp_builtin_hasattr);

// These are defined in terms of MicroPython API functions right away
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_id_obj, mp_obj_id);
MP_DEFINE_CONST_FUN_OBJ_1(mp_builtin_len_obj, mp_obj_len);
MP_DEFINE_CONST_FUN_OBJ_0(mp_builtin_globals_obj, mp_globals_get);
MP_DEFINE_CONST_FUN_OBJ_0(mp_builtin_locals_obj, mp_locals_get);
