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
// All the qstr definitions in this file are available as constants.
// That is, they are in ROM and you can reference them simply as MP_QSTR_xxxx.

Q(*)
Q(__build_class__)
Q(__class__)
Q(__doc__)
Q(__import__)
Q(__init__)
Q(__new__)
Q(__locals__)
Q(__main__)
Q(__module__)
Q(__name__)
Q(__next__)
Q(__qualname__)
Q(__path__)
Q(__repl_print__)
#if MICROPY_PY___FILE__
Q(__file__)
#endif

Q(__bool__)
Q(__contains__)
Q(__enter__)
Q(__exit__)
Q(__len__)
Q(__iter__)
Q(__getitem__)
Q(__setitem__)
Q(__delitem__)
Q(__add__)
Q(__sub__)
Q(__repr__)
Q(__str__)
Q(__getattr__)
Q(__del__)
Q(__call__)
Q(__lt__)
Q(__gt__)
Q(__eq__)
Q(__le__)
Q(__ge__)

Q(micropython)
Q(bytecode)
Q(const)

#if MICROPY_EMIT_NATIVE
Q(native)
Q(viper)
Q(uint)
Q(ptr)
Q(ptr8)
Q(ptr16)
#endif

#if MICROPY_EMIT_INLINE_THUMB
Q(asm_thumb)
Q(label)
Q(align)
Q(data)
#endif

Q(builtins)

Q(Ellipsis)
Q(StopIteration)

Q(BaseException)
Q(ArithmeticError)
Q(AssertionError)
Q(AttributeError)
Q(BufferError)
Q(EOFError)
Q(Exception)
Q(FileExistsError)
Q(FileNotFoundError)
Q(FloatingPointError)
Q(GeneratorExit)
Q(ImportError)
Q(IndentationError)
Q(IndexError)
Q(KeyError)
Q(LookupError)
Q(MemoryError)
Q(NameError)
Q(NotImplementedError)
Q(OSError)
Q(OverflowError)
Q(RuntimeError)
Q(SyntaxError)
Q(SystemError)
Q(SystemExit)
Q(TypeError)
Q(UnboundLocalError)
Q(ValueError)
Q(ZeroDivisionError)

Q(None)
Q(False)
Q(True)
Q(object)

Q(NoneType)

