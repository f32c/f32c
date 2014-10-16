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

#include <stdbool.h>
#include <string.h>
#include <assert.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "runtime.h"
#include "runtime0.h"
#include "builtin.h"

#if MICROPY_PY_BUILTINS_SET

typedef struct _mp_obj_set_t {
    mp_obj_base_t base;
    mp_set_t set;
} mp_obj_set_t;

typedef struct _mp_obj_set_it_t {
    mp_obj_base_t base;
    mp_obj_set_t *set;
    mp_uint_t cur;
} mp_obj_set_it_t;

STATIC mp_obj_t set_it_iternext(mp_obj_t self_in);

STATIC bool is_set_or_frozenset(mp_obj_t o) {
    return MP_OBJ_IS_TYPE(o, &mp_type_set)
#if MICROPY_PY_BUILTINS_FROZENSET
        || MP_OBJ_IS_TYPE(o, &mp_type_frozenset)
#endif
    ;
}

#if MICROPY_PY_BUILTINS_FROZENSET
STATIC void check_set_or_frozenset(mp_obj_t o) {
    if (!is_set_or_frozenset(o)) {
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "'set' object required"));
    }
}
#else
#define check_set_or_frozenset(o) check_set(o)
#endif

STATIC void check_set(mp_obj_t o) {
    if (!MP_OBJ_IS_TYPE(o, &mp_type_set)) {
        // Emulate CPython behavior
        // AttributeError: 'frozenset' object has no attribute 'add'
        #if MICROPY_PY_BUILTINS_FROZENSET
        if (MP_OBJ_IS_TYPE(o, &mp_type_frozenset)) {
            nlr_raise(mp_obj_new_exception_msg(&mp_type_AttributeError, "'frozenset' has no such attribute"));
        }
        #endif
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_TypeError, "'set' object required"));
    }
}

STATIC void set_print(void (*print)(void *env, const char *fmt, ...), void *env, mp_obj_t self_in, mp_print_kind_t kind) {
    mp_obj_set_t *self = self_in;
    #if MICROPY_PY_BUILTINS_FROZENSET
    bool is_frozen = MP_OBJ_IS_TYPE(self_in, &mp_type_frozenset);
    #endif
    if (self->set.used == 0) {
        #if MICROPY_PY_BUILTINS_FROZENSET
        if (is_frozen) {
            print(env, "frozen");
        }
        #endif
        print(env, "set()");
        return;
    }
    bool first = true;
    #if MICROPY_PY_BUILTINS_FROZENSET
    if (is_frozen) {
        print(env, "frozenset(");
    }
    #endif
    print(env, "{");
    for (mp_uint_t i = 0; i < self->set.alloc; i++) {
        if (MP_SET_SLOT_IS_FILLED(&self->set, i)) {
            if (!first) {
                print(env, ", ");
            }
            first = false;
            mp_obj_print_helper(print, env, self->set.table[i], PRINT_REPR);
        }
    }
    print(env, "}");
    #if MICROPY_PY_BUILTINS_FROZENSET
    if (is_frozen) {
        print(env, ")");
    }
    #endif
}


STATIC mp_obj_t set_make_new(mp_obj_t type_in, mp_uint_t n_args, mp_uint_t n_kw, const mp_obj_t *args) {
    mp_arg_check_num(n_args, n_kw, 0, 1, false);

    switch (n_args) {
        case 0: {
            // create a new, empty set
            mp_obj_set_t *set = mp_obj_new_set(0, NULL);
            // set actual set/frozenset type
            set->base.type = type_in;
            return set;
        }

        case 1:
        default: { // can only be 0 or 1 arg
            // 1 argument, an iterable from which we make a new set
            mp_obj_set_t *set = mp_obj_new_set(0, NULL);
            mp_obj_t iterable = mp_getiter(args[0]);
            mp_obj_t item;
            while ((item = mp_iternext(iterable)) != MP_OBJ_STOP_ITERATION) {
                mp_obj_set_store(set, item);
            }
            // Set actual set/frozenset type
            set->base.type = type_in;
            return set;
        }
    }
}

