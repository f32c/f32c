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

/* lexer.c -- simple tokeniser for Python implementation
 */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <assert.h>

#include "mpconfig.h"
#include "misc.h"
#include "qstr.h"
#include "lexer.h"

#define TAB_SIZE (8)

// TODO seems that CPython allows NULL byte in the input stream
// don't know if that's intentional or not, but we don't allow it

struct _mp_lexer_t {
    qstr source_name;           // name of source
    void *stream_data;          // data for stream
    mp_lexer_stream_next_byte_t stream_next_byte;   // stream callback to get next byte
    mp_lexer_stream_close_t stream_close;           // stream callback to free

    unichar chr0, chr1, chr2;   // current cached characters from source

    mp_uint_t line;             // source line
    mp_uint_t column;           // source column

    mp_int_t emit_dent;             // non-zero when there are INDENT/DEDENT tokens to emit
    mp_int_t nested_bracket_level;  // >0 when there are nested brackets over multiple lines

    mp_uint_t alloc_indent_level;
    mp_uint_t num_indent_level;
    uint16_t *indent_level;

    vstr_t vstr;
    mp_token_t tok_cur;
};

mp_uint_t mp_optimise_value;

// TODO replace with a call to a standard function
bool str_strn_equal(const char *str, const char *strn, mp_uint_t len) {
    mp_uint_t i = 0;

    while (i < len && *str == *strn) {
        ++i;
        ++str;
        ++strn;
    }

    return i == len && *str == 0;
}

#ifdef MICROPY_DEBUG_PRINTERS
void mp_token_show(const mp_token_t *tok) {
    printf("(" UINT_FMT ":" UINT_FMT ") kind:%u str:%p len:" UINT_FMT, tok->src_line, tok->src_column, tok->kind, tok->str, tok->len);
    if (tok->str != NULL && tok->len > 0) {
        const byte *i = (const byte *)tok->str;
        const byte *j = (const byte *)i + tok->len;
        printf(" ");
        while (i < j) {
            unichar c = utf8_get_char(i);
            i = utf8_next_char(i);
            if (unichar_isprint(c)) {
                printf("%c", c);
            } else {
                printf("?");
            }
        }
    }
    printf("\n");
}
#endif

#define CUR_CHAR(lex) ((lex)->chr0)

STATIC bool is_end(mp_lexer_t *lex) {
    return lex->chr0 == MP_LEXER_EOF;
}

STATIC bool is_physical_newline(mp_lexer_t *lex) {
    return lex->chr0 == '\n' || lex->chr0 == '\r';
}

STATIC bool is_char(mp_lexer_t *lex, char c) {
    return lex->chr0 == c;
}

STATIC bool is_char_or(mp_lexer_t *lex, char c1, char c2) {
    return lex->chr0 == c1 || lex->chr0 == c2;
}

STATIC bool is_char_or3(mp_lexer_t *lex, char c1, char c2, char c3) {
    return lex->chr0 == c1 || lex->chr0 == c2 || lex->chr0 == c3;
}

/*
STATIC bool is_char_following(mp_lexer_t *lex, char c) {
    return lex->chr1 == c;
}
*/

STATIC bool is_char_following_or(mp_lexer_t *lex, char c1, char c2) {
    return lex->chr1 == c1 || lex->chr1 == c2;
}

STATIC bool is_char_following_following_or(mp_lexer_t *lex, char c1, char c2) {
    return lex->chr2 == c1 || lex->chr2 == c2;
}

STATIC bool is_char_and(mp_lexer_t *lex, char c1, char c2) {
    return lex->chr0 == c1 && lex->chr1 == c2;
}

STATIC bool is_whitespace(mp_lexer_t *lex) {
    return unichar_isspace(lex->chr0);
}

STATIC bool is_letter(mp_lexer_t *lex) {
    return unichar_isalpha(lex->chr0);
}

STATIC bool is_digit(mp_lexer_t *lex) {
    return unichar_isdigit(lex->chr0);
}

