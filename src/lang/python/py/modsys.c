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

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "builtin.h"
#include "runtime.h"
#include "objlist.h"
#include "objtuple.h"
#include "objstr.h"
#include "mpz.h"
#include "objint.h"

#if MICROPY_PY_SYS

/// \module sys - system specific functions

// These two lists must be initialised per port (after the call to mp_init).
// TODO document these properly, they aren't constants or functions...
/// \constant path - a mutable list of directories to search for imported modules
mp_obj_list_t mp_sys_path_obj;
/// \constant argv - a mutable list of arguments this program started with
mp_obj_list_t mp_sys_argv_obj;

/// \constant version - Python language version that this implementation conforms to, as a string
STATIC const MP_DEFINE_STR_OBJ(version_obj, "3.4.0");

/// \constant version_info - Python language version that this implementation conforms to, as a tuple of ints
#define I(n) MP_OBJ_NEW_SMALL_INT(n)
// TODO: CPython is now at 5-element array, but save 2 els so far...
STATIC const mp_obj_tuple_t mp_sys_version_info_obj = {{&mp_type_tuple}, 3, {I(3), I(4), I(0)}};
#undef I

#ifdef MICROPY_PY_SYS_PLATFORM
/// \constant platform - the platform that Micro Python is running on
STATIC const MP_DEFINE_STR_OBJ(platform_obj, MICROPY_PY_SYS_PLATFORM);
#endif

/// \function exit([retval])
/// Raise a `SystemExit` exception.  If an argument is given, it is the
/// value given to `SystemExit`.
STATIC mp_obj_t mp_sys_exit(mp_uint_t n_args, const mp_obj_t *args) {
    mp_obj_t exc;
    if (n_args == 0) {
        exc = mp_obj_new_exception(&mp_type_SystemExit);
    } else {
        exc = mp_obj_new_exception_arg1(&mp_type_SystemExit, args[0]);
    }
    nlr_raise(exc);
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mp_sys_exit_obj, 0, 1, mp_sys_exit);

STATIC const mp_map_elem_t mp_module_sys_globals_table[] = {
    { MP_OBJ_NEW_QSTR(MP_QSTR___name__), MP_OBJ_NEW_QSTR(MP_QSTR_sys) },

    { MP_OBJ_NEW_QSTR(MP_QSTR_path), (mp_obj_t)&mp_sys_path_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_argv), (mp_obj_t)&mp_sys_argv_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_version), (mp_obj_t)&version_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_version_info), (mp_obj_t)&mp_sys_version_info_obj },
#ifdef MICROPY_PY_SYS_PLATFORM
    { MP_OBJ_NEW_QSTR(MP_QSTR_platform), (mp_obj_t)&platform_obj },
#endif
    /// \constant byteorder - the byte order of the system ("little" or "big")
#if MP_ENDIANNESS_LITTLE
    { MP_OBJ_NEW_QSTR(MP_QSTR_byteorder), MP_OBJ_NEW_QSTR(MP_QSTR_little) },
#else
    { MP_OBJ_NEW_QSTR(MP_QSTR_byteorder), MP_OBJ_NEW_QSTR(MP_QSTR_big) },
#endif
#if MICROPY_PY_SYS_MAXSIZE
    #if MICROPY_LONGINT_IMPL == MICROPY_LONGINT_IMPL_NONE
    // INT_MAX is not representable as small int, as we know that small int
    // takes one bit for tag. So, we have little choice but to provide this
    // value. Apps also should be careful to not try to compare sys.maxsize
    // with some number (which may not fit in available int size), but instead
    // count number of significant bits in sys.maxsize.
    { MP_OBJ_NEW_QSTR(MP_QSTR_maxsize), MP_OBJ_NEW_SMALL_INT(INT_MAX >> 1) },
    #else
    { MP_OBJ_NEW_QSTR(MP_QSTR_maxsize), (mp_obj_t)&mp_maxsize_obj },
    #endif
#endif

#if MICROPY_PY_SYS_EXIT
    // documented per-port
    { MP_OBJ_NEW_QSTR(MP_QSTR_exit), (mp_obj_t)&mp_sys_exit_obj },
#endif

#if MICROPY_PY_SYS_STDFILES
    // documented per-port
    { MP_OBJ_NEW_QSTR(MP_QSTR_stdin), (mp_obj_t)&mp_sys_stdin_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_stdout), (mp_obj_t)&mp_sys_stdout_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_stderr), (mp_obj_t)&mp_sys_stderr_obj },
#endif
};

STATIC const mp_obj_dict_t mp_module_sys_globals = {
    .base = {&mp_type_dict},
    .map = {
        .all_keys_are_qstrs = 1,
        .table_is_fixed_array = 1,
        .used = MP_ARRAY_SIZE(mp_module_sys_globals_table),
        .alloc = MP_ARRAY_SIZE(mp_module_sys_globals_table),
        .table = (mp_map_elem_t*)mp_module_sys_globals_table,
    },
};

const mp_obj_module_t mp_module_sys = {
    .base = { &mp_type_module },
    .name = MP_QSTR_sys,
    .globals = (mp_obj_dict_t*)&mp_module_sys_globals,
};

#endif