const mp_obj_type_t mp_type_set_it = {
    { &mp_type_type },
    .name = MP_QSTR_iterator,
    .getiter = mp_identity,
    .iternext = set_it_iternext,
};

STATIC mp_obj_t set_it_iternext(mp_obj_t self_in) {
    assert(MP_OBJ_IS_TYPE(self_in, &mp_type_set_it));
    mp_obj_set_it_t *self = self_in;
    mp_uint_t max = self->set->set.alloc;
    mp_set_t *set = &self->set->set;

    for (mp_uint_t i = self->cur; i < max; i++) {
        if (MP_SET_SLOT_IS_FILLED(set, i)) {
            self->cur = i + 1;
            return set->table[i];
        }
    }

    return MP_OBJ_STOP_ITERATION;
}

STATIC mp_obj_t set_getiter(mp_obj_t set_in) {
    mp_obj_set_it_t *o = m_new_obj(mp_obj_set_it_t);
    o->base.type = &mp_type_set_it;
    o->set = (mp_obj_set_t *)set_in;
    o->cur = 0;
    return o;
}


/******************************************************************************/
/* set methods                                                                */

STATIC mp_obj_t set_add(mp_obj_t self_in, mp_obj_t item) {
    check_set(self_in);
    mp_obj_set_t *self = self_in;
    mp_set_lookup(&self->set, item, MP_MAP_LOOKUP_ADD_IF_NOT_FOUND);
    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_add_obj, set_add);

