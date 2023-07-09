/*-
 * Copyright (c) 2023 Marko Zec
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */


#include <time.h>

#include <dev/io.h>


/* Table of f32c:rtc specific clock increments, in ns */
static const char rtc_res_tbl[8] = {1, 2, 5, 10, 20, 50, 100, 200};


uint32_t
get_cpu_freq() {
	uint32_t rtc_cfg;
	uint32_t incr_ns;
	uint64_t clk_freq = 1000000000;

	INW(rtc_cfg, IO_RTC_CFG);
	incr_ns = rtc_res_tbl[(rtc_cfg >> 24) & 0xf];
	clk_freq += incr_ns / 2;
	clk_freq <<= 24;
	clk_freq /= (rtc_cfg & 0xffffff) * incr_ns;

	return (clk_freq);
}


int
clock_getres(clockid_t clk_id, struct timespec *res) {
	uint32_t rtc_cfg;

	if (res == NULL)
		return (-1);

	INW(rtc_cfg, IO_RTC_CFG);
	res->tv_sec = 0;
	res->tv_nsec = rtc_res_tbl[(rtc_cfg >> 24) & 0xf];
	return (0);
}


int
clock_gettime(clockid_t clk_id, struct timespec *tp) {
	uint32_t sec, sec2, nsec;

	if ((clk_id != CLOCK_REALTIME && clk_id != CLOCK_MONOTONIC)
	    || tp == NULL)
		return (-1);

	do {
		INW(sec, IO_RTC_UPTIME_S);
		INW(nsec, IO_RTC_UPTIME_NS);
		INW(sec2, IO_RTC_UPTIME_S);
	} while (sec != sec2);
	tp->tv_sec = sec;
	tp->tv_nsec = nsec;

	if (clk_id != CLOCK_REALTIME)
		return (0);

	INW(sec, IO_RTC_BOOTTIME_S);
	tp->tv_sec += sec;
	if (sec)
		return (0);
	tp->tv_sec = 0;
	tp->tv_nsec = 0;
	return (-1);
}


int
clock_settime(clockid_t clk_id, const struct timespec *tp) {
	uint32_t sec;

	if (clk_id != CLOCK_REALTIME || tp == NULL)
		return (-1);

	INW(sec, IO_RTC_UPTIME_S);
	sec = tp->tv_sec - sec;
	OUTW(IO_RTC_BOOTTIME_S, sec);
	return (0);
}
