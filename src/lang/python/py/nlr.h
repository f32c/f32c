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

// non-local return
// exception handling, basically a stack of setjmp/longjmp buffers

#include <limits.h>
#include <setjmp.h>
#include <assert.h>

#define MICROPY_NLR_SETJMP 1

typedef struct _nlr_buf_t nlr_buf_t;
struct _nlr_buf_t {
    // the entries here must all be machine word size
    nlr_buf_t *prev;
    void *ret_val;
#if !MICROPY_NLR_SETJMP
#if defined(__i386__)
    void *regs[6];
#elif defined(__x86_64__)
  #if defined(__CYGWIN__)
    void *regs[12];
  #else
    void *regs[8];
  #endif
#elif defined(__thumb2__) || defined(__thumb__) || defined(__arm__)
    void *regs[10];
#else
    #define MICROPY_NLR_SETJMP (1)
    //#warning "No native NLR support for this arch, using setjmp implementation"
#endif
#endif

#if MICROPY_NLR_SETJMP
    jmp_buf jmpbuf;
#endif
};

#if MICROPY_NLR_SETJMP
extern nlr_buf_t *nlr_setjmp_top;
NORETURN void nlr_setjmp_jump(void *val);
// nlr_push() must be defined as a macro, because "The stack context will be
// invalidated if the function which called setjmp() returns."
#define nlr_push(buf) ((buf)->prev = nlr_setjmp_top, nlr_setjmp_top = (buf), setjmp((buf)->jmpbuf))
#define nlr_pop() { nlr_setjmp_top = nlr_setjmp_top->prev; }
#define nlr_jump(val) nlr_setjmp_jump(val)
#else
unsigned int nlr_push(nlr_buf_t *);
void nlr_pop(void);
NORETURN void nlr_jump(void *val);
#endif

// This must be implemented by a port.  It's called by nlr_jump
// if no nlr buf has been pushed.  It must not return, but rather
// should bail out with a fatal error.
void nlr_jump_fail(void *val);

// use nlr_raise instead of nlr_jump so that debugging is easier
#ifndef DEBUG
#define nlr_raise(val) nlr_jump(val)
#else
#define nlr_raise(val) \
    do { \
        void *_val = val; \
        assert(_val != NULL); \
        assert(mp_obj_is_exception_instance(_val)); \
        nlr_jump(_val); \
    } while (0)
#endif