STATIC mp_obj_t set_clear(mp_obj_t self_in) {
    check_set(self_in);
    mp_obj_set_t *self = self_in;

    mp_set_clear(&self->set);

    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(set_clear_obj, set_clear);

STATIC mp_obj_t set_copy_as_mutable(mp_obj_t self_in) {
    mp_obj_set_t *self = self_in;

    mp_obj_set_t *other = m_new_obj(mp_obj_set_t);
    other->base.type = &mp_type_set;
    mp_set_init(&other->set, self->set.alloc);
    other->set.used = self->set.used;
    memcpy(other->set.table, self->set.table, self->set.alloc * sizeof(mp_obj_t));

    return other;
}

STATIC mp_obj_t set_copy(mp_obj_t self_in) {
    check_set_or_frozenset(self_in);
    mp_obj_set_t *self = self_in;

    mp_obj_set_t *other = set_copy_as_mutable(self);
    other->base.type = self->base.type;

    return other;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(set_copy_obj, set_copy);

STATIC mp_obj_t set_discard(mp_obj_t self_in, mp_obj_t item) {
    check_set(self_in);
    mp_obj_set_t *self = self_in;
    mp_set_lookup(&self->set, item, MP_MAP_LOOKUP_REMOVE_IF_FOUND);
    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_discard_obj, set_discard);

STATIC mp_obj_t set_diff_int(mp_uint_t n_args, const mp_obj_t *args, bool update) {
    assert(n_args > 0);

    mp_obj_set_t *self;
    if (update) {
        check_set(args[0]);
        self = args[0];
    } else {
        check_set_or_frozenset(args[0]);
        self = set_copy_as_mutable(args[0]);
    }


    for (mp_uint_t i = 1; i < n_args; i++) {
        mp_obj_t other = args[i];
        if (self == other) {
            set_clear(self);
        } else {
            mp_obj_t iter = mp_getiter(other);
            mp_obj_t next;
            while ((next = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
                set_discard(self, next);
            }
        }
    }

    self->base.type = ((mp_obj_set_t*)args[0])->base.type;
    return self;
}

STATIC mp_obj_t set_diff(mp_uint_t n_args, const mp_obj_t *args) {
    return set_diff_int(n_args, args, false);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_VAR(set_diff_obj, 1, set_diff);

STATIC mp_obj_t set_diff_update(mp_uint_t n_args, const mp_obj_t *args) {
    set_diff_int(n_args, args, true);
    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_VAR(set_diff_update_obj, 1, set_diff_update);

STATIC mp_obj_t set_intersect_int(mp_obj_t self_in, mp_obj_t other, bool update) {
    if (update) {
        check_set(self_in);
    } else {
        check_set_or_frozenset(self_in);
    }

    if (self_in == other) {
        return update ? mp_const_none : set_copy(self_in);
    }

    mp_obj_set_t *self = self_in;
    mp_obj_set_t *out = mp_obj_new_set(0, NULL);

    mp_obj_t iter = mp_getiter(other);
    mp_obj_t next;
    while ((next = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        if (mp_set_lookup(&self->set, next, MP_MAP_LOOKUP)) {
            set_add(out, next);
        }
    }

    if (update) {
        m_del(mp_obj_t, self->set.table, self->set.alloc);
        self->set.alloc = out->set.alloc;
        self->set.used = out->set.used;
        self->set.table = out->set.table;
    }

    return update ? mp_const_none : out;
}

STATIC mp_obj_t set_intersect(mp_obj_t self_in, mp_obj_t other) {
    return set_intersect_int(self_in, other, false);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_intersect_obj, set_intersect);

STATIC mp_obj_t set_intersect_update(mp_obj_t self_in, mp_obj_t other) {
    return set_intersect_int(self_in, other, true);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_intersect_update_obj, set_intersect_update);

STATIC mp_obj_t set_isdisjoint(mp_obj_t self_in, mp_obj_t other) {
    check_set_or_frozenset(self_in);
    mp_obj_set_t *self = self_in;

    mp_obj_t iter = mp_getiter(other);
    mp_obj_t next;
    while ((next = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        if (mp_set_lookup(&self->set, next, MP_MAP_LOOKUP)) {
            return mp_const_false;
        }
    }
    return mp_const_true;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_isdisjoint_obj, set_isdisjoint);

STATIC mp_obj_t set_issubset_internal(mp_obj_t self_in, mp_obj_t other_in, bool proper) {
    mp_obj_set_t *self;
    bool cleanup_self = false;
    if (is_set_or_frozenset(self_in)) {
        self = self_in;
    } else {
        self = set_make_new((mp_obj_t)&mp_type_set, 1, 0, &self_in);
        cleanup_self = true;
    }

    mp_obj_set_t *other;
    bool cleanup_other = false;
    if (is_set_or_frozenset(other_in)) {
        other = other_in;
    } else {
        other = set_make_new((mp_obj_t)&mp_type_set, 1, 0, &other_in);
        cleanup_other = true;
    }
    bool out = true;
    if (proper && self->set.used == other->set.used) {
        out = false;
    } else {
        mp_obj_t iter = set_getiter(self);
        mp_obj_t next;
        while ((next = set_it_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
            if (!mp_set_lookup(&other->set, next, MP_MAP_LOOKUP)) {
                out = false;
                break;
            }
        }
    }
    // TODO: Should free objects altogether
    if (cleanup_self) {
        set_clear(self);
    }
    if (cleanup_other) {
        set_clear(other);
    }
    return MP_BOOL(out);
}
STATIC mp_obj_t set_issubset(mp_obj_t self_in, mp_obj_t other_in) {
    return set_issubset_internal(self_in, other_in, false);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_issubset_obj, set_issubset);

STATIC mp_obj_t set_issubset_proper(mp_obj_t self_in, mp_obj_t other_in) {
    return set_issubset_internal(self_in, other_in, true);
}

STATIC mp_obj_t set_issuperset(mp_obj_t self_in, mp_obj_t other_in) {
    return set_issubset_internal(other_in, self_in, false);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_issuperset_obj, set_issuperset);

STATIC mp_obj_t set_issuperset_proper(mp_obj_t self_in, mp_obj_t other_in) {
    return set_issubset_internal(other_in, self_in, true);
}

STATIC mp_obj_t set_equal(mp_obj_t self_in, mp_obj_t other_in) {
    check_set_or_frozenset(self_in);
    mp_obj_set_t *self = self_in;
    if (!is_set_or_frozenset(other_in)) {
        return mp_const_false;
    }
    mp_obj_set_t *other = other_in;
    if (self->set.used != other->set.used) {
        return mp_const_false;
    }
    return set_issubset(self_in, other_in);
}

STATIC mp_obj_t set_pop(mp_obj_t self_in) {
    check_set(self_in);
    mp_obj_set_t *self = self_in;
    mp_obj_t obj = mp_set_remove_first(&self->set);
    if (obj == MP_OBJ_NULL) {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_KeyError, "pop from an empty set"));
    }
    return obj;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(set_pop_obj, set_pop);

STATIC mp_obj_t set_remove(mp_obj_t self_in, mp_obj_t item) {
    check_set(self_in);
    mp_obj_set_t *self = self_in;
    if (mp_set_lookup(&self->set, item, MP_MAP_LOOKUP_REMOVE_IF_FOUND) == MP_OBJ_NULL) {
        nlr_raise(mp_obj_new_exception(&mp_type_KeyError));
    }
    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_remove_obj, set_remove);

STATIC mp_obj_t set_symmetric_difference_update(mp_obj_t self_in, mp_obj_t other_in) {
    check_set(self_in);
    mp_obj_set_t *self = self_in;
    mp_obj_t iter = mp_getiter(other_in);
    mp_obj_t next;
    while ((next = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        mp_set_lookup(&self->set, next, MP_MAP_LOOKUP_REMOVE_IF_FOUND | MP_MAP_LOOKUP_ADD_IF_NOT_FOUND);
    }
    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_symmetric_difference_update_obj, set_symmetric_difference_update);

STATIC mp_obj_t set_symmetric_difference(mp_obj_t self_in, mp_obj_t other_in) {
    check_set_or_frozenset(self_in);
    mp_obj_set_t *self_out = set_copy_as_mutable(self_in);
    set_symmetric_difference_update(self_out, other_in);
    self_out->base.type = ((mp_obj_set_t*)self_in)->base.type;
    return self_out;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_symmetric_difference_obj, set_symmetric_difference);

STATIC void set_update_int(mp_obj_set_t *self, mp_obj_t other_in) {
    mp_obj_t iter = mp_getiter(other_in);
    mp_obj_t next;
    while ((next = mp_iternext(iter)) != MP_OBJ_STOP_ITERATION) {
        mp_set_lookup(&self->set, next, MP_MAP_LOOKUP_ADD_IF_NOT_FOUND);
    }
}

STATIC mp_obj_t set_update(mp_uint_t n_args, const mp_obj_t *args) {
    assert(n_args > 0);

    for (mp_uint_t i = 1; i < n_args; i++) {
        set_update_int(args[0], args[i]);
    }

    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_VAR(set_update_obj, 1, set_update);

STATIC mp_obj_t set_union(mp_obj_t self_in, mp_obj_t other_in) {
    check_set_or_frozenset(self_in);
    mp_obj_set_t *self = set_copy(self_in);
    set_update_int(self, other_in);
    return self;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_2(set_union_obj, set_union);

STATIC mp_obj_t set_unary_op(mp_uint_t op, mp_obj_t self_in) {
    mp_obj_set_t *self = self_in;
    switch (op) {
        case MP_UNARY_OP_BOOL: return MP_BOOL(self->set.used != 0);
        case MP_UNARY_OP_LEN: return MP_OBJ_NEW_SMALL_INT(self->set.used);
        default: return MP_OBJ_NULL; // op not supported
    }
}

STATIC mp_obj_t set_binary_op(mp_uint_t op, mp_obj_t lhs, mp_obj_t rhs) {
    mp_obj_t args[] = {lhs, rhs};
    switch (op) {
        case MP_BINARY_OP_OR:
            return set_union(lhs, rhs);
        case MP_BINARY_OP_XOR:
            return set_symmetric_difference(lhs, rhs);
        case MP_BINARY_OP_AND:
            return set_intersect(lhs, rhs);
        case MP_BINARY_OP_SUBTRACT:
            return set_diff(2, args);
        case MP_BINARY_OP_INPLACE_OR:
            return set_union(lhs, rhs);
        case MP_BINARY_OP_INPLACE_XOR:
            return set_symmetric_difference(lhs, rhs);
        case MP_BINARY_OP_INPLACE_AND:
            return set_intersect(lhs, rhs);
        case MP_BINARY_OP_INPLACE_SUBTRACT:
            return set_diff(2, args);
        case MP_BINARY_OP_LESS:
            return set_issubset_proper(lhs, rhs);
        case MP_BINARY_OP_MORE:
            return set_issuperset_proper(lhs, rhs);
        case MP_BINARY_OP_EQUAL:
            return set_equal(lhs, rhs);
        case MP_BINARY_OP_LESS_EQUAL:
            return set_issubset(lhs, rhs);
        case MP_BINARY_OP_MORE_EQUAL:
            return set_issuperset(lhs, rhs);
        case MP_BINARY_OP_IN: {
            mp_obj_set_t *o = lhs;
            mp_obj_t elem = mp_set_lookup(&o->set, rhs, MP_MAP_LOOKUP);
            return MP_BOOL(elem != NULL);
        }
        default:
            return MP_OBJ_NULL; // op not supported
    }
}

/******************************************************************************/
/* set constructors & public C API                                            */


STATIC const mp_map_elem_t set_locals_dict_table[] = {
    { MP_OBJ_NEW_QSTR(MP_QSTR_add), (mp_obj_t)&set_add_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_clear), (mp_obj_t)&set_clear_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_copy), (mp_obj_t)&set_copy_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_discard), (mp_obj_t)&set_discard_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_difference), (mp_obj_t)&set_diff_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_difference_update), (mp_obj_t)&set_diff_update_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_intersection), (mp_obj_t)&set_intersect_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_intersection_update), (mp_obj_t)&set_intersect_update_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_isdisjoint), (mp_obj_t)&set_isdisjoint_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_issubset), (mp_obj_t)&set_issubset_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_issuperset), (mp_obj_t)&set_issuperset_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_pop), (mp_obj_t)&set_pop_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_remove), (mp_obj_t)&set_remove_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_symmetric_difference), (mp_obj_t)&set_symmetric_difference_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_symmetric_difference_update), (mp_obj_t)&set_symmetric_difference_update_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_union), (mp_obj_t)&set_union_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR_update), (mp_obj_t)&set_update_obj },
    { MP_OBJ_NEW_QSTR(MP_QSTR___contains__), (mp_obj_t)&mp_op_contains_obj },
};

