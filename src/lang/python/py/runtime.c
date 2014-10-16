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
#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "objtuple.h"
#include "objlist.h"
#include "objmodule.h"
#include "parsenum.h"
#include "runtime0.h"
#include "runtime.h"
#include "emitglue.h"
#include "builtin.h"
#include "builtintables.h"
#include "bc.h"
#include "smallint.h"
#include "objgenerator.h"
#include "lexer.h"
#include "parse.h"
#include "parsehelper.h"
#include "compile.h"
#include "stackctrl.h"
#include "gc.h"

#if 0 // print debugging info
#define DEBUG_PRINT (1)
#define DEBUG_printf DEBUG_printf
#define DEBUG_OP_printf(...) DEBUG_printf(__VA_ARGS__)
#else // don't print debugging info
#define DEBUG_printf(...) (void)0
#define DEBUG_OP_printf(...) (void)0
#endif

// locals and globals need to be pointers because they can be the same in outer module scope
STATIC mp_obj_dict_t *dict_locals;
STATIC mp_obj_dict_t *dict_globals;

// dictionary for the __main__ module
STATIC mp_obj_dict_t dict_main;

const mp_obj_module_t mp_module___main__ = {
    .base = { &mp_type_module },
    .name = MP_QSTR___main__,
    .globals = (mp_obj_dict_t*)&dict_main,
};

void mp_init(void) {
    qstr_init();
    mp_stack_ctrl_init();

#if MICROPY_ENABLE_EMERGENCY_EXCEPTION_BUF
    mp_init_emergency_exception_buf();
#endif

    // call port specific initialization if any
#ifdef MICROPY_PORT_INIT_FUNC
    MICROPY_PORT_INIT_FUNC;
#endif

    // optimization disabled by default
    mp_optimise_value = 0;

    // init global module stuff
    mp_module_init();

    // initialise the __main__ module
    mp_obj_dict_init(&dict_main, 1);
    mp_obj_dict_store(&dict_main, MP_OBJ_NEW_QSTR(MP_QSTR___name__), MP_OBJ_NEW_QSTR(MP_QSTR___main__));

    // locals = globals for outer module (see Objects/frameobject.c/PyFrame_New())
    dict_locals = dict_globals = &dict_main;
}

void mp_deinit(void) {
    //mp_obj_dict_free(&dict_main);
    mp_module_deinit();

    // call port specific deinitialization if any 
#ifdef MICROPY_PORT_INIT_FUNC
    MICROPY_PORT_DEINIT_FUNC;
#endif
}

mp_obj_t mp_load_const_int(qstr qstr) {
    DEBUG_OP_printf("load '%s'\n", qstr_str(qstr));
    mp_uint_t len;
    const byte* data = qstr_data(qstr, &len);
    return mp_parse_num_integer((const char*)data, len, 0);
}

mp_obj_t mp_load_const_dec(qstr qstr) {
    DEBUG_OP_printf("load '%s'\n", qstr_str(qstr));
    mp_uint_t len;
    const byte* data = qstr_data(qstr, &len);
    return mp_parse_num_decimal((const char*)data, len, true, false);
}

mp_obj_t mp_load_const_str(qstr qstr) {
    DEBUG_OP_printf("load '%s'\n", qstr_str(qstr));
    return MP_OBJ_NEW_QSTR(qstr);
}

mp_obj_t mp_load_const_bytes(qstr qstr) {
    DEBUG_OP_printf("load b'%s'\n", qstr_str(qstr));
    mp_uint_t len;
    const byte *data = qstr_data(qstr, &len);
    return mp_obj_new_bytes(data, len);
}

mp_obj_t mp_load_name(qstr qstr) {
    // logic: search locals, globals, builtins
    DEBUG_OP_printf("load name %s\n", qstr_str(qstr));
    // If we're at the outer scope (locals == globals), dispatch to load_global right away
    if (dict_locals != dict_globals) {
        mp_map_elem_t *elem = mp_map_lookup(&dict_locals->map, MP_OBJ_NEW_QSTR(qstr), MP_MAP_LOOKUP);
        if (elem != NULL) {
            return elem->value;
        }
    }
    return mp_load_global(qstr);
}

mp_obj_t mp_load_global(qstr qstr) {
    // logic: search globals, builtins
    DEBUG_OP_printf("load global %s\n", qstr_str(qstr));
    mp_map_elem_t *elem = mp_map_lookup(&dict_globals->map, MP_OBJ_NEW_QSTR(qstr), MP_MAP_LOOKUP);
    if (elem == NULL) {
        // TODO lookup in dynamic table of builtins first
        elem = mp_map_lookup((mp_map_t*)&mp_builtin_object_dict_obj.map, MP_OBJ_NEW_QSTR(qstr), MP_MAP_LOOKUP);
        if (elem == NULL) {
            nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_NameError, "name '%s' is not defined", qstr_str(qstr)));
        }
    }
    return elem->value;
}

mp_obj_t mp_load_build_class(void) {
    DEBUG_OP_printf("load_build_class\n");
    // TODO lookup __build_class__ in dynamic table of builtins first
    // ... else no user-defined __build_class__, return builtin one
    return (mp_obj_t)&mp_builtin___build_class___obj;
}

void mp_store_name(qstr qstr, mp_obj_t obj) {
    DEBUG_OP_printf("store name %s <- %p\n", qstr_str(qstr), obj);
    mp_obj_dict_store(dict_locals, MP_OBJ_NEW_QSTR(qstr), obj);
}

void mp_delete_name(qstr qstr) {
    DEBUG_OP_printf("delete name %s\n", qstr_str(qstr));
    // TODO convert KeyError to NameError if qstr not found
    mp_obj_dict_delete(dict_locals, MP_OBJ_NEW_QSTR(qstr));
}

void mp_store_global(qstr qstr, mp_obj_t obj) {
    DEBUG_OP_printf("store global %s <- %p\n", qstr_str(qstr), obj);
    mp_obj_dict_store(dict_globals, MP_OBJ_NEW_QSTR(qstr), obj);
}

