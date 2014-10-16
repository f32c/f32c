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
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

#include "mpconfig.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "parse.h"
#include "emitglue.h"
#include "scope.h"

scope_t *scope_new(scope_kind_t kind, mp_parse_node_t pn, qstr source_file, mp_uint_t emit_options) {
    scope_t *scope = m_new0(scope_t, 1);
    scope->kind = kind;
    scope->pn = pn;
    scope->source_file = source_file;
    switch (kind) {
        case SCOPE_MODULE:
            scope->simple_name = MP_QSTR__lt_module_gt_;
            break;
        case SCOPE_FUNCTION:
        case SCOPE_CLASS:
            assert(MP_PARSE_NODE_IS_STRUCT(pn));
            scope->simple_name = MP_PARSE_NODE_LEAF_ARG(((mp_parse_node_struct_t*)pn)->nodes[0]);
            break;
        case SCOPE_LAMBDA:
            scope->simple_name = MP_QSTR__lt_lambda_gt_;
            break;
        case SCOPE_LIST_COMP:
            scope->simple_name = MP_QSTR__lt_listcomp_gt_;
            break;
        case SCOPE_DICT_COMP:
            scope->simple_name = MP_QSTR__lt_dictcomp_gt_;
            break;
        case SCOPE_SET_COMP:
            scope->simple_name = MP_QSTR__lt_setcomp_gt_;
            break;
        case SCOPE_GEN_EXPR:
            scope->simple_name = MP_QSTR__lt_genexpr_gt_;
            break;
        default:
            assert(0);
    }
    scope->raw_code = mp_emit_glue_new_raw_code();
    scope->emit_options = emit_options;
    scope->id_info_alloc = MICROPY_ALLOC_SCOPE_ID_INIT;
    scope->id_info = m_new(id_info_t, scope->id_info_alloc);

    return scope;
}

void scope_free(scope_t *scope) {
    m_del(id_info_t, scope->id_info, scope->id_info_alloc);
    m_del(scope_t, scope, 1);
}

id_info_t *scope_find_or_add_id(scope_t *scope, qstr qst, bool *added) {
    id_info_t *id_info = scope_find(scope, qst);
    if (id_info != NULL) {
        *added = false;
        return id_info;
    }

    // make sure we have enough memory
    if (scope->id_info_len >= scope->id_info_alloc) {
        scope->id_info = m_renew(id_info_t, scope->id_info, scope->id_info_alloc, scope->id_info_alloc + MICROPY_ALLOC_SCOPE_ID_INC);
        scope->id_info_alloc += MICROPY_ALLOC_SCOPE_ID_INC;
    }

    // add new id to end of array of all ids; this seems to match CPython
    // important thing is that function arguments are first, but that is
    // handled by the compiler because it adds arguments before compiling the body
    id_info = &scope->id_info[scope->id_info_len++];

    id_info->kind = 0;
    id_info->flags = 0;
    id_info->local_num = 0;
    id_info->qst = qst;
    *added = true;
    return id_info;
}

id_info_t *scope_find(scope_t *scope, qstr qst) {
    for (mp_uint_t i = 0; i < scope->id_info_len; i++) {
        if (scope->id_info[i].qst == qst) {
            return &scope->id_info[i];
        }
    }
    return NULL;
}

id_info_t *scope_find_global(scope_t *scope, qstr qst) {
    while (scope->parent != NULL) {
        scope = scope->parent;
    }
    return scope_find(scope, qst);
}

id_info_t *scope_find_local_in_parent(scope_t *scope, qstr qst) {
    if (scope->parent == NULL) {
        return NULL;
    }
    for (scope_t *s = scope->parent; s->parent != NULL; s = s->parent) {
        id_info_t *id = scope_find(s, qst);
        if (id != NULL) {
            return id;
        }
    }
    return NULL;
}

void scope_close_over_in_parents(scope_t *scope, qstr qst) {
    assert(scope->parent != NULL); // we should have at least 1 parent
    for (scope_t *s = scope->parent; s->parent != NULL; s = s->parent) {
        bool added;
        id_info_t *id = scope_find_or_add_id(s, qst, &added);
        if (added) {
            // variable not previously declared in this scope, so declare it as free and keep searching parents
            id->kind = ID_INFO_KIND_FREE;
        } else {
            // variable is declared in this scope, so finish
            switch (id->kind) {
                case ID_INFO_KIND_LOCAL: id->kind = ID_INFO_KIND_CELL; break; // variable local to this scope, close it over
                case ID_INFO_KIND_FREE: break; // variable already closed over in a parent scope
                case ID_INFO_KIND_CELL: break; // variable already closed over in this scope
                default: assert(0); // TODO
            }
            return;
        }
    }
    assert(0); // we should have found the variable in one of the parents
}

