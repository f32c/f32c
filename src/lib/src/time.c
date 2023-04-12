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


static char month_days[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};


time_t
time(time_t *res)
{
	time_t t;
	uint32_t sec;

	INW(sec, IO_RTC_UPTIME_S);
	t = sec;
	INW(sec, IO_RTC_BOOTTIME_S);
	t += sec;
	if (res != NULL)
		*res = t;
	return (t);
}


/*
 * A crude approximation of gmtime() and friends, valid from 1970 through 2099
 */
struct tm *
gmtime_r(const time_t *restrict time, struct tm *restrict res) {
	uint32_t sec, day, month, year;
	uint32_t four_yrs, days, leap;

	if (time == NULL || res == NULL)
		return (NULL);

	sec = *time;
	day = sec / 86400;
	sec = sec % 86400;

	res->tm_wday = (day + 4) % 7;

	four_yrs = day / (366 + 3 * 365);
	day = day % (366 + 3 * 365);
	for (year = 0, leap = 0; year < 4; year++) {
		if (year == 2) {
			leap = 1;
			days = 366;
		} else
			days = 365;
		if (day < days)
			break;
		day -= days;
	}
	res->tm_yday = day;

	year += 1970 + four_yrs * 4;
	for (month = 0; month < 12; month++) {
		days = month_days[month];
		if (month == 1)
			days += leap;
		if (day < days)
			break;
		day -= days;
	}

	res->tm_year = year - 1900;
	res->tm_mon = month;
	res->tm_mday = day + 1;

	res->tm_hour = sec / (60 * 60);
	res->tm_min = sec % (60 * 60) / 60;
	res->tm_sec = sec % 60;

	res->tm_isdst = 0;
	res->tm_gmtoff = 0;
	res->tm_zone = NULL;

	return (res);
}