void mp_delete_global(qstr qstr) {
    DEBUG_OP_printf("delete global %s\n", qstr_str(qstr));
    // TODO convert KeyError to NameError if qstr not found
    mp_obj_dict_delete(dict_globals, MP_OBJ_NEW_QSTR(qstr));
}

mp_obj_t mp_unary_op(mp_uint_t op, mp_obj_t arg) {
    DEBUG_OP_printf("unary " UINT_FMT " %p\n", op, arg);

    if (MP_OBJ_IS_SMALL_INT(arg)) {
        mp_int_t val = MP_OBJ_SMALL_INT_VALUE(arg);
        switch (op) {
            case MP_UNARY_OP_BOOL:
                return MP_BOOL(val != 0);
            case MP_UNARY_OP_POSITIVE:
                return arg;
            case MP_UNARY_OP_NEGATIVE:
                // check for overflow
                if (val == MP_SMALL_INT_MIN) {
                    return mp_obj_new_int(-val);
                } else {
                    return MP_OBJ_NEW_SMALL_INT(-val);
                }
            case MP_UNARY_OP_INVERT:
                return MP_OBJ_NEW_SMALL_INT(~val);
            default:
                assert(0);
                return arg;
        }
    } else {
        mp_obj_type_t *type = mp_obj_get_type(arg);
        if (type->unary_op != NULL) {
            mp_obj_t result = type->unary_op(op, arg);
            if (result != MP_OBJ_NULL) {
                return result;
            }
        }
        // TODO specify in error message what the operator is
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "bad operand type for unary operator: '%s'", mp_obj_get_type_str(arg)));
    }
}

mp_obj_t mp_binary_op(mp_uint_t op, mp_obj_t lhs, mp_obj_t rhs) {
    DEBUG_OP_printf("binary " UINT_FMT " %p %p\n", op, lhs, rhs);

    // TODO correctly distinguish inplace operators for mutable objects
    // lookup logic that CPython uses for +=:
    //   check for implemented +=
    //   then check for implemented +
    //   then check for implemented seq.inplace_concat
    //   then check for implemented seq.concat
    //   then fail
    // note that list does not implement + or +=, so that inplace_concat is reached first for +=

    // deal with is
    if (op == MP_BINARY_OP_IS) {
        return MP_BOOL(lhs == rhs);
    }

    // deal with == and != for all types
    if (op == MP_BINARY_OP_EQUAL || op == MP_BINARY_OP_NOT_EQUAL) {
        if (mp_obj_equal(lhs, rhs)) {
            if (op == MP_BINARY_OP_EQUAL) {
                return mp_const_true;
            } else {
                return mp_const_false;
            }
        } else {
            if (op == MP_BINARY_OP_EQUAL) {
                return mp_const_false;
            } else {
                return mp_const_true;
            }
        }
    }

    // deal with exception_match for all types
    if (op == MP_BINARY_OP_EXCEPTION_MATCH) {
        // rhs must be issubclass(rhs, BaseException)
        if (mp_obj_is_exception_type(rhs)) {
            if (mp_obj_exception_match(lhs, rhs)) {
                return mp_const_true;
            } else {
                return mp_const_false;
            }
        } else if (MP_OBJ_IS_TYPE(rhs, &mp_type_tuple)) {
            mp_obj_tuple_t *tuple = rhs;
            for (mp_uint_t i = 0; i < tuple->len; i++) {
                rhs = tuple->items[i];
                if (!mp_obj_is_exception_type(rhs)) {
                    goto unsupported_op;
                }
                if (mp_obj_exception_match(lhs, rhs)) {
                    return mp_const_true;
                }
            }
            return mp_const_false;
        }
        goto unsupported_op;
    }

    if (MP_OBJ_IS_SMALL_INT(lhs)) {
        mp_int_t lhs_val = MP_OBJ_SMALL_INT_VALUE(lhs);
        if (MP_OBJ_IS_SMALL_INT(rhs)) {
            mp_int_t rhs_val = MP_OBJ_SMALL_INT_VALUE(rhs);
            // This is a binary operation: lhs_val op rhs_val
            // We need to be careful to handle overflow; see CERT INT32-C
            // Operations that can overflow:
            //      +       result always fits in mp_int_t, then handled by SMALL_INT check
            //      -       result always fits in mp_int_t, then handled by SMALL_INT check
            //      *       checked explicitly
            //      /       if lhs=MIN and rhs=-1; result always fits in mp_int_t, then handled by SMALL_INT check
            //      %       if lhs=MIN and rhs=-1; result always fits in mp_int_t, then handled by SMALL_INT check
            //      <<      checked explicitly
            switch (op) {
                case MP_BINARY_OP_OR:
                case MP_BINARY_OP_INPLACE_OR: lhs_val |= rhs_val; break;
                case MP_BINARY_OP_XOR:
                case MP_BINARY_OP_INPLACE_XOR: lhs_val ^= rhs_val; break;
                case MP_BINARY_OP_AND:
                case MP_BINARY_OP_INPLACE_AND: lhs_val &= rhs_val; break;
                case MP_BINARY_OP_LSHIFT:
                case MP_BINARY_OP_INPLACE_LSHIFT: {
                    if (rhs_val < 0) {
                        // negative shift not allowed
                        nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "negative shift count"));
                    } else if (rhs_val >= BITS_PER_WORD || lhs_val > (MP_SMALL_INT_MAX >> rhs_val) || lhs_val < (MP_SMALL_INT_MIN >> rhs_val)) {
                        // left-shift will overflow, so use higher precision integer
                        lhs = mp_obj_new_int_from_ll(lhs_val);
                        goto generic_binary_op;
                    } else {
                        // use standard precision
                        lhs_val <<= rhs_val;
                    }
                    break;
                }
                case MP_BINARY_OP_RSHIFT:
                case MP_BINARY_OP_INPLACE_RSHIFT:
                    if (rhs_val < 0) {
                        // negative shift not allowed
                        nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "negative shift count"));
                    } else {
                        // standard precision is enough for right-shift
                        lhs_val >>= rhs_val;
                    }
                    break;
                case MP_BINARY_OP_ADD:
                case MP_BINARY_OP_INPLACE_ADD: lhs_val += rhs_val; break;
                case MP_BINARY_OP_SUBTRACT:
                case MP_BINARY_OP_INPLACE_SUBTRACT: lhs_val -= rhs_val; break;
                case MP_BINARY_OP_MULTIPLY:
                case MP_BINARY_OP_INPLACE_MULTIPLY: {

                    // If long long type exists and is larger than mp_int_t, then
                    // we can use the following code to perform overflow-checked multiplication.
                    // Otherwise (eg in x64 case) we must use mp_small_int_mul_overflow.
                    #if 0
                    // compute result using long long precision
                    long long res = (long long)lhs_val * (long long)rhs_val;
                    if (res > MP_SMALL_INT_MAX || res < MP_SMALL_INT_MIN) {
                        // result overflowed SMALL_INT, so return higher precision integer
                        return mp_obj_new_int_from_ll(res);
                    } else {
                        // use standard precision
                        lhs_val = (mp_int_t)res;
                    }
                    #endif

                    if (mp_small_int_mul_overflow(lhs_val, rhs_val)) {
                        // use higher precision
                        lhs = mp_obj_new_int_from_ll(lhs_val);
                        goto generic_binary_op;
                    } else {
                        // use standard precision
                        return MP_OBJ_NEW_SMALL_INT(lhs_val * rhs_val);
                    }
                    break;
                }
                case MP_BINARY_OP_FLOOR_DIVIDE:
                case MP_BINARY_OP_INPLACE_FLOOR_DIVIDE:
                    if (rhs_val == 0) {
                        goto zero_division;
                    }
                    lhs_val = mp_small_int_floor_divide(lhs_val, rhs_val);
                    break;

                #if MICROPY_PY_BUILTINS_FLOAT
                case MP_BINARY_OP_TRUE_DIVIDE:
                case MP_BINARY_OP_INPLACE_TRUE_DIVIDE:
                    if (rhs_val == 0) {
                        goto zero_division;
                    }
                    return mp_obj_new_float((mp_float_t)lhs_val / (mp_float_t)rhs_val);
                #endif

                case MP_BINARY_OP_MODULO:
                case MP_BINARY_OP_INPLACE_MODULO: {
                    lhs_val = mp_small_int_modulo(lhs_val, rhs_val);
                    break;
                }

                case MP_BINARY_OP_POWER:
                case MP_BINARY_OP_INPLACE_POWER:
                    if (rhs_val < 0) {
                        #if MICROPY_PY_BUILTINS_FLOAT
                        lhs = mp_obj_new_float(lhs_val);
                        goto generic_binary_op;
                        #else
                        nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "negative power with no float support"));
                        #endif
                    } else {
                        mp_int_t ans = 1;
                        while (rhs_val > 0) {
                            if (rhs_val & 1) {
                                if (mp_small_int_mul_overflow(ans, lhs_val)) {
                                    goto power_overflow;
                                }
                                ans *= lhs_val;
                            }
                            if (rhs_val == 1) {
                                break;
                            }
                            rhs_val /= 2;
                            if (mp_small_int_mul_overflow(lhs_val, lhs_val)) {
                                goto power_overflow;
                            }
                            lhs_val *= lhs_val;
                        }
                        lhs_val = ans;
                    }
                    break;

                power_overflow:
                    // use higher precision
                    lhs = mp_obj_new_int_from_ll(MP_OBJ_SMALL_INT_VALUE(lhs));
                    goto generic_binary_op;

                case MP_BINARY_OP_LESS: return MP_BOOL(lhs_val < rhs_val); break;
                case MP_BINARY_OP_MORE: return MP_BOOL(lhs_val > rhs_val); break;
                case MP_BINARY_OP_LESS_EQUAL: return MP_BOOL(lhs_val <= rhs_val); break;
                case MP_BINARY_OP_MORE_EQUAL: return MP_BOOL(lhs_val >= rhs_val); break;

                default:
                    goto unsupported_op;
            }
            // TODO: We just should make mp_obj_new_int() inline and use that
            if (MP_SMALL_INT_FITS(lhs_val)) {
                return MP_OBJ_NEW_SMALL_INT(lhs_val);
            } else {
                return mp_obj_new_int(lhs_val);
            }
