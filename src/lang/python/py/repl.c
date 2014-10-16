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

#include "mpconfig.h"
#include "misc.h"
#include "repl.h"

#if MICROPY_HELPER_REPL

bool str_startswith_word(const char *str, const char *head) {
    mp_uint_t i;
    for (i = 0; str[i] && head[i]; i++) {
        if (str[i] != head[i]) {
            return false;
        }
    }
    return head[i] == '\0' && (str[i] == '\0' || !unichar_isalpha(str[i]));
}

bool mp_repl_continue_with_input(const char *input) {
    // check for blank input
    if (input[0] == '\0') {
        return false;
    }

    // check if input starts with a certain keyword
    bool starts_with_compound_keyword =
           input[0] == '@'
        || str_startswith_word(input, "if")
        || str_startswith_word(input, "while")
        || str_startswith_word(input, "for")
        || str_startswith_word(input, "try")
        || str_startswith_word(input, "with")
        || str_startswith_word(input, "def")
        || str_startswith_word(input, "class")
        ;

    // check for unmatched open bracket or triple quote
    // TODO don't look at triple quotes inside single quotes
    int n_paren = 0;
    int n_brack = 0;
    int n_brace = 0;
    int in_triple_quote = 0;
    const char *i;
    for (i = input; *i; i++) {
        switch (*i) {
            case '(': n_paren += 1; break;
            case ')': n_paren -= 1; break;
            case '[': n_brack += 1; break;
            case ']': n_brack -= 1; break;
            case '{': n_brace += 1; break;
            case '}': n_brace -= 1; break;
            case '\'':
                if (in_triple_quote != '"' && i[1] == '\'' && i[2] == '\'') {
                    i += 2;
                    in_triple_quote = '\'' - in_triple_quote;
                }
                break;
            case '"':
                if (in_triple_quote != '\'' && i[1] == '"' && i[2] == '"') {
                    i += 2;
                    in_triple_quote = '"' - in_triple_quote;
                }
                break;
        }
    }

    // continue if unmatched brackets or quotes
    if (n_paren > 0 || n_brack > 0 || n_brace > 0 || in_triple_quote != 0) {
        return true;
    }

    // continue if last character was backslash (for line continuation)
    if (i[-1] == '\\') {
        return true;
    }

    // continue if compound keyword and last line was not empty
    if (starts_with_compound_keyword && i[-1] != '\n') {
        return true;
    }

    // otherwise, don't continue
    return false;
}

#endif // MICROPY_HELPER_REPL
