/*
    PiFmRds - FM/RDS transmitter for the Raspberry Pi
    Copyright (C) 2014 Christophe Jacquet, F8FTK
    
    See https://github.com/ChristopheJacquet/PiFmRds

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef RDS_H
#define RDS_H


#include <stdint.h>

#define GROUP_LENGTH 4
#define BITS_PER_GROUP (GROUP_LENGTH * (BLOCK_SIZE+POLY_DEG))

/* The RDS error-detection code generator polynomial is
   x^10 + x^8 + x^7 + x^5 + x^4 + x^3 + x^0
*/
#define POLY 0x1B9
#define POLY_DEG 10
#define MSB_BIT 0x8000
#define BLOCK_SIZE 16

#define RT_LENGTH 64
#define PS_LENGTH 8
#define AF_LENGTH 7

struct s_rds_params {
    uint16_t pi;
    unsigned int stereo:1;
    unsigned int ta:1;
    int8_t afs;
    uint16_t af[AF_LENGTH];
    char ps[PS_LENGTH];
    char rt[RT_LENGTH];
};
extern struct s_rds_params rds_params;
extern void get_rds_samples(float *buffer, int count);
extern void set_rds_pi(uint16_t pi_code);
extern void set_rds_rt(char *rt);
extern void set_rds_ps(char *ps);
extern void set_rds_ta(int ta);
extern void get_rds_group(uint8_t *buffer);
extern void write_ps_group(uint8_t *buffer, uint8_t group_number);
extern void write_rt_group(uint8_t *buffer, uint8_t group_number);

#endif /* RDS_H */
