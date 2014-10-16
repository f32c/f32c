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

struct _mp_lexer_t;

// a mp_parse_node_t is:
//  - 0000...0000: no node
//  - xxxx...xxx1: a small integer; bits 1 and above are the signed value, 2's complement
//  - xxxx...xx00: pointer to mp_parse_node_struct_t
//  - xx...x00010: an identifier; bits 5 and above are the qstr
//  - xx...x00110: an integer; bits 5 and above are the qstr holding the value
//  - xx...x01010: a decimal; bits 5 and above are the qstr holding the value
//  - xx...x01110: a string; bits 5 and above are the qstr holding the value
//  - xx...x10010: a string of bytes; bits 5 and above are the qstr holding the value
//  - xx...x10110: a token; bits 5 and above are mp_token_kind_t

#define MP_PARSE_NODE_NULL      (0)
#define MP_PARSE_NODE_SMALL_INT (0x1)
#define MP_PARSE_NODE_ID        (0x02)
#define MP_PARSE_NODE_INTEGER   (0x06)
#define MP_PARSE_NODE_DECIMAL   (0x0a)
#define MP_PARSE_NODE_STRING    (0x0e)
#define MP_PARSE_NODE_BYTES     (0x12)
#define MP_PARSE_NODE_TOKEN     (0x16)

typedef mp_uint_t mp_parse_node_t; // must be pointer size

typedef struct _mp_parse_node_struct_t {
    uint32_t source_line;       // line number in source file
    uint32_t kind_num_nodes;    // parse node kind, and number of nodes
    mp_parse_node_t nodes[];    // nodes
} mp_parse_node_struct_t;

// macros for mp_parse_node_t usage
// some of these evaluate their argument more than once

#define MP_PARSE_NODE_IS_NULL(pn) ((pn) == MP_PARSE_NODE_NULL)
#define MP_PARSE_NODE_IS_LEAF(pn) ((pn) & 3)
#define MP_PARSE_NODE_IS_STRUCT(pn) ((pn) != MP_PARSE_NODE_NULL && ((pn) & 3) == 0)
#define MP_PARSE_NODE_IS_STRUCT_KIND(pn, k) ((pn) != MP_PARSE_NODE_NULL && ((pn) & 3) == 0 && MP_PARSE_NODE_STRUCT_KIND((mp_parse_node_struct_t*)(pn)) == (k))

#define MP_PARSE_NODE_IS_SMALL_INT(pn) (((pn) & 0x1) == MP_PARSE_NODE_SMALL_INT)
#define MP_PARSE_NODE_IS_ID(pn) (((pn) & 0x1f) == MP_PARSE_NODE_ID)
#define MP_PARSE_NODE_IS_TOKEN(pn) (((pn) & 0x1f) == MP_PARSE_NODE_TOKEN)
#define MP_PARSE_NODE_IS_TOKEN_KIND(pn, k) ((pn) == (MP_PARSE_NODE_TOKEN | ((k) << 5)))

#define MP_PARSE_NODE_LEAF_KIND(pn) ((pn) & 0x1f)
#define MP_PARSE_NODE_LEAF_ARG(pn) (((mp_uint_t)(pn)) >> 5)
#define MP_PARSE_NODE_LEAF_SMALL_INT(pn) (((mp_int_t)(pn)) >> 1)
#define MP_PARSE_NODE_STRUCT_KIND(pns) ((pns)->kind_num_nodes & 0xff)
#define MP_PARSE_NODE_STRUCT_NUM_NODES(pns) ((pns)->kind_num_nodes >> 8)

mp_parse_node_t mp_parse_node_new_leaf(mp_int_t kind, mp_int_t arg);
void mp_parse_node_free(mp_parse_node_t pn);

void mp_parse_node_print(mp_parse_node_t pn, mp_uint_t indent);

typedef enum {
    MP_PARSE_SINGLE_INPUT,
    MP_PARSE_FILE_INPUT,
    MP_PARSE_EVAL_INPUT,
} mp_parse_input_kind_t;

typedef enum {
    MP_PARSE_ERROR_MEMORY,
    MP_PARSE_ERROR_UNEXPECTED_INDENT,
    MP_PARSE_ERROR_UNMATCHED_UNINDENT,
    MP_PARSE_ERROR_INVALID_SYNTAX,
} mp_parse_error_kind_t;

// returns MP_PARSE_NODE_NULL on error, and then parse_error_kind_out is valid
mp_parse_node_t mp_parse(struct _mp_lexer_t *lex, mp_parse_input_kind_t input_kind, mp_parse_error_kind_t *parse_error_kind_out);