STATIC bool is_following_digit(mp_lexer_t *lex) {
    return unichar_isdigit(lex->chr1);
}

STATIC bool is_following_odigit(mp_lexer_t *lex) {
    return lex->chr1 >= '0' && lex->chr1 <= '7';
}

// TODO UNICODE include unicode characters in definition of identifiers
STATIC bool is_head_of_identifier(mp_lexer_t *lex) {
    return is_letter(lex) || lex->chr0 == '_';
}

// TODO UNICODE include unicode characters in definition of identifiers
STATIC bool is_tail_of_identifier(mp_lexer_t *lex) {
    return is_head_of_identifier(lex) || is_digit(lex);
}

STATIC void next_char(mp_lexer_t *lex) {
    if (lex->chr0 == MP_LEXER_EOF) {
        return;
    }

    mp_uint_t advance = 1;

    if (lex->chr0 == '\n') {
        // LF is a new line
        ++lex->line;
        lex->column = 1;
    } else if (lex->chr0 == '\r') {
        // CR is a new line
        ++lex->line;
        lex->column = 1;
        if (lex->chr1 == '\n') {
            // CR LF is a single new line
            advance = 2;
        }
    } else if (lex->chr0 == '\t') {
        // a tab
        lex->column = (((lex->column - 1 + TAB_SIZE) / TAB_SIZE) * TAB_SIZE) + 1;
    } else {
        // a character worth one column
        ++lex->column;
    }

    for (; advance > 0; advance--) {
        lex->chr0 = lex->chr1;
        lex->chr1 = lex->chr2;
        lex->chr2 = lex->stream_next_byte(lex->stream_data);
        if (lex->chr2 == MP_LEXER_EOF) {
            // EOF
            if (lex->chr1 != MP_LEXER_EOF && lex->chr1 != '\n' && lex->chr1 != '\r') {
                lex->chr2 = '\n'; // insert newline at end of file
            }
        }
    }
}

void indent_push(mp_lexer_t *lex, mp_uint_t indent) {
    if (lex->num_indent_level >= lex->alloc_indent_level) {
        // TODO use m_renew_maybe and somehow indicate an error if it fails... probably by using MP_TOKEN_MEMORY_ERROR
        lex->indent_level = m_renew(uint16_t, lex->indent_level, lex->alloc_indent_level, lex->alloc_indent_level + MICROPY_ALLOC_LEXEL_INDENT_INC);
        lex->alloc_indent_level += MICROPY_ALLOC_LEXEL_INDENT_INC;
    }
    lex->indent_level[lex->num_indent_level++] = indent;
}

mp_uint_t indent_top(mp_lexer_t *lex) {
    return lex->indent_level[lex->num_indent_level - 1];
}

void indent_pop(mp_lexer_t *lex) {
    lex->num_indent_level -= 1;
}

// some tricky operator encoding:
//     <op>  = begin with <op>, if this opchar matches then begin here
//     e<op> = end with <op>, if this opchar matches then end
//     E<op> = mandatory end with <op>, this opchar must match, then end
//     c<op> = continue with <op>, if this opchar matches then continue matching
// this means if the start of two ops are the same then they are equal til the last char

STATIC const char *tok_enc =
    "()[]{},:;@~" // singles
    "<e=c<e="     // < <= << <<=
    ">e=c>e="     // > >= >> >>=
    "*e=c*e="     // * *= ** **=
    "+e="         // + +=
    "-e=e>"       // - -= ->
    "&e="         // & &=
    "|e="         // | |=
    "/e=c/e="     // / /= // //=
    "%e="         // % %=
    "^e="         // ^ ^=
    "=e="         // = ==
    "!E=";        // !=