#if MICROPY_PY_BUILTINS_FLOAT
        } else if (MP_OBJ_IS_TYPE(rhs, &mp_type_float)) {
            mp_obj_t res = mp_obj_float_binary_op(op, lhs_val, rhs);
            if (res == MP_OBJ_NULL) {
                goto unsupported_op;
            } else {
                return res;
            }
#if MICROPY_PY_BUILTINS_COMPLEX
        } else if (MP_OBJ_IS_TYPE(rhs, &mp_type_complex)) {
            mp_obj_t res = mp_obj_complex_binary_op(op, lhs_val, 0, rhs);
            if (res == MP_OBJ_NULL) {
                goto unsupported_op;
            } else {
                return res;
            }
#endif
#endif
        }
    }

    /* deal with `in`
     *
     * NOTE `a in b` is `b.__contains__(a)`, hence why the generic dispatch
     * needs to go below with swapped arguments
     */
    if (op == MP_BINARY_OP_IN) {
        mp_obj_type_t *type = mp_obj_get_type(rhs);
        if (type->binary_op != NULL) {
            mp_obj_t res = type->binary_op(op, rhs, lhs);
            if (res != MP_OBJ_NULL) {
                return res;
            }
        }
        if (type->getiter != NULL) {
            /* second attempt, walk the iterator */
            mp_obj_t next = NULL;
            mp_obj_t iter = mp_getiter(rhs);
            while ((next = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
                if (mp_obj_equal(next, lhs)) {
                    return mp_const_true;
                }
            }
            return mp_const_false;
        }

        nlr_raise(mp_obj_new_exception_msg_varg(
                     &mp_type_TypeError, "'%s' object is not iterable",
                     mp_obj_get_type_str(rhs)));
        return mp_const_none;
    }

    // generic binary_op supplied by type
    mp_obj_type_t *type;
generic_binary_op:
    type = mp_obj_get_type(lhs);
    if (type->binary_op != NULL) {
        mp_obj_t result = type->binary_op(op, lhs, rhs);
        if (result != MP_OBJ_NULL) {
            return result;
        }
    }

    // TODO implement dispatch for reverse binary ops

    // TODO specify in error message what the operator is
unsupported_op:
    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError,
        "unsupported operand types for binary operator: '%s', '%s'",
        mp_obj_get_type_str(lhs), mp_obj_get_type_str(rhs)));
    return mp_const_none;

