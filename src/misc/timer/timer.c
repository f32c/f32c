/*
 * Exercise various graphics manipulation functions.  Apparently also
 * a good test for SRAM consistency / reliability.
 *
 * $Id: video_test.c 2167 2014-08-22 09:14:55Z marko $
 */

#include <stdio.h>
#include <stdlib.h>
#include <io.h>
#include <fb.h>
#include <sys/isr.h>
#include <mips/asm.h>
#include "timer.h"

/* OR this to extend sign of TIMER_BITS to integer */
#define INC_EXTEND_SIGN (-(1<<(TIMER_BITS+PRESCALER_BITS-1)))

#if 1
static int timer_interrupt(void)
{
	static uint8_t counter;

        /* find source of interrupt, clear and process */
	if( TIMER[TC_CONTROL] & (1<<TCTRL_IF_OCP1) )
	{
	  TIMER[TC_CONTROL] = ~(1<<TCTRL_IF_OCP1);
	  *LED = 1<<0; // triggers ICP1
          *LED = (counter++) << 4;
        }

	if( TIMER[TC_CONTROL] & (1<<TCTRL_IF_OCP2) )
	{
	  TIMER[TC_CONTROL] = ~(1<<TCTRL_IF_OCP2);
	  *LED = 1<<1; // triggers ICP2
          *LED = (counter--) << 4;
        }

	if( TIMER[TC_CONTROL] & (1<<TCTRL_IF_ICP1) )
	{
	  TIMER[TC_CONTROL] = ~(1<<TCTRL_IF_ICP1);
          // *LED = counter++;
        }

	if( TIMER[TC_CONTROL] & (1<<TCTRL_IF_ICP2) )
	{
	  TIMER[TC_CONTROL] = ~(1<<TCTRL_IF_ICP2);
          // *LED = counter++;
        }

	/*
	 * tsc_update() executes in interrupt context, and as such it
	 * should not use MULT / MULTU, but fb_text() does.  In this
	 * particular program, by pure luck this seems not to be a problem,
	 * but in general, interrupt context routines should be more
	 * carefully crafted to avoid messing up HI and LO registers.
	 */
	return 1;
}


static struct isr_link timer_isr = {
	.handler_fn = &timer_interrupt
};
#endif

void print_timer(void)
{
  int32_t i;
  int64_t f;
  
  i = TIMER[TC_INCREMENT] & ((1<<(TIMER_BITS+PRESCALER_BITS))-1);
  if(i & (1<<(TIMER_BITS+PRESCALER_BITS-1))) /* is i negative? */
    i |= INC_EXTEND_SIGN;
  
  f = ((uint64_t)CLOCK * i) >> (TIMER_BITS+PRESCALER_BITS);
  printf("inc=%d (%08x) f=%d cnt=%d icp1=%d icp2=%d\n",
    i, i,
    (int32_t) f,
    TIMER[TC_COUNTER],
    TIMER[TC_ICP1],
    TIMER[TC_ICP2]
    );
}