Q(abs)
Q(all)
Q(any)
Q(args)
Q(array)
Q(bin)
Q({:#b})
Q(bool)
Q(bytearray)
Q(bytes)
Q(callable)
#if MICROPY_PY_STRUCT
Q(calcsize)
#endif
Q(chr)
Q(classmethod)
Q(_collections)
#if MICROPY_PY_BUILTINS_COMPLEX
Q(complex)
Q(real)
Q(imag)
#endif
Q(dict)
Q(dir)
Q(divmod)
Q(enumerate)
Q(eval)
Q(exec)
Q(filter)
#if MICROPY_PY_BUILTINS_FLOAT
Q(float)
#endif
Q(from_bytes)
Q(getattr)
Q(globals)
Q(hasattr)
Q(hash)
Q(hex)
Q(%#x)
Q(id)
Q(int)
Q(isinstance)
Q(issubclass)
Q(iter)
Q(len)
Q(list)
Q(locals)
Q(map)
Q(max)
Q(min)
Q(namedtuple)
Q(next)
Q(oct)
Q(%#o)
Q(open)
Q(ord)
Q(path)
Q(pow)
Q(print)
Q(range)
Q(read)
Q(repr)
Q(reversed)
Q(sorted)
Q(staticmethod)
Q(sum)
Q(super)
Q(str)
Q(sys)
Q(to_bytes)
Q(tuple)
Q(type)
Q(value)
Q(write)
Q(zip)

Q(sep)
Q(end)

Q(clear)
Q(copy)
Q(fromkeys)
Q(get)
Q(items)
Q(keys)
Q(pop)
Q(popitem)
Q(setdefault)
Q(update)
Q(values)
Q(append)
Q(close)
Q(send)
Q(throw)
Q(count)
Q(extend)
Q(index)
Q(remove)
Q(insert)
Q(pop)
Q(sort)
Q(join)
Q(strip)
Q(lstrip)
Q(rstrip)
Q(format)
Q(key)
Q(reverse)
Q(add)
Q(clear)
Q(copy)
Q(pop)
Q(remove)
Q(find)
Q(rfind)
Q(rindex)
Q(split)
Q(rsplit)
Q(startswith)
Q(endswith)
Q(replace)
Q(partition)
Q(rpartition)
Q(lower)
Q(upper)
Q(isspace)
Q(isalpha)
Q(isdigit)
Q(isupper)
Q(islower)
Q(iterable)
Q(start)

Q(bound_method)
Q(closure)
Q(dict_view)
Q(function)
Q(generator)
Q(iterator)
Q(module)
Q(slice)

#if MICROPY_PY_BUILTINS_SET
Q(discard)
Q(difference)
Q(difference_update)
Q(intersection)
Q(intersection_update)
Q(isdisjoint)
Q(issubset)
Q(issuperset)
Q(set)
Q(symmetric_difference)
Q(symmetric_difference_update)
Q(union)
Q(update)
#endif

#if MICROPY_PY_BUILTINS_FROZENSET
Q(frozenset)
#endif

#if MICROPY_PY_MATH || MICROPY_PY_CMATH
Q(math)
Q(e)
Q(pi)
Q(sqrt)
Q(pow)
Q(exp)
Q(expm1)
Q(log)
Q(log2)
Q(log10)
Q(cosh)
Q(sinh)
Q(tanh)
Q(acosh)
Q(asinh)
Q(atanh)
Q(cos)
Q(sin)
Q(tan)
Q(acos)
Q(asin)
Q(atan)
Q(atan2)
Q(ceil)
Q(copysign)
Q(fabs)
Q(fmod)
Q(floor)
Q(isfinite)
Q(isinf)
Q(isnan)
Q(trunc)
Q(modf)
Q(frexp)
Q(ldexp)
Q(degrees)
Q(radians)
Q(erf)
Q(erfc)
Q(gamma)
Q(lgamma)
#endif

#if MICROPY_PY_CMATH
Q(cmath)
Q(phase)
Q(polar)
Q(rect)
#endif

#if MICROPY_MEM_STATS
Q(mem_total)
Q(mem_current)
Q(mem_peak)
#endif

#if MICROPY_ENABLE_EMERGENCY_EXCEPTION_BUF && (MICROPY_EMERGENCY_EXCEPTION_BUF_SIZE == 0)
Q(alloc_emergency_exception_buf)
#endif

Q(<module>)
Q(<lambda>)
Q(<listcomp>)
Q(<dictcomp>)
Q(<setcomp>)
Q(<genexpr>)
Q(<string>)
Q(<stdin>)

#if MICROPY_CPYTHON_COMPAT
Q(encode)
Q(decode)
Q(utf-8)
#endif

#if MICROPY_PY_SYS
Q(argv)
Q(byteorder)
Q(big)
Q(exit)
Q(little)
#ifdef MICROPY_PY_SYS_PLATFORM
Q(platform)
#endif
Q(stdin)
Q(stdout)
Q(stderr)
Q(version)
Q(version_info)
#if MICROPY_PY_SYS_MAXSIZE
Q(maxsize)
#endif
#endif

#if MICROPY_PY_STRUCT
Q(struct)
Q(pack)
Q(unpack)
#endif

#if MICROPY_PY_UCTYPES
Q(uctypes)
Q(sizeof)
Q(addressof)
Q(bytes_at)
Q(bytearray_at)

Q(NATIVE)
Q(LITTLE_ENDIAN)
Q(BIG_ENDIAN)

Q(VOID)

Q(UINT8)
Q(INT8)
Q(UINT16)
Q(INT16)
Q(UINT32)
Q(INT32)
Q(UINT64)
Q(INT64)

Q(BFUINT8)
Q(BFINT8)
Q(BFUINT16)
Q(BFINT16)
Q(BFUINT32)
Q(BFINT32)

Q(FLOAT32)
Q(FLOAT64)

Q(ARRAY)
Q(PTR)
//Q(BITFIELD)

Q(BF_POS)
Q(BF_LEN)
#endif

#if MICROPY_PY_IO
Q(_io)
Q(readall)
Q(readline)
Q(readlines)
Q(FileIO)
Q(TextIOWrapper)
Q(StringIO)
Q(BytesIO)
Q(getvalue)
Q(file)
#endif

#if MICROPY_PY_GC
Q(gc)
Q(collect)
Q(disable)
Q(enable)
Q(mem_free)
Q(mem_alloc)
#endif

#if MICROPY_PY_BUILTINS_PROPERTY
Q(property)
Q(getter)
Q(setter)
Q(deleter)
#endif

#if MICROPY_PY_UZLIB
Q(uzlib)
Q(decompress)
#endif

#if MICROPY_PY_UJSON
Q(ujson)
Q(dumps)
Q(loads)
#endif

#if MICROPY_PY_URE
Q(ure)
Q(compile)
Q(match)
Q(search)
Q(group)
Q(DEBUG)
#endif