zero_division:
    nlr_raise(mp_obj_new_exception_msg(&mp_type_ZeroDivisionError, "division by zero"));
}

mp_obj_t mp_call_function_0(mp_obj_t fun) {
    return mp_call_function_n_kw(fun, 0, 0, NULL);
}

mp_obj_t mp_call_function_1(mp_obj_t fun, mp_obj_t arg) {
    return mp_call_function_n_kw(fun, 1, 0, &arg);
}

mp_obj_t mp_call_function_2(mp_obj_t fun, mp_obj_t arg1, mp_obj_t arg2) {
    mp_obj_t args[2];
    args[0] = arg1;
    args[1] = arg2;
    return mp_call_function_n_kw(fun, 2, 0, args);
}

// args contains, eg: arg0  arg1  key0  value0  key1  value1
mp_obj_t mp_call_function_n_kw(mp_obj_t fun_in, mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args) {
    // TODO improve this: fun object can specify its type and we parse here the arguments,
    // passing to the function arrays of fixed and keyword arguments

    DEBUG_OP_printf("calling function %p(n_args=" UINT_FMT ", n_kw=" UINT_FMT ", args=%p)\n", fun_in, n_args, n_kw, args);

    // get the type
    mp_obj_type_t *type = mp_obj_get_type(fun_in);

    // do the call
    if (type->call != NULL) {
        return type->call(fun_in, n_args, n_kw, args);
    }

    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "'%s' object is not callable", mp_obj_get_type_str(fun_in)));
}

// args contains: fun  self/NULL  arg(0)  ...  arg(n_args-2)  arg(n_args-1)  kw_key(0)  kw_val(0)  ... kw_key(n_kw-1)  kw_val(n_kw-1)
// if n_args==0 and n_kw==0 then there are only fun and self/NULL
mp_obj_t mp_call_method_n_kw(mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args) {
    DEBUG_OP_printf("call method (fun=%p, self=%p, n_args=" UINT_FMT ", n_kw=" UINT_FMT ", args=%p)\n", args[0], args[1], n_args, n_kw, args);
    int adjust = (args[1] == NULL) ? 0 : 1;
    return mp_call_function_n_kw(args[0], n_args + adjust, n_kw, args + 2 - adjust);
}

mp_obj_t mp_call_method_n_kw_var(bool have_self, mp_uint_t n_args_n_kw, const mp_obj_t *args) {
    mp_obj_t fun = *args++;
    mp_obj_t self = MP_OBJ_NULL;
    if (have_self) {
        self = *args++; // may be MP_OBJ_NULL
    }
    uint n_args = n_args_n_kw & 0xff;
    uint n_kw = (n_args_n_kw >> 8) & 0xff;
    mp_obj_t pos_seq = args[n_args + 2 * n_kw]; // map be MP_OBJ_NULL
    mp_obj_t kw_dict = args[n_args + 2 * n_kw + 1]; // map be MP_OBJ_NULL

    DEBUG_OP_printf("call method var (fun=%p, self=%p, n_args=%u, n_kw=%u, args=%p, seq=%p, dict=%p)\n", fun, self, n_args, n_kw, args, pos_seq, kw_dict);

    // We need to create the following array of objects:
    //     args[0 .. n_args]  unpacked(pos_seq)  args[n_args .. n_args + 2 * n_kw]  unpacked(kw_dict)
    // TODO: optimize one day to avoid constructing new arg array? Will be hard.

    // The new args array
    mp_obj_t *args2;
    uint args2_alloc;
    uint args2_len = 0;

    // Try to get a hint for the size of the kw_dict
    uint kw_dict_len = 0;
    if (kw_dict != MP_OBJ_NULL && MP_OBJ_IS_TYPE(kw_dict, &mp_type_dict)) {
        kw_dict_len = mp_obj_dict_len(kw_dict);
    }

    // Extract the pos_seq sequence to the new args array.
    // Note that it can be arbitrary iterator.
    if (pos_seq == MP_OBJ_NULL) {
        // no sequence

        // allocate memory for the new array of args
        args2_alloc = 1 + n_args + 2 * (n_kw + kw_dict_len);
        args2 = m_new(mp_obj_t, args2_alloc);

        // copy the self
        if (self != MP_OBJ_NULL) {
            args2[args2_len++] = self;
        }

        // copy the fixed pos args
        mp_seq_copy(args2 + args2_len, args, n_args, mp_obj_t);
        args2_len += n_args;

    } else if (MP_OBJ_IS_TYPE(pos_seq, &mp_type_tuple) || MP_OBJ_IS_TYPE(pos_seq, &mp_type_list)) {
        // optimise the case of a tuple and list

        // get the items
        mp_uint_t len;
        mp_obj_t *items;
        mp_obj_get_array(pos_seq, &len, &items);

        // allocate memory for the new array of args
        args2_alloc = 1 + n_args + len + 2 * (n_kw + kw_dict_len);
        args2 = m_new(mp_obj_t, args2_alloc);

        // copy the self
        if (self != MP_OBJ_NULL) {
            args2[args2_len++] = self;
        }

        // copy the fixed and variable position args
        mp_seq_cat(args2 + args2_len, args, n_args, items, len, mp_obj_t);
        args2_len += n_args + len;

    } else {
        // generic iterator

        // allocate memory for the new array of args
        args2_alloc = 1 + n_args + 2 * (n_kw + kw_dict_len) + 3;
        args2 = m_new(mp_obj_t, args2_alloc);

        // copy the self
        if (self != MP_OBJ_NULL) {
            args2[args2_len++] = self;
        }

        // copy the fixed position args
        mp_seq_copy(args2 + args2_len, args, n_args, mp_obj_t);

        // extract the variable position args from the iterator
        mp_obj_t iterable = mp_getiter(pos_seq);
        mp_obj_t item;
        while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
            if (args2_len >= args2_alloc) {
                args2 = m_renew(mp_obj_t, args2, args2_alloc, args2_alloc * 2);
                args2_alloc *= 2;
            }
            args2[args2_len++] = item;
        }
    }

    // The size of the args2 array now is the number of positional args.
    uint pos_args_len = args2_len;

    // Copy the fixed kw args.
    mp_seq_copy(args2 + args2_len, args + n_args, 2 * n_kw, mp_obj_t);
    args2_len += 2 * n_kw;

    // Extract (key,value) pairs from kw_dict dictionary and append to args2.
    // Note that it can be arbitrary iterator.
    if (kw_dict == MP_OBJ_NULL) {
        // pass
    } else if (MP_OBJ_IS_TYPE(kw_dict, &mp_type_dict)) {
        // dictionary
        mp_map_t *map = mp_obj_dict_get_map(kw_dict);
        assert(args2_len + 2 * map->used <= args2_alloc); // should have enough, since kw_dict_len is in this case hinted correctly above
        for (uint i = 0; i < map->alloc; i++) {
            if (map->table[i].key != MP_OBJ_NULL) {
                args2[args2_len++] = map->table[i].key;
                args2[args2_len++] = map->table[i].value;
            }
        }
    } else {
        // generic mapping
        // TODO is calling 'items' on the mapping the correct thing to do here?
        mp_obj_t dest[2];
        mp_load_method(kw_dict, MP_QSTR_items, dest);
        mp_obj_t iterable = mp_getiter(mp_call_method_n_kw(0, 0, dest));
        mp_obj_t item;
        while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
            if (args2_len + 1 >= args2_alloc) {
                uint new_alloc = args2_alloc * 2;
                if (new_alloc < 4) {
                    new_alloc = 4;
                }
                args2 = m_renew(mp_obj_t, args2, args2_alloc, new_alloc);
                args2_alloc = new_alloc;
            }
            mp_obj_t *items;
            mp_obj_get_array_fixed_n(item, 2, &items);
            args2[args2_len++] = items[0];
            args2[args2_len++] = items[1];
        }
    }

    mp_obj_t res = mp_call_function_n_kw(fun, pos_args_len, (args2_len - pos_args_len) / 2, args2);
    m_del(mp_obj_t, args2, args2_alloc);

    return res;
}

