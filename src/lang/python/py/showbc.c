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

#include <stdio.h>
#include <assert.h>

#include "mpconfig.h"
#include "misc.h"
#include "qstr.h"
#include "obj.h"
#include "runtime.h"
#include "bc0.h"
#include "bc.h"

#if MICROPY_DEBUG_PRINTERS

#define DECODE_UINT { \
    unum = 0; \
    do { \
        unum = (unum << 7) + (*ip & 0x7f); \
    } while ((*ip++ & 0x80) != 0); \
}
#define DECODE_ULABEL do { unum = (ip[0] | (ip[1] << 8)); ip += 2; } while (0)
#define DECODE_SLABEL do { unum = (ip[0] | (ip[1] << 8)) - 0x8000; ip += 2; } while (0)
#define DECODE_QSTR { \
    qstr = 0; \
    do { \
        qstr = (qstr << 7) + (*ip & 0x7f); \
    } while ((*ip++ & 0x80) != 0); \
}
#define DECODE_PTR do { \
    ip = (byte*)(((mp_uint_t)ip + sizeof(mp_uint_t) - 1) & (~(sizeof(mp_uint_t) - 1))); /* align ip */ \
    unum = *(mp_uint_t*)ip; \
    ip += sizeof(mp_uint_t); \
} while (0)

void mp_bytecode_print(const void *descr, const byte *ip, mp_uint_t len) {
    const byte *ip_start = ip;

    // get code info size
    const byte *code_info = ip;
    mp_uint_t code_info_size = mp_decode_uint(&code_info);
    ip += code_info_size;

    qstr block_name = mp_decode_uint(&code_info);
    qstr source_file = mp_decode_uint(&code_info);
    printf("File %s, code block '%s' (descriptor: %p, bytecode @%p " UINT_FMT " bytes)\n",
        qstr_str(source_file), qstr_str(block_name), descr, code_info, len);

    // bytecode prelude: state size and exception stack size; 16 bit uints
    {
        uint n_state = mp_decode_uint(&ip);
        uint n_exc_stack = mp_decode_uint(&ip);
        printf("(N_STATE %u)\n", n_state);
        printf("(N_EXC_STACK %u)\n", n_exc_stack);
    }

    // bytecode prelude: initialise closed over variables
    {
        uint n_local = *ip++;
        printf("(NUM_LOCAL %u)\n", n_local);
        for (; n_local > 0; n_local--) {
            uint local_num = *ip++;
            printf("(INIT_CELL %u)\n", local_num);
        }
        len -= ip - ip_start;
        ip_start = ip;
    }

    // print out line number info
    {
        mp_int_t bc = (code_info + code_info_size) - ip;
        mp_uint_t source_line = 1;
        printf("  bc=" INT_FMT " line=" UINT_FMT "\n", bc, source_line);
        for (const byte* ci = code_info + 12; *ci;) {
            if ((ci[0] & 0x80) == 0) {
                // 0b0LLBBBBB encoding
                bc += ci[0] & 0x1f;
                source_line += ci[0] >> 5;
                ci += 1;
            } else {
                // 0b1LLLBBBB 0bLLLLLLLL encoding (l's LSB in second byte)
                bc += ci[0] & 0xf;
                source_line += ((ci[0] << 4) & 0x700) | ci[1];
                ci += 2;
            }
            printf("  bc=" INT_FMT " line=" UINT_FMT "\n", bc, source_line);
        }
    }
    mp_bytecode_print2(ip, len - 0);
}

