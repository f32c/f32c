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

#include "mpconfig.h"
#include "misc.h"
#include "gc.h"

#if MICROPY_ENABLE_GC

extern char *stack_top;

#if MICROPY_GCREGS_SETJMP
#include <setjmp.h>

typedef jmp_buf regs_t;

void gc_helper_get_regs(regs_t arr) {
    setjmp(arr);
}

#else // !MICROPY_GCREGS_SETJMP

// We capture here callee-save registers, i.e. ones which may contain
// interesting values held there by our callers. It doesn't make sense
// to capture caller-saved registers, because they, well, put on the
// stack already by the caller.
#ifdef __x86_64__
typedef mp_uint_t regs_t[6];

void gc_helper_get_regs(regs_t arr) {
    register long rbx asm ("rbx");
    register long rbp asm ("rbp");
    register long r12 asm ("r12");
    register long r13 asm ("r13");
    register long r14 asm ("r14");
    register long r15 asm ("r15");
#ifdef __clang__
    // TODO:
    // This is dirty workaround for Clang. It tries to get around
    // uncompliant (wrt to GCC) behavior of handling register variables.
    // Application of this patch here is random, and done only to unbreak
    // MacOS build. Better, cross-arch ways to deal with Clang issues should
    // be found.
    asm("" : "=r"(rbx));
    asm("" : "=r"(rbp));
    asm("" : "=r"(r12));
    asm("" : "=r"(r13));
    asm("" : "=r"(r14));
    asm("" : "=r"(r15));
#endif
    arr[0] = rbx;
    arr[1] = rbp;
    arr[2] = r12;
    arr[3] = r13;
    arr[4] = r14;
    arr[5] = r15;
}
#endif

#ifdef __i386__
typedef mp_uint_t regs_t[4];

void gc_helper_get_regs(regs_t arr) {
    register long ebx asm ("ebx");
    register long esi asm ("esi");
    register long edi asm ("edi");
    register long ebp asm ("ebp");
    arr[0] = ebx;
    arr[1] = esi;
    arr[2] = edi;
    arr[3] = ebp;
}
#endif

#if defined(__thumb2__) || defined(__thumb__) || defined(__arm__)
typedef mp_uint_t regs_t[10];

void gc_helper_get_regs(regs_t arr) {
    register long r4 asm ("r4");
    register long r5 asm ("r5");
    register long r6 asm ("r6");
    register long r7 asm ("r7");
    register long r8 asm ("r8");
    register long r9 asm ("r9");
    register long r10 asm ("r10");
    register long r11 asm ("r11");
    register long r12 asm ("r12");
    register long r13 asm ("r13");
    arr[0] = r4;
    arr[1] = r5;
    arr[2] = r6;
    arr[3] = r7;
    arr[4] = r8;
    arr[5] = r9;
    arr[6] = r10;
    arr[7] = r11;
    arr[8] = r12;
    arr[9] = r13;
}
#endif
#endif // !MICROPY_GCREGS_SETJMP

void gc_collect(void) {
    //gc_dump_info();

    gc_collect_start();
    // this traces the .bss section
#if defined( __CYGWIN__ )
#define BSS_START __bss_start__
#elif defined( _MSC_VER ) || defined( __MINGW32__ )
#define BSS_START *bss_start
#define _end *bss_end
#else
#define BSS_START __bss_start
#endif
    extern char BSS_START, _end;
    //printf(".bss: %p-%p\n", &BSS_START, &_end);
    gc_collect_root((void**)&BSS_START, ((mp_uint_t)&_end - (mp_uint_t)&BSS_START) / sizeof(mp_uint_t));
    regs_t regs;
    gc_helper_get_regs(regs);
    // GC stack (and regs because we captured them)
    void **regs_ptr = (void**)(void*)&regs;
    gc_collect_root(regs_ptr, ((mp_uint_t)stack_top - (mp_uint_t)&regs) / sizeof(mp_uint_t));
    gc_collect_end();

    //printf("-----\n");
    //gc_dump_info();
}

#endif //MICROPY_ENABLE_GC