// unpacked items are stored in reverse order into the array pointed to by items
void mp_unpack_sequence(mp_obj_t seq_in, mp_uint_t num, mp_obj_t *items) {
    mp_uint_t seq_len;
    if (MP_OBJ_IS_TYPE(seq_in, &mp_type_tuple) || MP_OBJ_IS_TYPE(seq_in, &mp_type_list)) {
        mp_obj_t *seq_items;
        if (MP_OBJ_IS_TYPE(seq_in, &mp_type_tuple)) {
            mp_obj_tuple_get(seq_in, &seq_len, &seq_items);
        } else {
            mp_obj_list_get(seq_in, &seq_len, &seq_items);
        }
        if (seq_len < num) {
            goto too_short;
        } else if (seq_len > num) {
            goto too_long;
        }
        for (mp_uint_t i = 0; i < num; i++) {
            items[i] = seq_items[num - 1 - i];
        }
    } else {
        mp_obj_t iterable = mp_getiter(seq_in);

        for (seq_len = 0; seq_len < num; seq_len++) {
            mp_obj_t el = mp_iternext(iterable);
            if (el == MP_OBJ_STOP_ITERATION) {
                goto too_short;
            }
            items[num - 1 - seq_len] = el;
        }
        if (mp_iternext(iterable) != MP_OBJ_STOP_ITERATION) {
            goto too_long;
        }
    }
    return;

too_short:
    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_ValueError, "need more than %d values to unpack", seq_len));
too_long:
    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_ValueError, "too many values to unpack (expected %d)", num));
}

// unpacked items are stored in reverse order into the array pointed to by items
void mp_unpack_ex(mp_obj_t seq_in, mp_uint_t num_in, mp_obj_t *items) {
    mp_uint_t num_left = num_in & 0xff;
    mp_uint_t num_right = (num_in >> 8) & 0xff;
    DEBUG_OP_printf("unpack ex " UINT_FMT " " UINT_FMT "\n", num_left, num_right);
    mp_uint_t seq_len;
    if (MP_OBJ_IS_TYPE(seq_in, &mp_type_tuple) || MP_OBJ_IS_TYPE(seq_in, &mp_type_list)) {
        mp_obj_t *seq_items;
        if (MP_OBJ_IS_TYPE(seq_in, &mp_type_tuple)) {
            mp_obj_tuple_get(seq_in, &seq_len, &seq_items);
        } else {
            if (num_left == 0 && num_right == 0) {
                // *a, = b # sets a to b if b is a list
                items[0] = seq_in;
                return;
            }
            mp_obj_list_get(seq_in, &seq_len, &seq_items);
        }
        if (seq_len < num_left + num_right) {
            goto too_short;
        }
        for (mp_uint_t i = 0; i < num_right; i++) {
            items[i] = seq_items[seq_len - 1 - i];
        }
        items[num_right] = mp_obj_new_list(seq_len - num_left - num_right, seq_items + num_left);
        for (mp_uint_t i = 0; i < num_left; i++) {
            items[num_right + 1 + i] = seq_items[num_left - 1 - i];
        }
    } else {
        // Generic iterable; this gets a bit messy: we unpack known left length to the
        // items destination array, then the rest to a dynamically created list.  Once the
        // iterable is exhausted, we take from this list for the right part of the items.
        // TODO Improve to waste less memory in the dynamically created list.
        mp_obj_t iterable = mp_getiter(seq_in);
        mp_obj_t item;
        for (seq_len = 0; seq_len < num_left; seq_len++) {
            item = mp_iternext(iterable);
            if (item == MP_OBJ_STOP_ITERATION) {
                goto too_short;
            }
            items[num_left + num_right + 1 - 1 - seq_len] = item;
        }
        mp_obj_list_t *rest = mp_obj_new_list(0, NULL);
        while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
            mp_obj_list_append(rest, item);
        }
        if (rest->len < num_right) {
            goto too_short;
        }
        items[num_right] = rest;
        for (mp_uint_t i = 0; i < num_right; i++) {
            items[num_right - 1 - i] = rest->items[rest->len - num_right + i];
        }
        mp_obj_list_set_len(rest, rest->len - num_right);
    }
    return;

