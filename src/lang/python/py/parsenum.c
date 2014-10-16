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
#include <stdlib.h>

#include "mpconfig.h"
#include "misc.h"
#include "qstr.h"
#include "nlr.h"
#include "obj.h"
#include "parsenumbase.h"
#include "parsenum.h"
#include "smallint.h"
#include "runtime.h"

#if MICROPY_PY_BUILTINS_FLOAT
#include <math.h>
#endif

mp_obj_t mp_parse_num_integer(const char *restrict str_, mp_uint_t len, mp_uint_t base) {
    const byte *restrict str = (const byte *)str_;
    const byte *restrict top = str + len;
    bool neg = false;
    mp_obj_t ret_val;

    // check radix base
    if ((base != 0 && base < 2) || base > 36) {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_ValueError, "int() arg 2 must be >= 2 and <= 36"));
    }

    // skip leading space
    for (; str < top && unichar_isspace(*str); str++) {
    }

    // parse optional sign
    if (str < top) {
        if (*str == '+') {
            str++;
        } else if (*str == '-') {
            str++;
            neg = true;
        }
    }

    // parse optional base prefix
    str += mp_parse_num_base((const char*)str, top - str, &base);

    // string should be an integer number
    mp_int_t int_val = 0;
    const byte *restrict str_val_start = str;
    for (; str < top; str++) {
        // get next digit as a value
        mp_uint_t dig = *str;
        if (unichar_isdigit(dig) && dig - '0' < base) {
            // 0-9 digit
            dig = dig - '0';
        } else if (base == 16) {
            dig |= 0x20;
            if ('a' <= dig && dig <= 'f') {
                // a-f hex digit
                dig = dig - 'a' + 10;
            } else {
                // unknown character
                break;
            }
        } else {
            // unknown character
            break;
        }

        // add next digi and check for overflow
        if (mp_small_int_mul_overflow(int_val, base)) {
            goto overflow;
        }
        int_val = int_val * base + dig;
        if (!MP_SMALL_INT_FITS(int_val)) {
            goto overflow;
        }
    }

    // negate value if needed
    if (neg) {
        int_val = -int_val;
    }

    // create the small int
    ret_val = MP_OBJ_NEW_SMALL_INT(int_val);

have_ret_val:
    // check we parsed something
    if (str == str_val_start) {
        goto value_error;
    }

    // skip trailing space
    for (; str < top && unichar_isspace(*str); str++) {
    }

    // check we reached the end of the string
    if (str != top) {
        goto value_error;
    }

    // return the object
    return ret_val;

overflow:
    // reparse using long int
    {
        const char *s2 = (const char*)str_val_start;
        ret_val = mp_obj_new_int_from_str_len(&s2, top - str_val_start, neg, base);
        str = (const byte*)s2;
        goto have_ret_val;
    }

value_error:
    nlr_raise(mp_obj_new_exception_msg_varg(&mp_type_ValueError, "invalid syntax for integer with base %d: '%s'", base, str));
}

typedef enum {
    PARSE_DEC_IN_INTG,
    PARSE_DEC_IN_FRAC,
    PARSE_DEC_IN_EXP,
} parse_dec_in_t;

mp_obj_t mp_parse_num_decimal(const char *str, mp_uint_t len, bool allow_imag, bool force_complex) {
#if MICROPY_PY_BUILTINS_FLOAT
    const char *top = str + len;
    mp_float_t dec_val = 0;
    bool dec_neg = false;
    bool imag = false;

    // skip leading space
    for (; str < top && unichar_isspace(*str); str++) {
    }

    // parse optional sign
    if (str < top) {
        if (*str == '+') {
            str++;
        } else if (*str == '-') {
            str++;
            dec_neg = true;
        }
    }

    // determine what the string is
    if (str < top && (str[0] | 0x20) == 'i') {
        // string starts with 'i', should be 'inf' or 'infinity' (case insensitive)
        if (str + 2 < top && (str[1] | 0x20) == 'n' && (str[2] | 0x20) == 'f') {
            // inf
            str += 3;
            dec_val = INFINITY;
            if (str + 4 < top && (str[0] | 0x20) == 'i' && (str[1] | 0x20) == 'n' && (str[2] | 0x20) == 'i' && (str[3] | 0x20) == 't' && (str[4] | 0x20) == 'y') {
                // infinity
                str += 5;
            }
        }
    } else if (str < top && (str[0] | 0x20) == 'n') {
        // string starts with 'n', should be 'nan' (case insensitive)
        if (str + 2 < top && (str[1] | 0x20) == 'a' && (str[2] | 0x20) == 'n') {
            // NaN
            str += 3;
            dec_val = MICROPY_FLOAT_C_FUN(nan)("");
        }
    } else {
        // string should be a decimal number
        parse_dec_in_t in = PARSE_DEC_IN_INTG;
        bool exp_neg = false;
        mp_int_t exp_val = 0;
        mp_int_t exp_extra = 0;
        for (; str < top; str++) {
            mp_uint_t dig = *str;
            if ('0' <= dig && dig <= '9') {
                dig -= '0';
                if (in == PARSE_DEC_IN_EXP) {
                    exp_val = 10 * exp_val + dig;
                } else {
                    dec_val = 10 * dec_val + dig;
                    if (in == PARSE_DEC_IN_FRAC) {
                        exp_extra -= 1;
                    }
                }
            } else if (in == PARSE_DEC_IN_INTG && dig == '.') {
                in = PARSE_DEC_IN_FRAC;
            } else if (in != PARSE_DEC_IN_EXP && ((dig | 0x20) == 'e')) {
                in = PARSE_DEC_IN_EXP;
                if (str[1] == '+') {
                    str++;
                } else if (str[1] == '-') {
                    str++;
                    exp_neg = true;
                }
            } else if (allow_imag && (dig | 0x20) == 'j') {
                str++;
                imag = true;
                break;
            } else {
                // unknown character
                break;
            }
        }

        // work out the exponent
        if (exp_neg) {
            exp_val = -exp_val;
        }
        exp_val += exp_extra;

        // apply the exponent
        for (; exp_val > 0; exp_val--) {
            dec_val *= 10;
        }
        for (; exp_val < 0; exp_val++) {
            dec_val *= 0.1;
        }
    }

    // negate value if needed
    if (dec_neg) {
        dec_val = -dec_val;
    }

    // skip trailing space
    for (; str < top && unichar_isspace(*str); str++) {
    }

    // check we reached the end of the string
    if (str != top) {
        nlr_raise(mp_obj_new_exception_msg(&mp_type_SyntaxError, "invalid syntax for number"));
    }

    // return the object
#if MICROPY_PY_BUILTINS_COMPLEX
    if (imag) {
        return mp_obj_new_complex(0, dec_val);
    } else if (force_complex) {
        return mp_obj_new_complex(dec_val, 0);
#else
    if (imag || force_complex) {
        mp_not_implemented("complex values not supported");
#endif
    } else {
        return mp_obj_new_float(dec_val);
    }

#else
    nlr_raise(mp_obj_new_exception_msg(&mp_type_SyntaxError, "decimal numbers not supported"));
#endif
}
