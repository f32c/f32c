/*
 * This file is part of the Micro Python project, http://micropython.org/
 *
 * The MIT License (MIT)
 *
 * Copyright (c) 2013, 2014 Damien P. George
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

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "mpconfig.h"
#include "nlr.h"
#include "misc.h"
#include "qstr.h"
#include "lexer.h"
#include "lexerunix.h"
#include "parse.h"
#include "obj.h"
#include "objmodule.h"
#include "parsehelper.h"
#include "compile.h"
#include "runtime0.h"
#include "runtime.h"
#include "builtin.h"
#include "builtintables.h"

#if 0 // print debugging info
#define DEBUG_PRINT (1)
#define DEBUG_printf DEBUG_printf
#else // don't print debugging info
#define DEBUG_printf(...) (void)0
#endif

#define PATH_SEP_CHAR '/'

STATIC mp_import_stat_t stat_dir_or_file(vstr_t *path) {
    //printf("stat %s\n", vstr_str(path));
    mp_import_stat_t stat = mp_import_stat(vstr_str(path));
    if (stat == MP_IMPORT_STAT_DIR) {
        return stat;
    }
    vstr_add_str(path, ".py");
    stat = mp_import_stat(vstr_str(path));
    if (stat == MP_IMPORT_STAT_FILE) {
        return stat;
    }
    return MP_IMPORT_STAT_NO_EXIST;
}

STATIC mp_import_stat_t find_file(const char *file_str, uint file_len, vstr_t *dest) {
    // extract the list of paths
    mp_uint_t path_num = 0;
    mp_obj_t *path_items;
#if MICROPY_PY_SYS
    mp_obj_list_get(mp_sys_path, &path_num, &path_items);
#endif

    if (path_num == 0) {
        // mp_sys_path is empty, so just use the given file name
        vstr_add_strn(dest, file_str, file_len);
        return stat_dir_or_file(dest);
    } else {
        // go through each path looking for a directory or file
        for (mp_uint_t i = 0; i < path_num; i++) {
            vstr_reset(dest);
            mp_uint_t p_len;
            const char *p = mp_obj_str_get_data(path_items[i], &p_len);
            if (p_len > 0) {
                vstr_add_strn(dest, p, p_len);
                vstr_add_char(dest, PATH_SEP_CHAR);
            }
            vstr_add_strn(dest, file_str, file_len);
            mp_import_stat_t stat = stat_dir_or_file(dest);
            if (stat != MP_IMPORT_STAT_NO_EXIST) {
                return stat;
            }
        }

        // could not find a directory or file
        return MP_IMPORT_STAT_NO_EXIST;
    }
}

STATIC void do_load(mp_obj_t module_obj, vstr_t *file) {
    // create the lexer
    mp_lexer_t *lex = mp_lexer_new_from_file(vstr_str(file));

    if (lex == NULL) {
        // we verified the file exists using stat, but lexer could still fail
        nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_ImportError, "No module named '%s'", vstr_str(file)));
    }

    #if MICROPY_PY___FILE__
    qstr source_name = mp_lexer_source_name(lex);
    mp_store_attr(module_obj, MP_QSTR___file__, MP_OBJ_NEW_QSTR(source_name));
    #endif

    // parse, compile and execute the module in its context
    mp_obj_dict_t *mod_globals = mp_obj_module_get_globals(module_obj);
    mp_parse_compile_execute(lex, MP_PARSE_FILE_INPUT, mod_globals, mod_globals);
}

mp_obj_t mp_builtin___import__(mp_uint_t n_args, mp_obj_t *args) {
#if DEBUG_PRINT
    DEBUG_printf("__import__:\n");
    for (mp_uint_t i = 0; i < n_args; i++) {
        DEBUG_printf("  ");
        mp_obj_print(args[i], PRINT_REPR);
        DEBUG_printf("\n");
    }
#endif

    mp_obj_t module_name = args[0];
    mp_obj_t fromtuple = mp_const_none;
    mp_int_t level = 0;
    if (n_args >= 4) {
        fromtuple = args[3];
        if (n_args >= 5) {
            level = MP_OBJ_SMALL_INT_VALUE(args[4]);
        }
    }

    mp_uint_t mod_len;
    const char *mod_str = mp_obj_str_get_data(module_name, &mod_len);

    if (level != 0) {
        // What we want to do here is to take name of current module,
        // chop <level> trailing components, and concatenate with passed-in
        // module name, thus resolving relative import name into absolue.
        // This even appears to be correct per
        // http://legacy.python.org/dev/peps/pep-0328/#relative-imports-and-name
        // "Relative imports use a module's __name__ attribute to determine that
        // module's position in the package hierarchy."
        mp_obj_t this_name_q = mp_obj_dict_get(mp_globals_get(), MP_OBJ_NEW_QSTR(MP_QSTR___name__));
        assert(this_name_q != MP_OBJ_NULL);
#if DEBUG_PRINT
        DEBUG_printf("Current module: ");
        mp_obj_print(this_name_q, PRINT_REPR);
        DEBUG_printf("\n");
#endif

        mp_uint_t this_name_l;
        const char *this_name = mp_obj_str_get_data(this_name_q, &this_name_l);

        uint dots_seen = 0;
        const char *p = this_name + this_name_l - 1;
        while (p > this_name) {
            if (*p == '.') {
                dots_seen++;
                if (--level == 0) {
                    break;
                }
            }
            p--;
        }

        if (dots_seen == 0 && level == 1) {
            // http://legacy.python.org/dev/peps/pep-0328/#relative-imports-and-name
            // "If the module's name does not contain any package information
            // (e.g. it is set to '__main__') then relative imports are
            // resolved as if the module were a top level module, regardless
            // of where the module is actually located on the file system."
            // Supposedly this if catches this condition and resolve it properly
            // TODO: But nobody knows for sure. This condition happens when
            // package's __init__.py does something like "import .submod". So,
            // maybe we should check for package here? But quote above doesn't
            // talk about packages, it talks about dot-less module names.
            p = this_name + this_name_l;
        } else if (level != 0) {
            nlr_raise(mp_obj_new_exception_msg(&mp_type_ImportError, "Invalid relative import"));
        }

        uint new_mod_l = (mod_len == 0 ? p - this_name : p - this_name + 1 + mod_len);
        char *new_mod = alloca(new_mod_l);
        memcpy(new_mod, this_name, p - this_name);
        if (mod_len != 0) {
            new_mod[p - this_name] = '.';
            memcpy(new_mod + (p - this_name) + 1, mod_str, mod_len);
        }

        qstr new_mod_q = qstr_from_strn(new_mod, new_mod_l);
        DEBUG_printf("Resolved relative name: %s\n", qstr_str(new_mod_q));
        module_name = MP_OBJ_NEW_QSTR(new_mod_q);
        mod_str = new_mod;
        mod_len = new_mod_l;
    }

    // check if module already exists
    mp_obj_t module_obj = mp_module_get(mp_obj_str_get_qstr(module_name));
    if (module_obj != MP_OBJ_NULL) {
        DEBUG_printf("Module already loaded\n");
        // If it's not a package, return module right away
        char *p = strchr(mod_str, '.');
        if (p == NULL) {
            return module_obj;
        }
        // If fromlist is not empty, return leaf module
        if (fromtuple != mp_const_none) {
            return module_obj;
        }
        // Otherwise, we need to return top-level package
        qstr pkg_name = qstr_from_strn(mod_str, p - mod_str);
        return mp_module_get(pkg_name);
    }
    DEBUG_printf("Module not yet loaded\n");

    uint last = 0;
    VSTR_FIXED(path, MICROPY_ALLOC_PATH_MAX)
    module_obj = MP_OBJ_NULL;
    mp_obj_t top_module_obj = MP_OBJ_NULL;
    mp_obj_t outer_module_obj = MP_OBJ_NULL;
    uint i;
    for (i = 1; i <= mod_len; i++) {
        if (i == mod_len || mod_str[i] == '.') {
            // create a qstr for the module name up to this depth
            qstr mod_name = qstr_from_strn(mod_str, i);
            DEBUG_printf("Processing module: %s\n", qstr_str(mod_name));
            DEBUG_printf("Previous path: %s\n", vstr_str(&path));

            // find the file corresponding to the module name
            mp_import_stat_t stat;
            if (vstr_len(&path) == 0) {
                // first module in the dotted-name; search for a directory or file
                stat = find_file(mod_str, i, &path);
            } else {
                // latter module in the dotted-name; append to path
                vstr_add_char(&path, PATH_SEP_CHAR);
                vstr_add_strn(&path, mod_str + last, i - last);
                stat = stat_dir_or_file(&path);
            }
            DEBUG_printf("Current path: %s\n", vstr_str(&path));

            if (stat == MP_IMPORT_STAT_NO_EXIST) {
                #if MICROPY_MODULE_WEAK_LINKS
                // check if there is a weak link to this module
                if (i == mod_len) {
                    mp_map_elem_t *el = mp_map_lookup((mp_map_t*)&mp_builtin_module_weak_links_dict_obj.map, MP_OBJ_NEW_QSTR(mod_name), MP_MAP_LOOKUP);
                    if (el == NULL) {
                        goto no_exist;
                    }
                    // found weak linked module
                    module_obj = el->value;
                } else {
                    no_exist:
                #else
                {
                #endif
                    // couldn't find the file, so fail
                    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_ImportError, "No module named '%s'", qstr_str(mod_name)));
                }
            } else {
                // found the file, so get the module
                module_obj = mp_module_get(mod_name);
            }

            if (module_obj == MP_OBJ_NULL) {
                // module not already loaded, so load it!

                module_obj = mp_obj_new_module(mod_name);

                if (stat == MP_IMPORT_STAT_DIR) {
                    DEBUG_printf("%s is dir\n", vstr_str(&path));
                    // https://docs.python.org/3/reference/import.html
                    // "Specifically, any module that contains a __path__ attribute is considered a package."
                    mp_store_attr(module_obj, MP_QSTR___path__, mp_obj_new_str(vstr_str(&path), vstr_len(&path), false));
                    vstr_add_char(&path, PATH_SEP_CHAR);
                    vstr_add_str(&path, "__init__.py");
                    if (mp_import_stat(vstr_str(&path)) != MP_IMPORT_STAT_FILE) {
                        vstr_cut_tail_bytes(&path, sizeof("/__init__.py") - 1); // cut off /__init__.py
                        printf("Notice: %s is imported as namespace package\n", vstr_str(&path));
                    } else {
                        do_load(module_obj, &path);
                        vstr_cut_tail_bytes(&path, sizeof("/__init__.py") - 1); // cut off /__init__.py
                    }
                } else { // MP_IMPORT_STAT_FILE
                    do_load(module_obj, &path);
                    // TODO: We cannot just break here, at the very least, we must execute
                    // trailer code below. But otherwise if there're remaining components,
                    // that would be (??) object path within module, not modules path within FS.
                    // break;
                }
            }
            if (outer_module_obj != MP_OBJ_NULL) {
                qstr s = qstr_from_strn(mod_str + last, i - last);
                mp_store_attr(outer_module_obj, s, module_obj);
            }
            outer_module_obj = module_obj;
            if (top_module_obj == MP_OBJ_NULL) {
                top_module_obj = module_obj;
            }
            last = i + 1;
        }
    }

    if (i < mod_len) {
        // we loaded a package, now need to load objects from within that package
        // TODO
        assert(0);
    }

    // If fromlist is not empty, return leaf module
    if (fromtuple != mp_const_none) {
        return module_obj;
    }
    // Otherwise, we need to return top-level package
    return top_module_obj;
}
MP_DEFINE_CONST_FUN_OBJ_VAR_BETWEEN(mp_builtin___import___obj, 1, 5, mp_builtin___import__);
