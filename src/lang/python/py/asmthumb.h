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

#define ASM_THUMB_PASS_COMPUTE (1)
#define ASM_THUMB_PASS_EMIT    (2)

#define ASM_THUMB_REG_R0  (0)
#define ASM_THUMB_REG_R1  (1)
#define ASM_THUMB_REG_R2  (2)
#define ASM_THUMB_REG_R3  (3)
#define ASM_THUMB_REG_R4  (4)
#define ASM_THUMB_REG_R5  (5)
#define ASM_THUMB_REG_R6  (6)
#define ASM_THUMB_REG_R7  (7)
#define ASM_THUMB_REG_R8  (8)
#define ASM_THUMB_REG_R9  (9)
#define ASM_THUMB_REG_R10 (10)
#define ASM_THUMB_REG_R11 (11)
#define ASM_THUMB_REG_R12 (12)
#define ASM_THUMB_REG_R13 (13)
#define ASM_THUMB_REG_R14 (14)
#define ASM_THUMB_REG_R15 (15)
#define ASM_THUMB_REG_LR  (REG_R14)

#define ASM_THUMB_CC_EQ (0x0)
#define ASM_THUMB_CC_NE (0x1)
#define ASM_THUMB_CC_CS (0x2)
#define ASM_THUMB_CC_CC (0x3)
#define ASM_THUMB_CC_MI (0x4)
#define ASM_THUMB_CC_PL (0x5)
#define ASM_THUMB_CC_VS (0x6)
#define ASM_THUMB_CC_VC (0x7)
#define ASM_THUMB_CC_HI (0x8)
#define ASM_THUMB_CC_LS (0x9)
#define ASM_THUMB_CC_GE (0xa)
#define ASM_THUMB_CC_LT (0xb)
#define ASM_THUMB_CC_GT (0xc)
#define ASM_THUMB_CC_LE (0xd)

typedef struct _asm_thumb_t asm_thumb_t;

asm_thumb_t *asm_thumb_new(uint max_num_labels);
void asm_thumb_free(asm_thumb_t *as, bool free_code);
void asm_thumb_start_pass(asm_thumb_t *as, uint pass);
void asm_thumb_end_pass(asm_thumb_t *as);
uint asm_thumb_get_code_size(asm_thumb_t *as);
void *asm_thumb_get_code(asm_thumb_t *as);

void asm_thumb_entry(asm_thumb_t *as, int num_locals);
void asm_thumb_exit(asm_thumb_t *as);

void asm_thumb_label_assign(asm_thumb_t *as, uint label);

void asm_thumb_align(asm_thumb_t* as, uint align);
void asm_thumb_data(asm_thumb_t* as, uint bytesize, uint val);

// argument order follows ARM, in general dest is first
// note there is a difference between movw and mov.w, and many others!

#define ASM_THUMB_OP_ITE_EQ (0xbf0c)
#define ASM_THUMB_OP_ITE_CS (0xbf2c)
#define ASM_THUMB_OP_ITE_MI (0xbf4c)
#define ASM_THUMB_OP_ITE_VS (0xbf6c)
#define ASM_THUMB_OP_ITE_HI (0xbf8c)
#define ASM_THUMB_OP_ITE_GE (0xbfac)
#define ASM_THUMB_OP_ITE_GT (0xbfcc)

#define ASM_THUMB_OP_NOP        (0xbf00)
#define ASM_THUMB_OP_WFI        (0xbf30)
#define ASM_THUMB_OP_CPSID_I    (0xb672) // cpsid i, disable irq
#define ASM_THUMB_OP_CPSIE_I    (0xb662) // cpsie i, enable irq

void asm_thumb_op16(asm_thumb_t *as, uint op);
void asm_thumb_op32(asm_thumb_t *as, uint op1, uint op2);

// FORMAT 2: add/subtract

#define ASM_THUMB_FORMAT_2_ADD (0x1800)
#define ASM_THUMB_FORMAT_2_SUB (0x1a00)
#define ASM_THUMB_FORMAT_2_REG_OPERAND (0x0000)
#define ASM_THUMB_FORMAT_2_IMM_OPERAND (0x0400)

void asm_thumb_format_2(asm_thumb_t *as, uint op, uint rlo_dest, uint rlo_src, int src_b);