void mp_bytecode_print2(const byte *ip, mp_uint_t len) {
    const byte *ip_start = ip;
    mp_uint_t unum;
    qstr qstr;
    while (ip - ip_start < len) {
        printf("%02u ", (uint)(ip - ip_start));
        switch (*ip++) {
            case MP_BC_LOAD_CONST_FALSE:
                printf("LOAD_CONST_FALSE");
                break;

            case MP_BC_LOAD_CONST_NONE:
                printf("LOAD_CONST_NONE");
                break;

            case MP_BC_LOAD_CONST_TRUE:
                printf("LOAD_CONST_TRUE");
                break;

            case MP_BC_LOAD_CONST_ELLIPSIS:
                printf("LOAD_CONST_ELLIPSIS");
                break;

            case MP_BC_LOAD_CONST_SMALL_INT: {
                mp_int_t num = 0;
                if ((ip[0] & 0x40) != 0) {
                    // Number is negative
                    num--;
                }
                do {
                    num = (num << 7) | (*ip & 0x7f);
                } while ((*ip++ & 0x80) != 0);
                printf("LOAD_CONST_SMALL_INT " INT_FMT, num);
                break;
            }

            case MP_BC_LOAD_CONST_INT:
                DECODE_QSTR;
                printf("LOAD_CONST_INT %s", qstr_str(qstr));
                break;

            case MP_BC_LOAD_CONST_DEC:
                DECODE_QSTR;
                printf("LOAD_CONST_DEC %s", qstr_str(qstr));
                break;

            case MP_BC_LOAD_CONST_BYTES:
                DECODE_QSTR;
                printf("LOAD_CONST_BYTES %s", qstr_str(qstr));
                break;

            case MP_BC_LOAD_CONST_STRING:
                DECODE_QSTR;
                printf("LOAD_CONST_STRING '%s'", qstr_str(qstr));
                break;

            case MP_BC_LOAD_NULL:
                printf("LOAD_NULL");
                break;

            case MP_BC_LOAD_FAST_0:
                printf("LOAD_FAST_0");
                break;

            case MP_BC_LOAD_FAST_1:
                printf("LOAD_FAST_1");
                break;

            case MP_BC_LOAD_FAST_2:
                printf("LOAD_FAST_2");
                break;

            case MP_BC_LOAD_FAST_N:
                DECODE_UINT;
                printf("LOAD_FAST_N " UINT_FMT, unum);
                break;

            case MP_BC_LOAD_DEREF:
                DECODE_UINT;
                printf("LOAD_DEREF " UINT_FMT, unum);
                break;

            case MP_BC_LOAD_NAME:
                DECODE_QSTR;
                printf("LOAD_NAME %s", qstr_str(qstr));
                break;

            case MP_BC_LOAD_GLOBAL:
                DECODE_QSTR;
                printf("LOAD_GLOBAL %s", qstr_str(qstr));
                break;

            case MP_BC_LOAD_ATTR:
                DECODE_QSTR;
                printf("LOAD_ATTR %s", qstr_str(qstr));
                break;

            case MP_BC_LOAD_METHOD:
                DECODE_QSTR;
                printf("LOAD_METHOD %s", qstr_str(qstr));
                break;

            case MP_BC_LOAD_BUILD_CLASS:
                printf("LOAD_BUILD_CLASS");
                break;

            case MP_BC_LOAD_SUBSCR:
                printf("LOAD_SUBSCR");
                break;

            case MP_BC_STORE_FAST_0:
                printf("STORE_FAST_0");
                break;

            case MP_BC_STORE_FAST_1:
                printf("STORE_FAST_1");
                break;

            case MP_BC_STORE_FAST_2:
                printf("STORE_FAST_2");
                break;

            case MP_BC_STORE_FAST_N:
                DECODE_UINT;
                printf("STORE_FAST_N " UINT_FMT, unum);
                break;

            case MP_BC_STORE_DEREF:
                DECODE_UINT;
                printf("STORE_DEREF " UINT_FMT, unum);
                break;

            case MP_BC_STORE_NAME:
                DECODE_QSTR;
                printf("STORE_NAME %s", qstr_str(qstr));
                break;

            case MP_BC_STORE_GLOBAL:
                DECODE_QSTR;
                printf("STORE_GLOBAL %s", qstr_str(qstr));
                break;

            case MP_BC_STORE_ATTR:
                DECODE_QSTR;
                printf("STORE_ATTR %s", qstr_str(qstr));
                break;

            case MP_BC_STORE_SUBSCR:
                printf("STORE_SUBSCR");
                break;

            case MP_BC_DELETE_FAST:
                DECODE_UINT;
                printf("DELETE_FAST " UINT_FMT, unum);
                break;

            case MP_BC_DELETE_DEREF:
                DECODE_UINT;
                printf("DELETE_DEREF " UINT_FMT, unum);
                break;

            case MP_BC_DELETE_NAME:
                DECODE_QSTR;
                printf("DELETE_NAME %s", qstr_str(qstr));
                break;

            case MP_BC_DUP_TOP:
                printf("DUP_TOP");
                break;

            case MP_BC_DUP_TOP_TWO:
                printf("DUP_TOP_TWO");
                break;

            case MP_BC_POP_TOP:
                printf("POP_TOP");
                break;

            case MP_BC_ROT_TWO:
                printf("ROT_TWO");
                break;

            case MP_BC_ROT_THREE:
                printf("ROT_THREE");
                break;

            case MP_BC_JUMP:
                DECODE_SLABEL;
                printf("JUMP " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_POP_JUMP_IF_TRUE:
                DECODE_SLABEL;
                printf("POP_JUMP_IF_TRUE " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_POP_JUMP_IF_FALSE:
                DECODE_SLABEL;
                printf("POP_JUMP_IF_FALSE " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_JUMP_IF_TRUE_OR_POP:
                DECODE_SLABEL;
                printf("JUMP_IF_TRUE_OR_POP " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_JUMP_IF_FALSE_OR_POP:
                DECODE_SLABEL;
                printf("JUMP_IF_FALSE_OR_POP " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_SETUP_WITH:
                DECODE_ULABEL; // loop-like labels are always forward
                printf("SETUP_WITH " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_WITH_CLEANUP:
                printf("WITH_CLEANUP");
                break;

            case MP_BC_UNWIND_JUMP:
                DECODE_SLABEL;
                printf("UNWIND_JUMP " UINT_FMT " %d", ip + unum - ip_start, *ip);
                ip += 1;
                break;

            case MP_BC_SETUP_EXCEPT:
                DECODE_ULABEL; // except labels are always forward
                printf("SETUP_EXCEPT " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_SETUP_FINALLY:
                DECODE_ULABEL; // except labels are always forward
                printf("SETUP_FINALLY " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_END_FINALLY:
                // if TOS is an exception, reraises the exception (3 values on TOS)
                // if TOS is an integer, does something else
                // if TOS is None, just pops it and continues
                // else error
                printf("END_FINALLY");
                break;

            case MP_BC_GET_ITER:
                printf("GET_ITER");
                break;

            case MP_BC_FOR_ITER:
                DECODE_ULABEL; // the jump offset if iteration finishes; for labels are always forward
                printf("FOR_ITER " UINT_FMT, ip + unum - ip_start);
                break;

            case MP_BC_POP_BLOCK:
                // pops block and restores the stack
                printf("POP_BLOCK");
                break;

            case MP_BC_POP_EXCEPT:
                // pops block, checks it's an exception block, and restores the stack, saving the 3 exception values to local threadstate
                printf("POP_EXCEPT");
                break;

            case MP_BC_NOT:
                printf("NOT");
                break;

            case MP_BC_UNARY_OP:
                unum = *ip++;
                printf("UNARY_OP " UINT_FMT, unum);
                break;

            case MP_BC_BINARY_OP:
                unum = *ip++;
                printf("BINARY_OP " UINT_FMT, unum);
                break;

            case MP_BC_BUILD_TUPLE:
                DECODE_UINT;
                printf("BUILD_TUPLE " UINT_FMT, unum);
                break;

            case MP_BC_BUILD_LIST:
                DECODE_UINT;
                printf("BUILD_LIST " UINT_FMT, unum);
                break;

            case MP_BC_LIST_APPEND:
                DECODE_UINT;
                printf("LIST_APPEND " UINT_FMT, unum);
                break;

            case MP_BC_BUILD_MAP:
                DECODE_UINT;
                printf("BUILD_MAP " UINT_FMT, unum);
                break;

            case MP_BC_STORE_MAP:
                printf("STORE_MAP");
                break;

            case MP_BC_MAP_ADD:
                DECODE_UINT;
                printf("MAP_ADD " UINT_FMT, unum);
                break;

            case MP_BC_BUILD_SET:
                DECODE_UINT;
                printf("BUILD_SET " UINT_FMT, unum);
                break;

            case MP_BC_SET_ADD:
                DECODE_UINT;
                printf("SET_ADD " UINT_FMT, unum);
                break;

#if MICROPY_PY_BUILTINS_SLICE
            case MP_BC_BUILD_SLICE:
                DECODE_UINT;
                printf("BUILD_SLICE " UINT_FMT, unum);
                break;
#endif

            case MP_BC_UNPACK_SEQUENCE:
                DECODE_UINT;
                printf("UNPACK_SEQUENCE " UINT_FMT, unum);
                break;

            case MP_BC_MAKE_FUNCTION:
                DECODE_PTR;
                printf("MAKE_FUNCTION %p", (void*)unum);
                break;

            case MP_BC_MAKE_FUNCTION_DEFARGS:
                DECODE_PTR;
                printf("MAKE_FUNCTION_DEFARGS %p", (void*)unum);
                break;

            case MP_BC_MAKE_CLOSURE: {
                DECODE_PTR;
                mp_uint_t n_closed_over = *ip++;
                printf("MAKE_CLOSURE %p " UINT_FMT, (void*)unum, n_closed_over);
                break;
            }

            case MP_BC_MAKE_CLOSURE_DEFARGS: {
                DECODE_PTR;
                mp_uint_t n_closed_over = *ip++;
                printf("MAKE_CLOSURE_DEFARGS %p " UINT_FMT, (void*)unum, n_closed_over);
                break;
            }

            case MP_BC_CALL_FUNCTION:
                DECODE_UINT;
                printf("CALL_FUNCTION n=" UINT_FMT " nkw=" UINT_FMT, unum & 0xff, (unum >> 8) & 0xff);
                break;

            case MP_BC_CALL_FUNCTION_VAR_KW:
                DECODE_UINT;
                printf("CALL_FUNCTION_VAR_KW n=" UINT_FMT " nkw=" UINT_FMT, unum & 0xff, (unum >> 8) & 0xff);
                break;

            case MP_BC_CALL_METHOD:
                DECODE_UINT;
                printf("CALL_METHOD n=" UINT_FMT " nkw=" UINT_FMT, unum & 0xff, (unum >> 8) & 0xff);
                break;

            case MP_BC_CALL_METHOD_VAR_KW:
                DECODE_UINT;
                printf("CALL_METHOD_VAR_KW n=" UINT_FMT " nkw=" UINT_FMT, unum & 0xff, (unum >> 8) & 0xff);
                break;

            case MP_BC_RETURN_VALUE:
                printf("RETURN_VALUE");
                break;

            case MP_BC_RAISE_VARARGS:
                unum = *ip++;
                printf("RAISE_VARARGS " UINT_FMT, unum);
                break;

            case MP_BC_YIELD_VALUE:
                printf("YIELD_VALUE");
                break;

            case MP_BC_YIELD_FROM:
                printf("YIELD_FROM");
                break;

            case MP_BC_IMPORT_NAME:
                DECODE_QSTR;
                printf("IMPORT_NAME '%s'", qstr_str(qstr));
                break;

            case MP_BC_IMPORT_FROM:
                DECODE_QSTR;
                printf("IMPORT_FROM '%s'", qstr_str(qstr));
                break;

            case MP_BC_IMPORT_STAR:
                printf("IMPORT_STAR");
                break;

            default:
                printf("code %p, byte code 0x%02x not implemented\n", ip, ip[-1]);
                assert(0);
                return;
        }
        printf("\n");
    }
}

#endif // MICROPY_DEBUG_PRINTERS
