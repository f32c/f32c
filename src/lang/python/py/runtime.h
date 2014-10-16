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

typedef enum {
    MP_VM_RETURN_NORMAL,
    MP_VM_RETURN_YIELD,
    MP_VM_RETURN_EXCEPTION,
} mp_vm_return_kind_t;

typedef enum {
    MP_ARG_BOOL      = 0x001,
    MP_ARG_INT       = 0x002,
    MP_ARG_OBJ       = 0x003,
    MP_ARG_KIND_MASK = 0x0ff,
    MP_ARG_REQUIRED  = 0x100,
    MP_ARG_KW_ONLY   = 0x200,
} mp_arg_flag_t;

typedef union _mp_arg_val_t {
    bool u_bool;
    mp_int_t u_int;
    mp_obj_t u_obj;
} mp_arg_val_t;

typedef struct _mp_arg_t {
    qstr qstr;
    mp_uint_t flags;
    mp_arg_val_t defval;
} mp_arg_t;

void mp_init(void);
void mp_deinit(void);

void mp_arg_check_num(mp_uint_t n_args, mp_uint_t n_kw, mp_uint_t n_args_min, mp_uint_t n_args_max, bool takes_kw);
void mp_arg_parse_all(mp_uint_t n_pos, const mp_obj_t *pos, mp_map_t *kws, mp_uint_t n_allowed, const mp_arg_t *allowed, mp_arg_val_t *out_vals);
void mp_arg_parse_all_kw_array(mp_uint_t n_pos, mp_uint_t n_kw, const mp_obj_t *args, mp_uint_t n_allowed, const mp_arg_t *allowed, mp_arg_val_t *out_vals);
NORETURN void mp_arg_error_unimpl_kw(void);

mp_obj_dict_t *mp_locals_get(void);
void mp_locals_set(mp_obj_dict_t *d);
mp_obj_dict_t *mp_globals_get(void);
void mp_globals_set(mp_obj_dict_t *d);

mp_obj_t mp_load_name(qstr qstr);
mp_obj_t mp_load_global(qstr qstr);
mp_obj_t mp_load_build_class(void);
void mp_store_name(qstr qstr, mp_obj_t obj);
void mp_store_global(qstr qstr, mp_obj_t obj);
void mp_delete_name(qstr qstr);
void mp_delete_global(qstr qstr);

mp_obj_t mp_unary_op(mp_uint_t op, mp_obj_t arg);
mp_obj_t mp_binary_op(mp_uint_t op, mp_obj_t lhs, mp_obj_t rhs);

mp_obj_t mp_load_const_int(qstr qstr);
mp_obj_t mp_load_const_dec(qstr qstr);
mp_obj_t mp_load_const_str(qstr qstr);
mp_obj_t mp_load_const_bytes(qstr qstr);

mp_obj_t mp_call_function_0(mp_obj_t fun);
mp_obj_t mp_call_function_1(mp_obj_t fun, mp_obj_t arg);
mp_obj_t mp_call_function_2(mp_obj_t fun, mp_obj_t arg1, mp_obj_t arg2);
mp_obj_t mp_call_function_n_kw(mp_obj_t fun, mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args);
mp_obj_t mp_call_method_n_kw(mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args);
mp_obj_t mp_call_method_n_kw_var(bool have_self, mp_uint_t n_args_n_kw, const mp_obj_t *args);

void mp_unpack_sequence(mp_obj_t seq, mp_uint_t num, mp_obj_t *items);
void mp_unpack_ex(mp_obj_t seq, mp_uint_t num, mp_obj_t *items);
mp_obj_t mp_store_map(mp_obj_t map, mp_obj_t key, mp_obj_t value);
mp_obj_t mp_load_attr(mp_obj_t base, qstr attr);
void mp_load_method(mp_obj_t base, qstr attr, mp_obj_t *dest);
void mp_load_method_maybe(mp_obj_t base, qstr attr, mp_obj_t *dest);
void mp_store_attr(mp_obj_t base, qstr attr, mp_obj_t val);

mp_obj_t mp_getiter(mp_obj_t o);
mp_obj_t mp_iternext_allow_raise(mp_obj_t o); // may return MP_OBJ_STOP_ITERATION instead of raising StopIteration()
mp_obj_t mp_iternext(mp_obj_t o); // will always return MP_OBJ_STOP_ITERATION instead of raising StopIteration(...)
mp_vm_return_kind_t mp_resume(mp_obj_t self_in, mp_obj_t send_value, mp_obj_t throw_value, mp_obj_t *ret_val);

mp_obj_t mp_make_raise_obj(mp_obj_t o);

mp_map_t *mp_loaded_modules_get(void);
mp_obj_t mp_import_name(qstr name, mp_obj_t fromlist, mp_obj_t level);
mp_obj_t mp_import_from(mp_obj_t module, qstr name);
void mp_import_all(mp_obj_t module);

// Raise NotImplementedError with given message
NORETURN void mp_not_implemented(const char *msg);

// helper functions for native/viper code
mp_uint_t mp_convert_obj_to_native(mp_obj_t obj, mp_uint_t type);
mp_obj_t mp_convert_native_to_obj(mp_uint_t val, mp_uint_t type);
mp_obj_t mp_native_call_function_n_kw(mp_obj_t fun_in, mp_uint_t n_args_kw, const mp_obj_t *args);
NORETURN void mp_native_raise(mp_obj_t o);

extern struct _mp_obj_list_t mp_sys_path_obj;
extern struct _mp_obj_list_t mp_sys_argv_obj;
#define mp_sys_path ((mp_obj_t)&mp_sys_path_obj)
#define mp_sys_argv ((mp_obj_t)&mp_sys_argv_obj)