static inline void asm_thumb_add_rlo_rlo_rlo(asm_thumb_t *as, uint rlo_dest, uint rlo_src_a, uint rlo_src_b)
    { asm_thumb_format_2(as, ASM_THUMB_FORMAT_2_ADD | ASM_THUMB_FORMAT_2_REG_OPERAND, rlo_dest, rlo_src_a, rlo_src_b); }
static inline void asm_thumb_add_rlo_rlo_i3(asm_thumb_t *as, uint rlo_dest, uint rlo_src_a, int i3_src)
    { asm_thumb_format_2(as, ASM_THUMB_FORMAT_2_ADD | ASM_THUMB_FORMAT_2_IMM_OPERAND, rlo_dest, rlo_src_a, i3_src); }
static inline void asm_thumb_sub_rlo_rlo_rlo(asm_thumb_t *as, uint rlo_dest, uint rlo_src_a, uint rlo_src_b)
    { asm_thumb_format_2(as, ASM_THUMB_FORMAT_2_SUB | ASM_THUMB_FORMAT_2_REG_OPERAND, rlo_dest, rlo_src_a, rlo_src_b); }
static inline void asm_thumb_sub_rlo_rlo_i3(asm_thumb_t *as, uint rlo_dest, uint rlo_src_a, int i3_src)
    { asm_thumb_format_2(as, ASM_THUMB_FORMAT_2_SUB | ASM_THUMB_FORMAT_2_IMM_OPERAND, rlo_dest, rlo_src_a, i3_src); }

// FORMAT 3: move/compare/add/subtract immediate
// These instructions all do zero extension of the i8 value

#define ASM_THUMB_FORMAT_3_MOV (0x2000)
#define ASM_THUMB_FORMAT_3_CMP (0x2800)
#define ASM_THUMB_FORMAT_3_ADD (0x3000)
#define ASM_THUMB_FORMAT_3_SUB (0x3800)

void asm_thumb_format_3(asm_thumb_t *as, uint op, uint rlo, int i8);

static inline void asm_thumb_mov_rlo_i8(asm_thumb_t *as, uint rlo, int i8) { asm_thumb_format_3(as, ASM_THUMB_FORMAT_3_MOV, rlo, i8); }
static inline void asm_thumb_cmp_rlo_i8(asm_thumb_t *as, uint rlo, int i8) { asm_thumb_format_3(as, ASM_THUMB_FORMAT_3_CMP, rlo, i8); }
static inline void asm_thumb_add_rlo_i8(asm_thumb_t *as, uint rlo, int i8) { asm_thumb_format_3(as, ASM_THUMB_FORMAT_3_ADD, rlo, i8); }
static inline void asm_thumb_sub_rlo_i8(asm_thumb_t *as, uint rlo, int i8) { asm_thumb_format_3(as, ASM_THUMB_FORMAT_3_SUB, rlo, i8); }

// FORMAT 4: ALU operations

#define ASM_THUMB_FORMAT_4_AND (0x4000)
#define ASM_THUMB_FORMAT_4_EOR (0x4040)
#define ASM_THUMB_FORMAT_4_LSL (0x4080)
#define ASM_THUMB_FORMAT_4_LSR (0x40c0)
#define ASM_THUMB_FORMAT_4_ASR (0x4100)
#define ASM_THUMB_FORMAT_4_ADC (0x4140)
#define ASM_THUMB_FORMAT_4_SBC (0x4180)
#define ASM_THUMB_FORMAT_4_ROR (0x41c0)
#define ASM_THUMB_FORMAT_4_TST (0x4200)
#define ASM_THUMB_FORMAT_4_NEG (0x4240)
#define ASM_THUMB_FORMAT_4_CMP (0x4280)
#define ASM_THUMB_FORMAT_4_CMN (0x42c0)
#define ASM_THUMB_FORMAT_4_ORR (0x4300)
#define ASM_THUMB_FORMAT_4_MUL (0x4340)
#define ASM_THUMB_FORMAT_4_BIC (0x4380)
#define ASM_THUMB_FORMAT_4_MVN (0x43c0)

void asm_thumb_format_4(asm_thumb_t *as, uint op, uint rlo_dest, uint rlo_src);

static inline void asm_thumb_cmp_rlo_rlo(asm_thumb_t *as, uint rlo_dest, uint rlo_src) { asm_thumb_format_4(as, ASM_THUMB_FORMAT_4_CMP, rlo_dest, rlo_src); }

// FORMAT 9: load/store with immediate offset
// For word transfers the offset must be aligned, and >>2