too_short:
    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_ValueError, "need more than %d values to unpack", seq_len));
}

mp_obj_t mp_load_attr(mp_obj_t base, qstr attr) {
    DEBUG_OP_printf("load attr %p.%s\n", base, qstr_str(attr));
    // use load_method
    mp_obj_t dest[2];
    mp_load_method(base, attr, dest);
    if (dest[1] == MP_OBJ_NULL) {
        // load_method returned just a normal attribute
        return dest[0];
    } else {
        // load_method returned a method, so build a bound method object
        return mp_obj_new_bound_meth(dest[0], dest[1]);
    }
}

// no attribute found, returns:     dest[0] == MP_OBJ_NULL, dest[1] == MP_OBJ_NULL
// normal attribute found, returns: dest[0] == <attribute>, dest[1] == MP_OBJ_NULL
// method attribute found, returns: dest[0] == <method>,    dest[1] == <self>
void mp_load_method_maybe(mp_obj_t base, qstr attr, mp_obj_t *dest) {
    // clear output to indicate no attribute/method found yet
    dest[0] = MP_OBJ_NULL;
    dest[1] = MP_OBJ_NULL;

    // get the type
    mp_obj_type_t *type = mp_obj_get_type(base);

    // look for built-in names
    if (0) {
#if MICROPY_CPYTHON_COMPAT
    } else if (attr == MP_QSTR___class__) {
        // a.__class__ is equivalent to type(a)
        dest[0] = type;
#endif

    } else if (attr == MP_QSTR___next__ && type->iternext != NULL) {
        dest[0] = (mp_obj_t)&mp_builtin_next_obj;
        dest[1] = base;

    } else if (type->load_attr != NULL) {
        // this type can do its own load, so call it
        type->load_attr(base, attr, dest);

    } else if (type->locals_dict != NULL) {
        // generic method lookup
        // this is a lookup in the object (ie not class or type)
        assert(MP_OBJ_IS_TYPE(type->locals_dict, &mp_type_dict)); // Micro Python restriction, for now
        mp_map_t *locals_map = mp_obj_dict_get_map(type->locals_dict);
        mp_map_elem_t *elem = mp_map_lookup(locals_map, MP_OBJ_NEW_QSTR(attr), MP_MAP_LOOKUP);
        if (elem != NULL) {
            // check if the methods are functions, static or class methods
            // see http://docs.python.org/3/howto/descriptor.html
            if (MP_OBJ_IS_TYPE(elem->value, &mp_type_staticmethod)) {
                // return just the function
                dest[0] = ((mp_obj_static_class_method_t*)elem->value)->fun;
            } else if (MP_OBJ_IS_TYPE(elem->value, &mp_type_classmethod)) {
                // return a bound method, with self being the type of this object
                dest[0] = ((mp_obj_static_class_method_t*)elem->value)->fun;
                dest[1] = mp_obj_get_type(base);
            } else if (MP_OBJ_IS_TYPE(elem->value, &mp_type_type)) {
                // Don't try to bind types
                dest[0] = elem->value;
            } else if (mp_obj_is_callable(elem->value)) {
                // return a bound method, with self being this object
                dest[0] = elem->value;
                dest[1] = base;
            } else {
                // class member is a value, so just return that value
                dest[0] = elem->value;
            }
        }
    }
}

void mp_load_method(mp_obj_t base, qstr attr, mp_obj_t *dest) {
    DEBUG_OP_printf("load method %p.%s\n", base, qstr_str(attr));

    mp_load_method_maybe(base, attr, dest);

    if (dest[0] == MP_OBJ_NULL) {
        // no attribute/method called attr
        // following CPython, we give a more detailed error message for type objects
        if (MP_OBJ_IS_TYPE(base, &mp_type_type)) {
            nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_AttributeError,
                "type object '%s' has no attribute '%s'", qstr_str(((mp_obj_type_t*)base)->name), qstr_str(attr)));
        } else {
            nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_AttributeError, "'%s' object has no attribute '%s'", mp_obj_get_type_str(base), qstr_str(attr)));
        }
    }
}

void mp_store_attr(mp_obj_t base, qstr attr, mp_obj_t value) {
    DEBUG_OP_printf("store attr %p.%s <- %p\n", base, qstr_str(attr), value);
    mp_obj_type_t *type = mp_obj_get_type(base);
    if (type->store_attr != NULL) {
        if (type->store_attr(base, attr, value)) {
            return;
        }
    }
    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_AttributeError, "'%s' object has no attribute '%s'", mp_obj_get_type_str(base), qstr_str(attr)));
}

mp_obj_t mp_getiter(mp_obj_t o_in) {
    assert(o_in);
    mp_obj_type_t *type = mp_obj_get_type(o_in);
    if (type->getiter != NULL) {
        mp_obj_t iter = type->getiter(o_in);
        if (iter == MP_OBJ_NULL) {
            goto not_iterable;
        }
        return iter;
    } else {
        // check for __iter__ method
        mp_obj_t dest[2];
        mp_load_method_maybe(o_in, MP_QSTR___iter__, dest);
        if (dest[0] != MP_OBJ_NULL) {
            // __iter__ exists, call it and return its result
            return mp_call_method_n_kw(0, 0, dest);
        } else {
            mp_load_method_maybe(o_in, MP_QSTR___getitem__, dest);
            if (dest[0] != MP_OBJ_NULL) {
                // __getitem__ exists, create an iterator
                return mp_obj_new_getitem_iter(dest);
            } else {
                // object not iterable
not_iterable:
                nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "'%s' object is not iterable", mp_obj_get_type_str(o_in)));
            }
        }
    }
}