// TODO static assert that number of tokens is less than 256 so we can safely make this table with byte sized entries
STATIC const uint8_t tok_enc_kind[] = {
    MP_TOKEN_DEL_PAREN_OPEN, MP_TOKEN_DEL_PAREN_CLOSE,
    MP_TOKEN_DEL_BRACKET_OPEN, MP_TOKEN_DEL_BRACKET_CLOSE,
    MP_TOKEN_DEL_BRACE_OPEN, MP_TOKEN_DEL_BRACE_CLOSE,
    MP_TOKEN_DEL_COMMA, MP_TOKEN_DEL_COLON, MP_TOKEN_DEL_SEMICOLON, MP_TOKEN_DEL_AT, MP_TOKEN_OP_TILDE,

    MP_TOKEN_OP_LESS, MP_TOKEN_OP_LESS_EQUAL, MP_TOKEN_OP_DBL_LESS, MP_TOKEN_DEL_DBL_LESS_EQUAL,
    MP_TOKEN_OP_MORE, MP_TOKEN_OP_MORE_EQUAL, MP_TOKEN_OP_DBL_MORE, MP_TOKEN_DEL_DBL_MORE_EQUAL,
    MP_TOKEN_OP_STAR, MP_TOKEN_DEL_STAR_EQUAL, MP_TOKEN_OP_DBL_STAR, MP_TOKEN_DEL_DBL_STAR_EQUAL,
    MP_TOKEN_OP_PLUS, MP_TOKEN_DEL_PLUS_EQUAL,
    MP_TOKEN_OP_MINUS, MP_TOKEN_DEL_MINUS_EQUAL, MP_TOKEN_DEL_MINUS_MORE,
    MP_TOKEN_OP_AMPERSAND, MP_TOKEN_DEL_AMPERSAND_EQUAL,
    MP_TOKEN_OP_PIPE, MP_TOKEN_DEL_PIPE_EQUAL,
    MP_TOKEN_OP_SLASH, MP_TOKEN_DEL_SLASH_EQUAL, MP_TOKEN_OP_DBL_SLASH, MP_TOKEN_DEL_DBL_SLASH_EQUAL,
    MP_TOKEN_OP_PERCENT, MP_TOKEN_DEL_PERCENT_EQUAL,
    MP_TOKEN_OP_CARET, MP_TOKEN_DEL_CARET_EQUAL,
    MP_TOKEN_DEL_EQUAL, MP_TOKEN_OP_DBL_EQUAL,
    MP_TOKEN_OP_NOT_EQUAL,
};

// must have the same order as enum in lexer.h
STATIC const char *tok_kw[] = {
    "False",
    "None",
    "True",
    "and",
    "as",
    "assert",
    "break",
    "class",
    "continue",
    "def",
    "del",
    "elif",
    "else",
    "except",
    "finally",
    "for",
    "from",
    "global",
    "if",
    "import",
    "in",
    "is",
    "lambda",
    "nonlocal",
    "not",
    "or",
    "pass",
    "raise",
    "return",
    "try",
    "while",
    "with",
    "yield",
    "__debug__",
};

STATIC mp_uint_t hex_digit(unichar c) {
    // c is assumed to be hex digit
    mp_uint_t n = c - '0';
    if (n > 9) {
        n &= ~('a' - 'A');
        n -= ('A' - ('9' + 1));
    }
    return n;
}

// This is called with CUR_CHAR() before first hex digit, and should return with
// it pointing to last hex digit
// num_digits must be greater than zero
STATIC bool get_hex(mp_lexer_t *lex, mp_uint_t num_digits, mp_uint_t *result) {
    mp_uint_t num = 0;
    while (num_digits-- != 0) {
        next_char(lex);
        unichar c = CUR_CHAR(lex);
        if (!unichar_isxdigit(c)) {
            return false;
        }
        num = (num << 4) + hex_digit(c);
    }
    *result = num;
    return true;
}

