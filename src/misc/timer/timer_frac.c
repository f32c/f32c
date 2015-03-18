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


static char buf[64];


void
main(void)
{
	uint32_t period_frac = 60000<<FRAC_BITS;
	
	*LED = 0;

	TIMER[TC_PERIOD] = period_frac >> FRAC_BITS;
	TIMER[TC_INCREMENT] = 3;
	TIMER[TC_FRACTIONAL] = period_frac & ((1<<FRAC_BITS)-1);
	TIMER[TC_COUNTER] = 0;
	TIMER[TC_APPLY] = (1<<TC_COUNTER) | (1<<TC_PERIOD) | (1<<TC_FRACTIONAL) | (1<<TC_INCREMENT);

	TIMER[TC_OCP1_START] = 0;
	TIMER[TC_OCP1_STOP]  = 10000;
	TIMER[TC_OCP2_START] = 20000;
	TIMER[TC_OCP2_STOP]  = 30000;
	TIMER[TC_CONTROL] = (1<<TCTRL_AND_OR_OCP1) | (1<<TCTRL_AND_OR_OCP2);
        TIMER[TC_APPLY] = (1<<TC_CONTROL)
                        | (1<<TC_OCP1_START) | (1<<TC_OCP1_STOP) 
                        | (1<<TC_OCP2_START) | (1<<TC_OCP2_STOP);

	TIMER[TC_OCP1_START] = 0;
	TIMER[TC_OCP1_STOP]  = 0;
	TIMER[TC_OCP2_START] = 0;
	TIMER[TC_OCP2_STOP]  = 0;
#if 0
	TIMER[TC_CONTROL] = (1<<TCTRL_AND_OR_OCP1) | (1<<TCTRL_AND_OR_OCP2);
        TIMER[TC_APPLY] = (1<<TC_CONTROL)
                        | (1<<TC_OCP1_START) | (1<<TC_OCP1_STOP) 
                        | (1<<TC_OCP2_START) | (1<<TC_OCP2_STOP);
#endif        
	for(;;)
	{
		sprintf(buf, "per=%d.%02d f=%d cnt=%d", 
		  *period, (100*(*fractional))>>FRAC_BITS, 
		  (uint32_t) ((( ((CLOCK<<FRAC_BITS) + (1<<PRESCALER_BITS)/2)>>PRESCALER_BITS)) / period_frac),
		  *counter);
		printf("%s\n", buf);
		DELAY(2000000);
		switch(sio_getchar(0))
		{
		  case 3:
		      exit(0); /* CTRL+C */
                  case '-':
                      period_frac += 1;
                      *period = (uint16_t)(period_frac >> FRAC_BITS);
                      *fractional = (uint16_t)(period_frac & ((1<<FRAC_BITS)-1));
                      *ocp1_start = 0;
                      *ocp1_stop = 1+(*period)/4;
                      *ocp2_start = (*period)/2;
                      *ocp2_stop = 1+(*period)/2 + (*period)/4;
                      *apply = (1<<TC_PERIOD) | (1<<TC_FRACTIONAL)
                             | (1<<TC_OCP1_START) | (1<<TC_OCP1_STOP)
                             | (1<<TC_OCP2_START) | (1<<TC_OCP2_STOP);
                      // printf("apply=%04x\n", *apply);
                      break;
                  case '+':
                      period_frac -= 1;
                      *period = (uint16_t)(period_frac >> FRAC_BITS);
                      *fractional = (uint16_t)(period_frac & ((1<<FRAC_BITS)-1));
                      *ocp1_start = 0;
                      *ocp1_stop = 1+(*period)/4;
                      *ocp2_start = (*period)/2;
                      *ocp2_stop = 1+(*period)/2 + (*period)/4;
                      *apply = (1<<TC_PERIOD) | (1<<TC_FRACTIONAL)
                             | (1<<TC_OCP1_START) | (1<<TC_OCP1_STOP)
                             | (1<<TC_OCP2_START) | (1<<TC_OCP2_STOP);
                      // printf("apply=%04x\n", *apply);
                      break;
                }

	}
}
