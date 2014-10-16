/*
 * This file is part of the Micro Python project, http://micropython.org/
 *
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 Paul Sokolovsky
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
#include <string.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "runtime.h"
#include "binary.h"

#if MICROPY_PY_URE

#include "re1.5/re1.5.h"

#define FLAG_DEBUG 0x1000

typedef struct _mp_obj_re_t {
    mp_obj_base_t base;
    ByteProg re;
} mp_obj_re_t;

typedef struct _mp_obj_match_t {
    mp_obj_base_t base;
    int num_matches;
    mp_obj_t str;
    const char *caps[0];
} mp_obj_match_t;


STATIC void match_print(void (*print)(void *env, const char *fmt, ...), void *env, mp_obj_t self_in, mp_print_kind_t kind) {
    mp_obj_match_t *self = self_in;
    print(env, "<match num=%d @%p>", self->num_matches);
}

STATIC mp_obj_t match_group(mp_obj_t self_in, mp_obj_t no_in) {
    mp_obj_match_t *self = self_in;
    mp_int_t no = mp_obj_int_get(no_in);
    if (no < 0 || no >= self->num_matches / 2) {
        nlr_raise(mp_obj_new_exception_arg1(&mp_type_IndexError, no_in));
    }

    const char *start = self->caps[no * 2];
    return mp_obj_new_str(start, self->caps[no * 2 + 1] - start, false);
}
MP_DEFINE_CONST_FUN_OBJ_2(match_group_obj, match_group);

STATIC const mp_map_elem_t match_locals_dict_table[] = {
    { MP_OBJ_NEW_QSTR(MP_QSTR_group), (mp_obj_t) &match_group_obj },
};

STATIC MP_DEFINE_CONST_DICT(match_locals_dict, match_locals_dict_table);

STATIC const mp_obj_type_t match_type = {
    { &mp_type_type },
    .name = MP_QSTR_match,
    .print = match_print,
    .locals_dict = (mp_obj_t)&match_locals_dict,
};

STATIC void re_print(void (*print)(void *env, const char *fmt, ...), void *env, mp_obj_t self_in, mp_print_kind_t kind) {
    mp_obj_re_t *self = self_in;
    print(env, "<re %p>", self);
}

STATIC mp_obj_t re_exec(bool is_anchored, uint n_args, const mp_obj_t *args) {
    mp_obj_re_t *self = args[0];
    Subject subj;
    mp_uint_t len;
    subj.begin = mp_obj_str_get_data(args[1], &len);
    subj.end = subj.begin + len;
    int caps_num = (self->re.sub + 1) * 2;
    mp_obj_match_t *match = m_new_obj_var(mp_obj_match_t, char*, caps_num);
    int res = re1_5_recursiveloopprog(&self->re, &subj, match->caps, caps_num, is_anchored);
    if (res == 0) {
        m_del_var(mp_obj_match_t, char*, caps_num, match);
        return mp_const_none;
    }

    match->base.type = &match_type;
    match->num_matches = caps_num;
    match->str = args[1];
    return match;
}

STATIC mp_obj_t re_match(uint n_args, const mp_obj_t *args) {
    return re_exec(true, n_args, args);
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(re_match_obj, 2, 4, re_match);

STATIC mp_obj_t re_search(uint n_args, const mp_obj_t *args) {
    return re_exec(false, n_args, args);
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(re_search_obj, 2, 4, re_search);

STATIC mp_obj_t re_split(uint n_args, const mp_obj_t *args) {
    mp_obj_re_t *self = args[0];
    Subject subj;
    mp_uint_t len;
    subj.begin = mp_obj_str_get_data(args[1], &len);
    subj.end = subj.begin + len;
    int caps_num = (self->re.sub + 1) * 2;

    int maxsplit = 0;
    if (n_args > 2) {
        maxsplit = mp_obj_int_get(args[2]);
    }

    mp_obj_t retval = mp_obj_new_list(0, NULL);
    const char *caps[caps_num];
    while (true) {
        int res = re1_5_recursiveloopprog(&self->re, &subj, caps, caps_num, false);

        // if we didn't have a match, or had an empty match, it's time to stop
        if (!res || caps[0] == caps[1]) {
            break;
        }

        mp_obj_t s = mp_obj_new_str(subj.begin, caps[0] - subj.begin, false);
        mp_obj_list_append(retval, s);
        if (self->re.sub > 0) {
            mp_not_implemented("Splitting with sub-captures");
        }
        subj.begin = caps[1];
        if (maxsplit > 0 && --maxsplit == 0) {
            break;
        }
    }

    mp_obj_t s = mp_obj_new_str(subj.begin, subj.end - subj.begin, false);
    mp_obj_list_append(retval, s);
    return retval;
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(re_split_obj, 2, 3, re_split);

STATIC const mp_map_elem_t re_locals_dict_table[] = {
    { MP_OBJ_NEW_QSTR(MP_QSTR_match), (mp_obj_t) &re_match_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_search), (mp_obj_t) &re_search_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_split), (mp_obj_t) &re_split_obj },
};

STATIC MP_DEFINE_CONST_DICT(re_locals_dict, re_locals_dict_table);

STATIC const mp_obj_type_t re_type = {
    { &mp_type_type },
    .name = MP_QSTR_ure,
    .print = re_print,
    .locals_dict = (mp_obj_t)&re_locals_dict,
};

mp_obj_t mod_re_compile(uint n_args, const mp_obj_t *args) {
    const char *re_str = mp_obj_str_get_str(args[0]);
    int size = re1_5_sizecode(re_str);
    mp_obj_re_t *o = m_new_obj_var(mp_obj_re_t, char, size);
    o->base.type = &re_type;
    int flags = 0;
    if (n_args > 1) {
        flags = mp_obj_get_int(args[1]);
    }
    int error = re1_5_compilecode(&o->re, re_str);
    if (error != 0) {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "Error in regex"));
    }
    if (flags & FLAG_DEBUG) {
        re1_5_dumpcode(&o->re);
    }
    return o;
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_re_compile_obj, 1, 2, mod_re_compile);

STATIC mp_obj_t mod_re_exec(bool is_anchored, uint n_args, const mp_obj_t *args) {
    mp_obj_re_t *self = mod_re_compile(1, args);

    const mp_obj_t args2[] = {self, args[1]};
    mp_obj_match_t *match = re_exec(is_anchored, 2, args2);
    return match;
}

STATIC mp_obj_t mod_re_match(uint n_args, const mp_obj_t *args) {
    return mod_re_exec(true, n_args, args);
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_re_match_obj, 2, 4, mod_re_match);

STATIC mp_obj_t mod_re_search(uint n_args, const mp_obj_t *args) {
    return mod_re_exec(false, n_args, args);
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mod_re_search_obj, 2, 4, mod_re_search);

STATIC const mp_map_elem_t mp_module_re_globals_table[] = {
    { MP_OBJ_NEW_QSTR(MP_QSTR___name__), MP_OBJ_NEW_QSTR(MP_QSTR_ure) },
    { MP_OBJ_NEW_QSTR(MP_QSTR_compile), (mp_obj_t)&mod_re_compile_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_match), (mp_obj_t)&mod_re_match_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_search), (mp_obj_t)&mod_re_search_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_DEBUG), MP_OBJ_NEW_SMALL_INT(FLAG_DEBUG) },
};

STATIC const mp_obj_dict_t mp_module_re_globals = {
    .base = {&mp_type_dict},
    .map = {
        .all_keys_are_qstrs = 1,
        .table_is_fixed_array = 1,
        .used = MP_ARRAY_SIZE(mp_module_re_globals_table),
        .alloc = MP_ARRAY_SIZE(mp_module_re_globals_table),
        .table = (mp_map_elem_t*)mp_module_re_globals_table,
    },
};

const mp_obj_module_t mp_module_ure = {
    .base = { &mp_type_module },
    .name = MP_QSTR_ure,
    .globals = (mp_obj_dict_t*)&mp_module_re_globals,
};

// Source files #include'd here to make sure they're compiled in
// only if module is enabled by config setting.

#define re1_5_fatal(x) assert(!x)
#include "re1.5/compilecode.c"
#include "re1.5/dumpcode.c"
#include "re1.5/recursiveloop.c"
#include "re1.5/charclass.c"

#endif //MICROPY_PY_URE