void scope_declare_global(scope_t *scope, qstr qst) {
    if (scope->kind == SCOPE_MODULE) {
        printf("SyntaxError?: can't declare global in outer code\n");
        return;
    }
    bool added;
    id_info_t *id_info = scope_find_or_add_id(scope, qst, &added);
    if (!added) {
        printf("SyntaxError?: identifier already declared something\n");
        return;
    }
    id_info->kind = ID_INFO_KIND_GLOBAL_EXPLICIT;

    // if the id exists in the global scope, set its kind to EXPLICIT_GLOBAL
    id_info = scope_find_global(scope, qst);
    if (id_info != NULL) {
        id_info->kind = ID_INFO_KIND_GLOBAL_EXPLICIT;
    }
}

void scope_declare_nonlocal(scope_t *scope, qstr qst) {
    if (scope->kind == SCOPE_MODULE) {
        printf("SyntaxError?: can't declare nonlocal in outer code\n");
        return;
    }
    bool added;
    id_info_t *id_info = scope_find_or_add_id(scope, qst, &added);
    if (!added) {
        printf("SyntaxError?: identifier already declared something\n");
        return;
    }
    id_info_t *id_info2 = scope_find_local_in_parent(scope, qst);
    if (id_info2 == NULL || !(id_info2->kind == ID_INFO_KIND_LOCAL || id_info2->kind == ID_INFO_KIND_CELL || id_info2->kind == ID_INFO_KIND_FREE)) {
        printf("SyntaxError: no binding for nonlocal '%s' found\n", qstr_str(qst));
        return;
    }
    id_info->kind = ID_INFO_KIND_FREE;
    scope_close_over_in_parents(scope, qst);
}

#if MICROPY_EMIT_CPYTHON
void scope_print_info(scope_t *s) {
    if (s->kind == SCOPE_MODULE) {
        printf("code <module>\n");
    } else if (s->kind == SCOPE_LAMBDA) {
        printf("code <lambda>\n");
    } else if (s->kind == SCOPE_LIST_COMP) {
        printf("code <listcomp>\n");
    } else if (s->kind == SCOPE_DICT_COMP) {
        printf("code <dictcomp>\n");
    } else if (s->kind == SCOPE_SET_COMP) {
        printf("code <setcomp>\n");
    } else if (s->kind == SCOPE_GEN_EXPR) {
        printf("code <genexpr>\n");
    } else {
        printf("code %s\n", qstr_str(s->simple_name));
    }
    /*
    printf("var global:");
    for (int i = 0; i < s->id_info_len; i++) {
        if (s->id_info[i].kind == ID_INFO_KIND_GLOBAL_EXPLICIT) {
            printf(" %s", qstr_str(s->id_info[i].qst));
        }
    }
    printf("\n");
    printf("var name:");
    for (int i = 0; i < s->id_info_len; i++) {
        if (s->id_info[i].kind == ID_INFO_KIND_GLOBAL_IMPLICIT) {
            printf(" %s", qstr_str(s->id_info[i].qst));
        }
    }
    printf("\n");
    printf("var local:");
    for (int i = 0; i < s->id_info_len; i++) {
        if (s->id_info[i].kind == ID_INFO_KIND_LOCAL) {
            printf(" %s", qstr_str(s->id_info[i].qst));
        }
    }
    printf("\n");
    printf("var free:");
    for (int i = 0; i < s->id_info_len; i++) {
        if (s->id_info[i].kind == ID_INFO_KIND_FREE) {
            printf(" %s", qstr_str(s->id_info[i].qst));
        }
    }
    printf("\n");
    */
    printf("     flags %04x\n", s->scope_flags);
    printf("     argcount %d\n", s->num_pos_args);
    printf("     nlocals %d\n", s->num_locals);
    printf("     stacksize %d\n", s->stack_size);
}
#endif
