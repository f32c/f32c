//===-- ffssi2.c - Implement __ffssi2 -------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements __ffssi2 for the compiler_rt library.
//
//===----------------------------------------------------------------------===//

// Returns: the index of the least significant 1-bit in a, or
// the value zero if a is zero. The least significant bit is index one.

int __ffssi2(int32_t a) {
  if (a == 0) {
    return 0;
  }
  return __builtin_ctz(a) + 1;
}
