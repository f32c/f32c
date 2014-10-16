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

MP_DECLARE_CONST_FUN_OBJ(mp_stream_read_obj);
MP_DECLARE_CONST_FUN_OBJ(mp_stream_readall_obj);
MP_DECLARE_CONST_FUN_OBJ(mp_stream_unbuffered_readline_obj);
MP_DECLARE_CONST_FUN_OBJ(mp_stream_unbuffered_readlines_obj);
MP_DECLARE_CONST_FUN_OBJ(mp_stream_write_obj);

// Iterator which uses mp_stream_unbuffered_readline_obj
mp_obj_t mp_stream_unbuffered_iter(mp_obj_t self);

mp_obj_t mp_stream_write(mp_obj_t self_in, const void *buf, mp_uint_t len);