void
main(void)
{
        char inkey;

	*LED = 0;

	TIMER[TC_INCREMENT] = 1;
	TIMER[TC_APPLY] = (1<<TC_INCREMENT);

#if 1
	TIMER[TC_OCP1_START] = 0;
	TIMER[TC_OCP1_STOP]  = (1<<(TIMER_BITS-2))-1;
	TIMER[TC_OCP2_START] = (1<<(TIMER_BITS-2));
	TIMER[TC_OCP2_STOP]  = (1<<(TIMER_BITS-1))-1;
#else
	TIMER[TC_OCP1_START] = 0;
	TIMER[TC_OCP1_STOP]  = (1<<(TIMER_BITS-1))-1;
	TIMER[TC_OCP2_START] = (1<<(TIMER_BITS-1));
	TIMER[TC_OCP2_STOP]  = (1<<(TIMER_BITS-0))-1;
#endif

#if 0
        /* icp in the same time window as ocp */
	TIMER[TC_ICP1_START] = 0;
	TIMER[TC_ICP1_STOP]  = (1<<(TIMER_BITS-2))-1;
	TIMER[TC_ICP2_START] = (1<<(TIMER_BITS-2));
	TIMER[TC_ICP2_STOP]  = (1<<(TIMER_BITS-1))-1;
#else
        /* icp wide open window */
	TIMER[TC_ICP1_START] = 0;
	TIMER[TC_ICP1_STOP]  = (1<<(TIMER_BITS))-1;
	TIMER[TC_ICP2_START] = 0;
	TIMER[TC_ICP2_STOP]  = (1<<(TIMER_BITS))-1;
#endif
	TIMER[TC_INC_MIN]    = 30000;
	TIMER[TC_INC_MAX]    = 40000;
	
	TIMER[TC_ICP1]       = 173; // setpoint ICP1
	TIMER[TC_ICP2]       = 689; // setpoint ICP2

	TIMER[TC_CONTROL] = (1<<TCTRL_AND_OR_OCP1) | (1<<TCTRL_AND_OR_OCP2)
	                  | (1<<TCTRL_AND_OR_ICP1) | (1<<TCTRL_AND_OR_ICP2)
	                  | (1<<TCTRL_IE_OCP1)     | (1<<TCTRL_IE_OCP2)
	                  | (1<<TCTRL_IE_ICP1)     | (1<<TCTRL_IE_ICP2)
	                  | (1<<TCTRL_AFCEN_ICP1)  | (0<<TCTRL_AFCINV_ICP1)
	                  | (0<<TCTRL_AFCEN_ICP2)  | (0<<TCTRL_AFCINV_ICP2)
	                  | (1<<TCTRL_XOR_OCP1)    | (1<<TCTRL_XOR_OCP2)
	                  | (1<<TCTRL_XOR_ICP1)    | (1<<TCTRL_XOR_ICP2)
	                  | (1<<TCTRL_ENABLE_OCP1) | (1<<TCTRL_ENABLE_OCP2)
	                  | (1<<TCTRL_ENABLE_ICP1) | (1<<TCTRL_ENABLE_ICP2)
	                  ;

        TIMER[TC_APPLY] = (1<<TC_CONTROL)
                        | (1<<TC_OCP1_START) | (1<<TC_OCP1_STOP) 
                        | (1<<TC_OCP2_START) | (1<<TC_OCP2_STOP)
                        | (1<<TC_ICP1_START) | (1<<TC_ICP1_STOP) 
                        | (1<<TC_ICP2_START) | (1<<TC_ICP2_STOP)
                        | (1<<TC_INC_MIN)    | (1<<TC_INC_MAX)
                        | (1<<TC_ICP1)       | (1<<TC_ICP2)
                        ;

        /* isr_register_handler(interrput number, *isr_link) */
        /* 2 is frame interrupt 
        ** 3 is serial interrupt
        ** 4 is timer interrupt
        */
	isr_register_handler(4, &timer_isr); 
	asm("ei");

        for(;;)
	{
		DELAY(2000000);
		inkey = sio_getchar(0);
		switch(inkey)
		{
		  case 3:
		      exit(0); /* CTRL+C */
                  case '-':
                      TIMER[TC_INCREMENT] -= 1;
                      TIMER[TC_APPLY] = (1<<TC_INCREMENT);
                      break;
                  case '+':
                      TIMER[TC_INCREMENT] += 1;
                      TIMER[TC_APPLY] = (1<<TC_INCREMENT);
                      break;
                  case ',':
                      TIMER[TC_INCREMENT] -= 100;
                      TIMER[TC_APPLY] = (1<<TC_INCREMENT);
                      break;
                  case '.':
                      TIMER[TC_INCREMENT] += 100;
                      TIMER[TC_APPLY] = (1<<TC_INCREMENT);
                      break;
                }
                switch(inkey)
                {
                  case '\r':
                  case '-':
                  case '+':
                  case ',':
                  case '.':
                      print_timer();
                      break;
                }

	}
}