STATIC MP_DEFINE_CONST_DICT(set_locals_dict, set_locals_dict_table);

const mp_obj_type_t mp_type_set = {
    { &mp_type_type },
    .name = MP_QSTR_set,
    .print = set_print,
    .make_new = set_make_new,
    .unary_op = set_unary_op,
    .binary_op = set_binary_op,
    .getiter = set_getiter,
    .locals_dict = (mp_obj_t)&set_locals_dict,
};

#if MICROPY_PY_BUILTINS_FROZENSET
const mp_obj_type_t mp_type_frozenset = {
    { &mp_type_type },
    .name = MP_QSTR_frozenset,
    .print = set_print,
    .make_new = set_make_new,
    .unary_op = set_unary_op,
    .binary_op = set_binary_op,
    .getiter = set_getiter,
    .locals_dict = (mp_obj_t)&set_locals_dict,
};
#endif

mp_obj_t mp_obj_new_set(mp_uint_t n_args, mp_obj_t *items) {
    mp_obj_set_t *o = m_new_obj(mp_obj_set_t);
    o->base.type = &mp_type_set;
    mp_set_init(&o->set, n_args);
    for (mp_uint_t i = 0; i < n_args; i++) {
        mp_set_lookup(&o->set, items[i], MP_MAP_LOOKUP_ADD_IF_NOT_FOUND);
    }
    return o;
}

void mp_obj_set_store(mp_obj_t self_in, mp_obj_t item) {
    assert(MP_OBJ_IS_TYPE(self_in, &mp_type_set));
    mp_obj_set_t *self = self_in;
    mp_set_lookup(&self->set, item, MP_MAP_LOOKUP_ADD_IF_NOT_FOUND);
}

#endif // MICROPY_PY_BUILTINS_SET