// may return MP_OBJ_STOP_ITERATION as an optimisation instead of raise StopIteration()
// may also raise StopIteration()
mp_obj_t mp_iternext_allow_raise(mp_obj_t o_in) {
    mp_obj_type_t *type = mp_obj_get_type(o_in);
    if (type->iternext != NULL) {
        return type->iternext(o_in);
    } else {
        // check for __next__ method
        mp_obj_t dest[2];
        mp_load_method_maybe(o_in, MP_QSTR___next__, dest);
        if (dest[0] != MP_OBJ_NULL) {
            // __next__ exists, call it and return its result
            return mp_call_method_n_kw(0, 0, dest);
        } else {
            nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "'%s' object is not an iterator", mp_obj_get_type_str(o_in)));
        }
    }
}

// will always return MP_OBJ_STOP_ITERATION instead of raising StopIteration() (or any subclass thereof)
// may raise other exceptions
mp_obj_t mp_iternext(mp_obj_t o_in) {
    mp_obj_type_t *type = mp_obj_get_type(o_in);
    if (type->iternext != NULL) {
        return type->iternext(o_in);
    } else {
        // check for __next__ method
        mp_obj_t dest[2];
        mp_load_method_maybe(o_in, MP_QSTR___next__, dest);
        if (dest[0] != MP_OBJ_NULL) {
            // __next__ exists, call it and return its result
            nlr_buf_t nlr;
            if (nlr_push(&nlr) == 0) {
                mp_obj_t ret = mp_call_method_n_kw(0, 0, dest);
                nlr_pop();
                return ret;
            } else {
                if (mp_obj_is_subclass_fast(mp_obj_get_type(nlr.ret_val), &mp_type_StopIteration)) {
                    return MP_OBJ_STOP_ITERATION;
                } else {
                    nlr_raise(nlr.ret_val);
                }
            }
        } else {
            nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "'%s' object is not an iterator", mp_obj_get_type_str(o_in)));
        }
    }
}

// TODO: Unclear what to do with StopIterarion exception here.
mp_vm_return_kind_t mp_resume(mp_obj_t self_in, mp_obj_t send_value, mp_obj_t throw_value, mp_obj_t *ret_val) {
    assert((send_value != MP_OBJ_NULL) ^ (throw_value != MP_OBJ_NULL));
    mp_obj_type_t *type = mp_obj_get_type(self_in);

    if (type == &mp_type_gen_instance) {
        return mp_obj_gen_resume(self_in, send_value, throw_value, ret_val);
    }

    if (type->iternext != NULL && send_value == mp_const_none) {
        mp_obj_t ret = type->iternext(self_in);
        if (ret != MP_OBJ_NULL) {
            *ret_val = ret;
            return MP_VM_RETURN_YIELD;
        } else {
            // Emulate raise StopIteration()
            // Special case, handled in vm.c
            *ret_val = MP_OBJ_NULL;
            return MP_VM_RETURN_NORMAL;
        }
    }

    mp_obj_t dest[3]; // Reserve slot for send() arg

    if (send_value == mp_const_none) {
        mp_load_method_maybe(self_in, MP_QSTR___next__, dest);
        if (dest[0] != MP_OBJ_NULL) {
            *ret_val = mp_call_method_n_kw(0, 0, dest);
            return MP_VM_RETURN_YIELD;
        }
    }

    if (send_value != MP_OBJ_NULL) {
        mp_load_method(self_in, MP_QSTR_send, dest);
        dest[2] = send_value;
        *ret_val = mp_call_method_n_kw(1, 0, dest);
        return MP_VM_RETURN_YIELD;
    }

    if (throw_value != MP_OBJ_NULL) {
        if (mp_obj_is_subclass_fast(mp_obj_get_type(throw_value), &mp_type_GeneratorExit)) {
            mp_load_method_maybe(self_in, MP_QSTR_close, dest);
            if (dest[0] != MP_OBJ_NULL) {
                *ret_val = mp_call_method_n_kw(0, 0, dest);
                // We assume one can't "yield" from close()
                return MP_VM_RETURN_NORMAL;
            }
        }
        mp_load_method_maybe(self_in, MP_QSTR_throw, dest);
        if (dest[0] != MP_OBJ_NULL) {
            *ret_val = mp_call_method_n_kw(1, 0, &throw_value);
            // If .throw() method returned, we assume it's value to yield
            // - any exception would be thrown with nlr_raise().
            return MP_VM_RETURN_YIELD;
        }
        // If there's nowhere to throw exception into, then we assume that object
        // is just incapable to handle it, so any exception thrown into it
        // will be propagated up. This behavior is approved by test_pep380.py
        // test_delegation_of_close_to_non_generator(),
        //  test_delegating_throw_to_non_generator()
        *ret_val = throw_value;
        return MP_VM_RETURN_EXCEPTION;
    }

    assert(0);
    return MP_VM_RETURN_NORMAL; // Should be unreachable
}

mp_obj_t mp_make_raise_obj(mp_obj_t o) {
    DEBUG_printf("raise %p\n", o);
    if (mp_obj_is_exception_type(o)) {
        // o is an exception type (it is derived from BaseException (or is BaseException))
        // create and return a new exception instance by calling o
        // TODO could have an option to disable traceback, then builtin exceptions (eg TypeError)
        // could have const instances in ROM which we return here instead
        return mp_call_function_n_kw(o, 0, 0, NULL);
    } else if (mp_obj_is_exception_instance(o)) {
        // o is an instance of an exception, so use it as the exception
        return o;
    } else {
        // o cannot be used as an exception, so return a type error (which will be raised by the caller)
        return mp_obj_new_exception_msg(&mp_type_TypeError, "exceptions must derive from BaseException");
    }
}