// FORMAT 10: load/store halfword
// The offset must be aligned, and >>1
// The load is zero extended into the register

#define ASM_THUMB_FORMAT_9_STR (0x6000)
#define ASM_THUMB_FORMAT_9_LDR (0x6800)
#define ASM_THUMB_FORMAT_9_WORD_TRANSFER (0x0000)
#define ASM_THUMB_FORMAT_9_BYTE_TRANSFER (0x1000)

#define ASM_THUMB_FORMAT_10_STRH (0x8000)
#define ASM_THUMB_FORMAT_10_LDRH (0x8800)

void asm_thumb_format_9_10(asm_thumb_t *as, uint op, uint rlo_dest, uint rlo_base, uint offset);

static inline void asm_thumb_str_rlo_rlo_i5(asm_thumb_t *as, uint rlo_src, uint rlo_base, uint word_offset)
    { asm_thumb_format_9_10(as, ASM_THUMB_FORMAT_9_STR | ASM_THUMB_FORMAT_9_WORD_TRANSFER, rlo_src, rlo_base, word_offset); }
static inline void asm_thumb_strb_rlo_rlo_i5(asm_thumb_t *as, uint rlo_src, uint rlo_base, uint byte_offset)
    { asm_thumb_format_9_10(as, ASM_THUMB_FORMAT_9_STR | ASM_THUMB_FORMAT_9_BYTE_TRANSFER, rlo_src, rlo_base, byte_offset); }
static inline void asm_thumb_strh_rlo_rlo_i5(asm_thumb_t *as, uint rlo_src, uint rlo_base, uint byte_offset)
    { asm_thumb_format_9_10(as, ASM_THUMB_FORMAT_10_STRH, rlo_src, rlo_base, byte_offset); }
static inline void asm_thumb_ldr_rlo_rlo_i5(asm_thumb_t *as, uint rlo_dest, uint rlo_base, uint word_offset)
    { asm_thumb_format_9_10(as, ASM_THUMB_FORMAT_9_LDR | ASM_THUMB_FORMAT_9_WORD_TRANSFER, rlo_dest, rlo_base, word_offset); }
static inline void asm_thumb_ldrb_rlo_rlo_i5(asm_thumb_t *as, uint rlo_dest, uint rlo_base, uint byte_offset)
    { asm_thumb_format_9_10(as, ASM_THUMB_FORMAT_9_LDR | ASM_THUMB_FORMAT_9_BYTE_TRANSFER , rlo_dest, rlo_base, byte_offset); }
static inline void asm_thumb_ldrh_rlo_rlo_i5(asm_thumb_t *as, uint rlo_dest, uint rlo_base, uint byte_offset)
    { asm_thumb_format_9_10(as, ASM_THUMB_FORMAT_10_LDRH, rlo_dest, rlo_base, byte_offset); }

// TODO convert these to above format style

void asm_thumb_mov_reg_reg(asm_thumb_t *as, uint reg_dest, uint reg_src);
void asm_thumb_movw_reg_i16(asm_thumb_t *as, uint reg_dest, int i16_src);
void asm_thumb_movt_reg_i16(asm_thumb_t *as, uint reg_dest, int i16_src);
void asm_thumb_b_n(asm_thumb_t *as, uint label);
void asm_thumb_bcc_n(asm_thumb_t *as, int cond, uint label);

void asm_thumb_mov_reg_i32(asm_thumb_t *as, uint reg_dest, mp_uint_t i32_src); // convenience
void asm_thumb_mov_reg_i32_optimised(asm_thumb_t *as, uint reg_dest, int i32_src); // convenience
void asm_thumb_mov_reg_i32_aligned(asm_thumb_t *as, uint reg_dest, int i32); // convenience
void asm_thumb_mov_local_reg(asm_thumb_t *as, int local_num_dest, uint rlo_src); // convenience
void asm_thumb_mov_reg_local(asm_thumb_t *as, uint rlo_dest, int local_num); // convenience
void asm_thumb_mov_reg_local_addr(asm_thumb_t *as, uint rlo_dest, int local_num); // convenience

void asm_thumb_b_label(asm_thumb_t *as, uint label); // convenience ?
void asm_thumb_bcc_label(asm_thumb_t *as, int cc, uint label); // convenience: picks narrow or wide branch
void asm_thumb_bl_ind(asm_thumb_t *as, void *fun_ptr, uint fun_id, uint reg_temp); // convenience ?