STATIC void mp_lexer_next_token_into(mp_lexer_t *lex, mp_token_t *tok, bool first_token) {
    // skip white space and comments
    bool had_physical_newline = false;
    while (!is_end(lex)) {
        if (is_physical_newline(lex)) {
            had_physical_newline = true;
            next_char(lex);
        } else if (is_whitespace(lex)) {
            next_char(lex);
        } else if (is_char(lex, '#')) {
            next_char(lex);
            while (!is_end(lex) && !is_physical_newline(lex)) {
                next_char(lex);
            }
            // had_physical_newline will be set on next loop
        } else if (is_char(lex, '\\')) {
            // backslash (outside string literals) must appear just before a physical newline
            next_char(lex);
            if (!is_physical_newline(lex)) {
                // SyntaxError: unexpected character after line continuation character
                tok->src_line = lex->line;
                tok->src_column = lex->column;
                tok->kind = MP_TOKEN_BAD_LINE_CONTINUATION;
                vstr_reset(&lex->vstr);
                tok->str = vstr_str(&lex->vstr);
                tok->len = 0;
                return;
            } else {
                next_char(lex);
            }
        } else {
            break;
        }
    }

    // set token source information
    tok->src_line = lex->line;
    tok->src_column = lex->column;

    // start new token text
    vstr_reset(&lex->vstr);

    if (first_token && lex->line == 1 && lex->column != 1) {
        // check that the first token is in the first column
        // if first token is not on first line, we get a physical newline and
        // this check is done as part of normal indent/dedent checking below
        // (done to get equivalence with CPython)
        tok->kind = MP_TOKEN_INDENT;

    } else if (lex->emit_dent < 0) {
        tok->kind = MP_TOKEN_DEDENT;
        lex->emit_dent += 1;

    } else if (lex->emit_dent > 0) {
        tok->kind = MP_TOKEN_INDENT;
        lex->emit_dent -= 1;

    } else if (had_physical_newline && lex->nested_bracket_level == 0) {
        tok->kind = MP_TOKEN_NEWLINE;

        mp_uint_t num_spaces = lex->column - 1;
        lex->emit_dent = 0;
        if (num_spaces == indent_top(lex)) {
        } else if (num_spaces > indent_top(lex)) {
            indent_push(lex, num_spaces);
            lex->emit_dent += 1;
        } else {
            while (num_spaces < indent_top(lex)) {
                indent_pop(lex);
                lex->emit_dent -= 1;
            }
            if (num_spaces != indent_top(lex)) {
                tok->kind = MP_TOKEN_DEDENT_MISMATCH;
            }
        }

    } else if (is_end(lex)) {
        if (indent_top(lex) > 0) {
            tok->kind = MP_TOKEN_NEWLINE;
            lex->emit_dent = 0;
            while (indent_top(lex) > 0) {
                indent_pop(lex);
                lex->emit_dent -= 1;
            }
        } else {
            tok->kind = MP_TOKEN_END;
        }

    } else if (is_char_or(lex, '\'', '\"')
               || (is_char_or3(lex, 'r', 'u', 'b') && is_char_following_or(lex, '\'', '\"'))
               || ((is_char_and(lex, 'r', 'b') || is_char_and(lex, 'b', 'r')) && is_char_following_following_or(lex, '\'', '\"'))) {
        // a string or bytes literal

        // parse type codes
        bool is_raw = false;
        bool is_bytes = false;
        if (is_char(lex, 'u')) {
            next_char(lex);
        } else if (is_char(lex, 'b')) {
            is_bytes = true;
            next_char(lex);
            if (is_char(lex, 'r')) {
                is_raw = true;
                next_char(lex);
            }
        } else if (is_char(lex, 'r')) {
            is_raw = true;
            next_char(lex);
            if (is_char(lex, 'b')) {
                is_bytes = true;
                next_char(lex);
            }
        }

        // set token kind
        if (is_bytes) {
            tok->kind = MP_TOKEN_BYTES;
        } else {
            tok->kind = MP_TOKEN_STRING;
        }

        // get first quoting character
        char quote_char = '\'';
        if (is_char(lex, '\"')) {
            quote_char = '\"';
        }
        next_char(lex);

        // work out if it's a single or triple quoted literal
        mp_uint_t num_quotes;
        if (is_char_and(lex, quote_char, quote_char)) {
            // triple quotes
            next_char(lex);
            next_char(lex);
            num_quotes = 3;
        } else {
            // single quotes
            num_quotes = 1;
        }

        // parse the literal
        mp_uint_t n_closing = 0;
        while (!is_end(lex) && (num_quotes > 1 || !is_char(lex, '\n')) && n_closing < num_quotes) {
            if (is_char(lex, quote_char)) {
                n_closing += 1;
                vstr_add_char(&lex->vstr, CUR_CHAR(lex));
            } else {
                n_closing = 0;
                if (is_char(lex, '\\')) {
                    next_char(lex);
                    unichar c = CUR_CHAR(lex);
                    if (is_raw) {
                        // raw strings allow escaping of quotes, but the backslash is also emitted
                        vstr_add_char(&lex->vstr, '\\');
                    } else {
                        switch (c) {
                            case MP_LEXER_EOF: break; // TODO a proper error message?
                            case '\n': c = MP_LEXER_EOF; break; // TODO check this works correctly (we are supposed to ignore it
                            case '\\': break;
                            case '\'': break;
                            case '"': break;
                            case 'a': c = 0x07; break;
                            case 'b': c = 0x08; break;
                            case 't': c = 0x09; break;
                            case 'n': c = 0x0a; break;
                            case 'v': c = 0x0b; break;
                            case 'f': c = 0x0c; break;
                            case 'r': c = 0x0d; break;
                            case 'u':
                            case 'U':
                                if (is_bytes) {
                                    // b'\u1234' == b'\\u1234'
                                    vstr_add_char(&lex->vstr, '\\');
                                    break;
                                }
                                // Otherwise fall through.
                            case 'x':
                            {
                                mp_uint_t num = 0;
                                if (!get_hex(lex, (c == 'x' ? 2 : c == 'u' ? 4 : 8), &num)) {
                                    // TODO error message
                                    assert(0);
                                }
                                c = num;
                                break;
                            }
                            case 'N':
                                // Supporting '\N{LATIN SMALL LETTER A}' == 'a' would require keeping the
                                // entire Unicode name table in the core. As of Unicode 6.3.0, that's nearly
                                // 3MB of text; even gzip-compressed and with minimal structure, it'll take
                                // roughly half a meg of storage. This form of Unicode escape may be added
                                // later on, but it's definitely not a priority right now. -- CJA 20140607
                                assert(!"Unicode name escapes not supported");
                                break;
                            default:
                                if (c >= '0' && c <= '7') {
                                    // Octal sequence, 1-3 chars
                                    mp_uint_t digits = 3;
                                    mp_uint_t num = c - '0';
                                    while (is_following_odigit(lex) && --digits != 0) {
                                        next_char(lex);
                                        num = num * 8 + (CUR_CHAR(lex) - '0');
                                    }
                                    c = num;
                                } else {
                                    // unrecognised escape character; CPython lets this through verbatim as '\' and then the character
                                    vstr_add_char(&lex->vstr, '\\');
                                }
                                break;
                        }
                    }
                    if (c != MP_LEXER_EOF) {
                        if (c < 0x110000 && !is_bytes) {
                            vstr_add_char(&lex->vstr, c);
                        } else if (c < 0x100 && is_bytes) {
                            vstr_add_byte(&lex->vstr, c);
                        } else {
                            assert(!"TODO: Throw an error, invalid escape code probably");
                        }
                    }
                } else {
                    // Add the "character" as a byte so that we remain 8-bit clean.
                    // This way, strings are parsed correctly whether or not they contain utf-8 chars.
                    vstr_add_byte(&lex->vstr, CUR_CHAR(lex));
                }
            }
            next_char(lex);
        }

        // check we got the required end quotes
        if (n_closing < num_quotes) {
            tok->kind = MP_TOKEN_LONELY_STRING_OPEN;
        }

        // cut off the end quotes from the token text
        vstr_cut_tail_bytes(&lex->vstr, n_closing);

    } else if (is_head_of_identifier(lex)) {
        tok->kind = MP_TOKEN_NAME;

        // get first char
        vstr_add_char(&lex->vstr, CUR_CHAR(lex));
        next_char(lex);

        // get tail chars
        while (!is_end(lex) && is_tail_of_identifier(lex)) {
            vstr_add_char(&lex->vstr, CUR_CHAR(lex));
            next_char(lex);
        }

    } else if (is_digit(lex) || (is_char(lex, '.') && is_following_digit(lex))) {
        tok->kind = MP_TOKEN_NUMBER;

        // get first char
        vstr_add_char(&lex->vstr, CUR_CHAR(lex));
        next_char(lex);

        // get tail chars
        while (!is_end(lex)) {
            if (is_char_or(lex, 'e', 'E')) {
                vstr_add_char(&lex->vstr, 'e');
                next_char(lex);
                if (is_char(lex, '+') || is_char(lex, '-')) {
                    vstr_add_char(&lex->vstr, CUR_CHAR(lex));
                    next_char(lex);
                }
            } else if (is_letter(lex) || is_digit(lex) || is_char_or(lex, '_', '.')) {
                vstr_add_char(&lex->vstr, CUR_CHAR(lex));
                next_char(lex);
            } else {
                break;
            }
        }

    } else if (is_char(lex, '.')) {
        // special handling for . and ... operators, because .. is not a valid operator

        // get first char
        vstr_add_char(&lex->vstr, '.');
        next_char(lex);

        if (is_char_and(lex, '.', '.')) {
            vstr_add_char(&lex->vstr, '.');
            vstr_add_char(&lex->vstr, '.');
            next_char(lex);
            next_char(lex);
            tok->kind = MP_TOKEN_ELLIPSIS;
        } else {
            tok->kind = MP_TOKEN_DEL_PERIOD;
        }

    } else {
        // search for encoded delimiter or operator

        const char *t = tok_enc;
        mp_uint_t tok_enc_index = 0;
        for (; *t != 0 && !is_char(lex, *t); t += 1) {
            if (*t == 'e' || *t == 'c') {
                t += 1;
            } else if (*t == 'E') {
                tok_enc_index -= 1;
                t += 1;
            }
            tok_enc_index += 1;
        }

        next_char(lex);

        if (*t == 0) {
            // didn't match any delimiter or operator characters
            tok->kind = MP_TOKEN_INVALID;

        } else {
            // matched a delimiter or operator character

            // get the maximum characters for a valid token
            t += 1;
            mp_uint_t t_index = tok_enc_index;
            for (;;) {
                for (; *t == 'e'; t += 1) {
                    t += 1;
                    t_index += 1;
                    if (is_char(lex, *t)) {
                        next_char(lex);
                        tok_enc_index = t_index;
                        break;
                    }
                }

                if (*t == 'E') {
                    t += 1;
                    if (is_char(lex, *t)) {
                        next_char(lex);
                        tok_enc_index = t_index;
                    } else {
                        tok->kind = MP_TOKEN_INVALID;
                        goto tok_enc_no_match;
                    }
                    break;
                }

                if (*t == 'c') {
                    t += 1;
                    t_index += 1;
                    if (is_char(lex, *t)) {
                        next_char(lex);
                        tok_enc_index = t_index;
                        t += 1;
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            }

            // set token kind
            tok->kind = tok_enc_kind[tok_enc_index];

            tok_enc_no_match:

            // compute bracket level for implicit line joining
            if (tok->kind == MP_TOKEN_DEL_PAREN_OPEN || tok->kind == MP_TOKEN_DEL_BRACKET_OPEN || tok->kind == MP_TOKEN_DEL_BRACE_OPEN) {
                lex->nested_bracket_level += 1;
            } else if (tok->kind == MP_TOKEN_DEL_PAREN_CLOSE || tok->kind == MP_TOKEN_DEL_BRACKET_CLOSE || tok->kind == MP_TOKEN_DEL_BRACE_CLOSE) {
                lex->nested_bracket_level -= 1;
            }
        }
    }

    // point token text to vstr buffer
    tok->str = vstr_str(&lex->vstr);
    tok->len = vstr_len(&lex->vstr);

    // check for keywords
    if (tok->kind == MP_TOKEN_NAME) {
        // We check for __debug__ here and convert it to its value.  This is so
        // the parser gives a syntax error on, eg, x.__debug__.  Otherwise, we
        // need to check for this special token in many places in the compiler.
        // TODO improve speed of these string comparisons
        //for (mp_int_t i = 0; tok_kw[i] != NULL; i++) {
        for (mp_int_t i = 0; i < MP_ARRAY_SIZE(tok_kw); i++) {
            if (str_strn_equal(tok_kw[i], tok->str, tok->len)) {
                if (i == MP_ARRAY_SIZE(tok_kw) - 1) {
                    // tok_kw[MP_ARRAY_SIZE(tok_kw) - 1] == "__debug__"
                    tok->kind = (mp_optimise_value == 0 ? MP_TOKEN_KW_TRUE : MP_TOKEN_KW_FALSE);
                } else {
                    tok->kind = MP_TOKEN_KW_FALSE + i;
                }
                break;
            }
        }
    }
}

mp_lexer_t *mp_lexer_new(qstr src_name, void *stream_data, mp_lexer_stream_next_byte_t stream_next_byte, mp_lexer_stream_close_t stream_close) {
    mp_lexer_t *lex = m_new_obj_maybe(mp_lexer_t);

    // check for memory allocation error
    if (lex == NULL) {
        if (stream_close) {
            stream_close(stream_data);
        }
        return NULL;
    }

    lex->source_name = src_name;
    lex->stream_data = stream_data;
    lex->stream_next_byte = stream_next_byte;
    lex->stream_close = stream_close;
    lex->line = 1;
    lex->column = 1;
    lex->emit_dent = 0;
    lex->nested_bracket_level = 0;
    lex->alloc_indent_level = MICROPY_ALLOC_LEXER_INDENT_INIT;
    lex->num_indent_level = 1;
    lex->indent_level = m_new_maybe(uint16_t, lex->alloc_indent_level);
    vstr_init(&lex->vstr, 32);

    // check for memory allocation error
    if (lex->indent_level == NULL || vstr_had_error(&lex->vstr)) {
        mp_lexer_free(lex);
        return NULL;
    }

    // store sentinel for first indentation level
    lex->indent_level[0] = 0;

    // preload characters
    lex->chr0 = stream_next_byte(stream_data);
    lex->chr1 = stream_next_byte(stream_data);
    lex->chr2 = stream_next_byte(stream_data);

    // if input stream is 0, 1 or 2 characters long and doesn't end in a newline, then insert a newline at the end
    if (lex->chr0 == MP_LEXER_EOF) {
        lex->chr0 = '\n';
    } else if (lex->chr1 == MP_LEXER_EOF) {
        if (lex->chr0 != '\n' && lex->chr0 != '\r') {
            lex->chr1 = '\n';
        }
    } else if (lex->chr2 == MP_LEXER_EOF) {
        if (lex->chr1 != '\n' && lex->chr1 != '\r') {
            lex->chr2 = '\n';
        }
    }

    // preload first token
    mp_lexer_next_token_into(lex, &lex->tok_cur, true);

    return lex;
}

void mp_lexer_free(mp_lexer_t *lex) {
    if (lex) {
        if (lex->stream_close) {
            lex->stream_close(lex->stream_data);
        }
        vstr_clear(&lex->vstr);
        m_del(uint16_t, lex->indent_level, lex->alloc_indent_level);
        m_del_obj(mp_lexer_t, lex);
    }
}

qstr mp_lexer_source_name(mp_lexer_t *lex) {
    return lex->source_name;
}

void mp_lexer_to_next(mp_lexer_t *lex) {
    mp_lexer_next_token_into(lex, &lex->tok_cur, false);
}

const mp_token_t *mp_lexer_cur(const mp_lexer_t *lex) {
    return &lex->tok_cur;
}

bool mp_lexer_is_kind(mp_lexer_t *lex, mp_token_kind_t kind) {
    return lex->tok_cur.kind == kind;
}
