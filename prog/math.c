/*--------------------------------------------------------------------
 * TITLE: Plasma Floating Point Library
 * AUTHOR: Steve Rhoads (rhoadss@yahoo.com)
 * DATE CREATED: 3/2/06
 * FILENAME: math.c
 * PROJECT: Plasma CPU core
 * COPYRIGHT: Software placed into the public domain by the author.
 *    Software 'as is' without warranty.  Author liable for nothing.
 * DESCRIPTION:
 *    Plasma Floating Point Library
 *--------------------------------------------------------------------*/

/* $Id$ */

#define USE_SW_MULT

//These five functions will only be used if the flag "-mno-mul" is enabled
#ifdef USE_SW_MULT
unsigned long __mulsi3(unsigned long a, unsigned long b)
{
   unsigned long answer = 0;
   while(b)
   {
      if(b & 1)
         answer += a;
      a <<= 1;
      b >>= 1;
   }
   return answer;
}


static unsigned long DivideMod(unsigned long a, unsigned long b, int doMod)
{
   unsigned long upper=a, lower=0;
   int i;
   a = b << 31;
   for(i = 0; i < 32; ++i)
   {
      lower = lower << 1;
      if(upper >= a && a && b < 2)
      {
         upper = upper - a;
         lower |= 1;
      }
      a = ((b&2) << 30) | (a >> 1);
      b = b >> 1;
   }
   if(!doMod)
      return lower;
   return upper;
}


unsigned long __udivsi3(unsigned long a, unsigned long b)
{
   return DivideMod(a, b, 0);
}


long __divsi3(long a, long b)
{
   long answer, negate=0;
   if(a < 0)
   {
      a = -a;
      negate = !negate;
   }
   if(b < 0)
   {
      b = -b;
      negate = !negate;
   }
   answer = DivideMod(a, b, 0);
   if(negate)
      answer = -answer;
   return answer;
}


unsigned long __umodsi3(unsigned long a, unsigned long b)
{
   return DivideMod(a, b, 1);
}
#endif