mp_obj_t mp_import_name(qstr name, mp_obj_t fromlist, mp_obj_t level) {
    DEBUG_printf("import name %s\n", qstr_str(name));

    // build args array
    mp_obj_t args[5];
    args[0] = MP_OBJ_NEW_QSTR(name);
    args[1] = mp_const_none; // TODO should be globals
    args[2] = mp_const_none; // TODO should be locals
    args[3] = fromlist;
    args[4] = level; // must be 0; we don't yet support other values

    // TODO lookup __import__ and call that instead of going straight to builtin implementation
    return mp_builtin___import__(5, args);
}

mp_obj_t mp_import_from(mp_obj_t module, qstr name) {
    DEBUG_printf("import from %p %s\n", module, qstr_str(name));

    mp_obj_t dest[2];

    mp_load_method_maybe(module, name, dest);

    if (dest[1] != MP_OBJ_NULL) {
        // Hopefully we can't import bound method from an object
import_error:
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_ImportError, "cannot import name %s", qstr_str(name)));
    }

    if (dest[0] != MP_OBJ_NULL) {
        return dest[0];
    }

    // See if it's a package, then can try FS import
    mp_load_method_maybe(module, MP_QSTR___path__, dest);
    if (dest[0] == MP_OBJ_NULL) {
        goto import_error;
    }

    mp_load_method_maybe(module, MP_QSTR___name__, dest);
    mp_uint_t pkg_name_len;
    const char *pkg_name = mp_obj_str_get_data(dest[0], &pkg_name_len);

    const uint dot_name_len = pkg_name_len + 1 + qstr_len(name);
    char *dot_name = alloca(dot_name_len);
    memcpy(dot_name, pkg_name, pkg_name_len);
    dot_name[pkg_name_len] = '.';
    memcpy(dot_name + pkg_name_len + 1, qstr_str(name), qstr_len(name));
    qstr dot_name_q = qstr_from_strn(dot_name, dot_name_len);

    mp_obj_t args[5];
    args[0] = MP_OBJ_NEW_QSTR(dot_name_q);
    args[1] = mp_const_none; // TODO should be globals
    args[2] = mp_const_none; // TODO should be locals
    args[3] = mp_const_true; // Pass sentinel "non empty" value to force returning of leaf module
    args[4] = MP_OBJ_NEW_SMALL_INT(0);

    // TODO lookup __import__ and call that instead of going straight to builtin implementation
    return mp_builtin___import__(5, args);
}

void mp_import_all(mp_obj_t module) {
    DEBUG_printf("import all %p\n", module);

    // TODO: Support __all__
    mp_map_t *map = mp_obj_dict_get_map(mp_obj_module_get_globals(module));
    for (uint i = 0; i < map->alloc; i++) {
        if (MP_MAP_SLOT_IS_FILLED(map, i)) {
            qstr name = MP_OBJ_QSTR_VALUE(map->table[i].key);
            if (*qstr_str(name) != '_') {
                mp_store_name(name, map->table[i].value);
            }
        }
    }
}

mp_obj_dict_t *mp_locals_get(void) {
    return dict_locals;
}

void mp_locals_set(mp_obj_dict_t *d) {
    DEBUG_OP_printf("mp_locals_set(%p)\n", d);
    dict_locals = d;
}

mp_obj_dict_t *mp_globals_get(void) {
    return dict_globals;
}

void mp_globals_set(mp_obj_dict_t *d) {
    DEBUG_OP_printf("mp_globals_set(%p)\n", d);
    dict_globals = d;
}

// this is implemented in this file so it can optimise access to locals/globals
mp_obj_t mp_parse_compile_execute(mp_lexer_t *lex, mp_parse_input_kind_t parse_input_kind, mp_obj_dict_t *globals, mp_obj_dict_t *locals) {
    // parse the string
    mp_parse_error_kind_t parse_error_kind;
    mp_parse_node_t pn = mp_parse(lex, parse_input_kind, &parse_error_kind);

    if (pn == MP_PARSE_NODE_NULL) {
        // parse error; raise exception
        mp_obj_t exc = mp_parse_make_exception(lex, parse_error_kind);
        mp_lexer_free(lex);
        nlr_raise(exc);
    }

    qstr source_name = mp_lexer_source_name(lex);
    mp_lexer_free(lex);

    // save context and set new context
    mp_obj_dict_t *old_globals = mp_globals_get();
    mp_obj_dict_t *old_locals = mp_locals_get();
    mp_globals_set(globals);
    mp_locals_set(locals);

    // compile the string
    mp_obj_t module_fun = mp_compile(pn, source_name, MP_EMIT_OPT_NONE, false);

    // check if there was a compile error
    if (mp_obj_is_exception_instance(module_fun)) {
        mp_globals_set(old_globals);
        mp_locals_set(old_locals);
        nlr_raise(module_fun);
    }

    // complied successfully, execute it
    nlr_buf_t nlr;
    if (nlr_push(&nlr) == 0) {
        mp_obj_t ret = mp_call_function_0(module_fun);
        nlr_pop();
        mp_globals_set(old_globals);
        mp_locals_set(old_locals);
        return ret;
    } else {
        // exception; restore context and re-raise same exception
        mp_globals_set(old_globals);
        mp_locals_set(old_locals);
        nlr_raise(nlr.ret_val);
    }
}

void *m_malloc_fail(size_t num_bytes) {
    DEBUG_printf("memory allocation failed, allocating " UINT_FMT " bytes\n", num_bytes);
    if (0) {
        // dummy
    #if MICROPY_ENABLE_GC
    } else if (gc_is_locked()) {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_MemoryError,
                                           "memory allocation failed, heap is locked"));
    #endif
    } else {
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_MemoryError,
                                                "memory allocation failed, allocating " UINT_FMT " bytes", num_bytes));
    }
}

NORETURN void mp_not_implemented(const char *msg) {
    nlr_raise(mp_obj_new_exception_msg(&mp_type_NotImplementedError, msg));
}
