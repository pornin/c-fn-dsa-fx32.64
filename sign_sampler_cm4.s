	.syntax	unified
	.cpu	cortex-m4
	.file	"sign_sampler_cm4.s"
	.text

@ =======================================================================
@ int32_t fndsa_gaussian0_helper(uint64_t lo, uint32_t hi)
@ =======================================================================

	.align	2
	.global	fndsa_gaussian0_helper
	.thumb
	.thumb_func
	.type	fndsa_gaussian0_helper, %function
fndsa_gaussian0_helper:
	push.w	{ r4, r5, r6, r7, r8, r10 }

	@ Right-shift value by 1 bit (bit 0 is ignored).
	lsrs.w	r2, r2, #1
	rrxs	r1, r1
	rrxs	r0, r0

	adr.w	r12, fndsa_gaussian0_helper__gauss0_low

	@ 0 and 1
	ldm	r12!, { r4, r5, r6, r7 }
	subs	r8, r0, r4
	sbcs	r8, r1, r5
	movw	r4, #20987    @ high[0]
	sbcs	r8, r2, r4
	lsr.w	r3, r8, #31
	subs	r8, r0, r6
	sbcs	r8, r1, r7
	movw	r4, #10857    @ high[1]
	sbcs	r8, r2, r4
	add.w	r3, r3, r8, lsr #31

	@ 2 and 3
	ldm	r12!, { r4, r5, r6, r7 }
	subs	r8, r0, r4
	sbcs	r8, r1, r5
	movw	r4, #4414     @ high[2]
	sbcs	r8, r2, r4
	add.w	r3, r3, r8, lsr #31
	subs	r8, r0, r6
	sbcs	r8, r1, r7
	movw	r4, #1384     @ high[3]
	sbcs	r8, r2, r4
	add.w	r3, r3, r8, lsr #31

	@ 4 and 5
	ldm	r12!, { r4, r5, r6, r7 }
	subs	r8, r0, r4
	sbcs	r8, r1, r5
	sbcs	r8, r2, #330  @ high[4]
	add.w	r3, r3, r8, lsr #31
	subs	r8, r0, r6
	sbcs	r8, r1, r7
	sbcs	r8, r2, #59   @ high[5]
	add.w	r3, r3, r8, lsr #31

	@ 6 and 7
	ldm	r12!, { r4, r5, r6, r7 }
	subs	r8, r0, r4
	sbcs	r8, r1, r5
	sbcs	r8, r2, #8    @ high[6]
	add.w	r3, r3, r8, lsr #31
	subs	r8, r0, r6
	sbcs	r8, r1, r7
	sbcs	r8, r2, #0    @ high[7]
	add.w	r3, r3, r8, lsr #31

	@ Subsequent values are less than 2^63, thus they can modify the
	@ result only if r2 = 0 and r1 < 2^31; in that case the top bit of
	@ the subtraction of r1 is correct. We will keep making the
	@ operations, but omitting the third subtraction, and accumulating
	@ bits into r10.
	movw	r10, #0

	@ 8 and 9
	ldm	r12!, { r4, r5, r6, r7 }
	subs	r8, r0, r4
	sbcs	r8, r1, r5
	@sbcs	r8, r2, #0    @ high[8]
	add.w	r10, r10, r8, lsr #31
	subs	r8, r0, r6
	sbcs	r8, r1, r7
	@sbcs	r8, r2, #0    @ high[9]
	add.w	r10, r10, r8, lsr #31

	@ 10 and 11
	ldm	r12!, { r4, r5, r6, r7 }
	subs	r8, r0, r4
	sbcs	r8, r1, r5
	@sbcs	r8, r2, #0    @ high[10]
	add.w	r10, r10, r8, lsr #31
	subs	r8, r0, r6
	sbcs	r8, r1, r7
	@sbcs	r8, r2, #0    @ high[11]
	add.w	r10, r10, r8, lsr #31

	@ 12, 13 and 14
	ldm	r12!, { r4, r5, r6, r7 }
	subs	r8, r0, r4
	sbcs	r8, r1, r5
	@sbcs	r8, r2, #0    @ high[12]
	add.w	r10, r10, r8, lsr #31
	subs	r8, r0, r6
	sbcs	r8, r1, #7    @ mid[13]
	@sbcs	r8, r2, #0    @ high[13]
	add.w	r10, r10, r8, lsr #31
	subs	r8, r0, r7
	sbcs	r8, r1, #0    @ mid[14]
	@sbcs	r8, r2, #0    @ high[14]
	add.w	r10, r10, r8, lsr #31

	@ 15, 16 and 17
	ldm	r12!, { r4, r5, r6 }
	subs	r8, r0, r4
	sbcs	r8, r1, #0    @ mid[15]
	@sbcs	r8, r2, #0    @ high[15]
	add.w	r10, r10, r8, lsr #31
	subs	r8, r0, r5
	sbcs	r8, r1, #0    @ mid[16]
	@sbcs	r8, r2, #0    @ high[16]
	add.w	r10, r10, r8, lsr #31
	subs	r8, r0, r6
	sbcs	r8, r1, #0    @ mid[17]
	@sbcs	r8, r2, #0    @ high[1.]
	add.w	r10, r10, r8, lsr #31

	@ Result is split into r10 and r3. If r2 != 0 or r1 >= 2^31, then
	@ result in r10 is incorrect and must be cleared.
	orr	r2, r2, r1, lsr #31
	sub	r2, #1
	and	r10, r10, r2, asr #31
	add	r0, r3, r10

	pop	{ r4, r5, r6, r7, r8, r10 }
	bx	lr
	.align	3
fndsa_gaussian0_helper__gauss0_low:
	@ This is the SignDist[] table from the specification. Only the low
	@ 64 bits of each value are stored here; the high 15 bits are provided
	@ in comments but otherwise hardcoded in the instructions above.
	.word	 478938394, 4195838422  @ high: 20987
	.word	3203253495, 2508984223  @ high: 10857
	.word	 350290691, 3873982884  @ high:  4414
	.word	3433395481, 3131161571  @ high:  1384
	.word	2676996758, 3258341241  @ high:   330
	.word	3126768186, 2774772342  @ high:    59
	.word	3149231280,  309242389  @ high:     8
	.word	3601985404, 3506433586  @ high:     0
	.word	1035081267,  264268869  @ high:     0
	.word	  33961550,   14810841  @ high:     0
	.word	1746468668,     616338  @ high:     0
	.word	3313799374,      19023  @ high:     0
	.word	 785698009,        435  @ high:     0
	@ Starting at value 13, we only store the low 32 bits.
	.word	1605852722  @ mid:   7    high:     0
	.word	 397328253  @ mid:   0    high:     0
	.word	   3689579  @ mid:   0    high:     0
	.word	     25354  @ mid:   0    high:     0
	.word	       129  @ mid:   0    high:     0

	.size	fndsa_gaussian0_helper,.-fndsa_gaussian0_helper

@ =======================================================================
@ void x_fndsa_ffsamp_fft_left_inner(sampler_state *ss,
@                                    unsigned logn, unsigned flags, rx *tmp)
@ =======================================================================

	.align	2
	.global	fndsa_x_ffsamp_fft_left_inner
	.thumb
	.thumb_func
	.type	fndsa_x_ffsamp_fft_left_inner, %function
fndsa_x_ffsamp_fft_left_inner:
	@ For the recursive calls, we use a special ABI:
	@    r4   pointer to sampler_state (unmodified)
	@    r5   lo16=logn; hi16=flags
	@    r6   tmp
	@ These values must remain unmodified.
	push	{ r4, r5, r6, lr }
	movs	r4, r0
	add	r5, r1, r2, lsl #16
	movs	r6, r3
	bl	fndsa_x_ffsamp_fft_left_inner__spec
	pop	{ r4, r5, r6, pc }

@ Write address of tmpX into register rd, with X = off.
.macro TTC  rd, off
	.if ((\off) == 0)
	movs	\rd, r6
	.else
	movs	\rd, #(\off)
	lsls	\rd, r5         @ lsls uses only the low 8 bits of r5
	adds	\rd, \rd, r6
	.endif
.endm

	.thumb
	.thumb_func
	.type	fndsa_x_ffsamp_fft_left_inner__spec, %function
fndsa_x_ffsamp_fft_left_inner__spec:
	@ If logn == 1 then tail-call ffsamp_x_fft_deepest().
	uxth	r3, r5
	cmp	r3, #1
	bne	Lfndsa_x_ffsamp_fft_left_inner__1
	movs	r0, r4
	lsrs	r1, r5, #16
	movs	r2, r6
	b.w	fndsa_x_ffsamp_fft_deepest
	.align	2
Lfndsa_x_ffsamp_fft_left_inner__1:
	push	{ r5, lr }

	@ xpoly_split_selfadj_fft(logn, tmp18, tmp21, tmp12);
	uxth	r0, r5
	TTC	r1, 18
	TTC	r2, 21
	TTC	r3, 12
	bl	fndsa_xpoly_split_selfadj_fft

	@ If init0 is not set: xpoly_split_fft(logn, tmp0, tmp12)
	tst	r5, #0x00010000
	bne	Lfndsa_x_ffsamp_fft_left_inner__2
	uxth	r0, r5
	TTC	r1, 0
	TTC	r2, 12
	bl	fndsa_xpoly_split_fft
Lfndsa_x_ffsamp_fft_left_inner__2:

	@ memcpy(tmp6, tmp18, qn * sizeof(rx))
	TTC	r0, 6
	TTC	r1, 18
	movs	r2, #3
	lsls	r2, r5
	bl	memcpy

	@ xpoly_LDL_fft(logn - 1, tmp18, tmp9, tmp6, tmp21)
	TTC	r1, 18
	TTC	r2, 9
	TTC	r3, 6
	TTC	r0, 21
	push	{ r0, r1 }
	uxth	r0, r5
	subs	r0, #1
	bl	fndsa_xpoly_LDL_fft
	add	sp, #8

	@ x_ffsamp_fft_left_inner(ss, logn - 1, flags & ~FLAG_NOOUT, tmp12)
	@ adjust tmp
	movs	r0, #12
	lsls	r0, r5
	adds	r6, r0
	bfc	r5, #17, #1    @ clear flag noout
	subs	r5, #1         @ decrement logn
	bl	fndsa_x_ffsamp_fft_left_inner__spec
	ldr	r5, [sp]       @ restore r5
	movs	r0, #12
	lsls	r0, r5
	subs	r6, r0         @ restore tmp

	@ memcpy(tmp18, tmp6, hn * sizeof(rx))
	TTC	r0, 18
	TTC	r1, 6
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy

	@ memcpy(tmp6, tmp12, hn * sizeof(rx))
	TTC	r0, 6
	TTC	r1, 12
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy

	@ If init0 is not set: memcpy(tmp12, tmp0, hn * sizeof(rx))
	tst	r5, #0x00010000
	bne	Lfndsa_x_ffsamp_fft_left_inner__3
	TTC	r0, 12
	TTC	r1, 0
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy
Lfndsa_x_ffsamp_fft_left_inner__3:

	@ xpoly_mul_iXadj_fft(logn - 1, tmp0, tmp6, tmp21)
	uxth	r0, r5
	subs	r0, #1
	TTC	r1, 0
	TTC	r2, 6
	TTC	r3, 21
	bl	fndsa_xpoly_mul_iXadj_fft

	@ If init0 is set:      memcpy(tmp12, tmp0, hn * sizeof(rx))
	@ If init0 is not set:  xpoly_add(logn - 1, tmp12, tmp0)
	tst	r5, #0x00010000
	beq	Lfndsa_x_ffsamp_fft_left_inner__4
	@ init0 is set
	TTC	r0, 12
	TTC	r1, 0
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy
	b	Lfndsa_x_ffsamp_fft_left_inner__5
Lfndsa_x_ffsamp_fft_left_inner__4:
	@ init0 is not set
	uxth	r0, r5
	subs	r0, #1
	TTC	r1, 12
	TTC	r2, 0
	bl	fndsa_xpoly_add
Lfndsa_x_ffsamp_fft_left_inner__5:

	@ x_ffsamp_fft_left_inner(ss, logn - 1, flags & ~FLAG_INIT0, tmp12)
	@ adjust tmp
	movs	r0, #12
	lsls	r0, r5
	adds	r6, r0
	bfc	r5, #16, #1    @ clear flag init0
	subs	r5, #1         @ decrement logn
	bl	fndsa_x_ffsamp_fft_left_inner__spec
	ldr	r5, [sp]       @ restore r5
	movs	r0, #12
	lsls	r0, r5
	subs	r6, r0         @ restore tmp

	@ If noout is set, the last few operations are skipped.
	tst	r5, #0x00020000
	bne	Lfndsa_x_ffsamp_fft_left_inner__6

	@ xpoly_sub(logn - 1, tmp12, tmp0)
	uxth	r0, r5
	subs	r0, #1
	TTC	r1, 12
	TTC	r2, 0
	bl	fndsa_xpoly_sub

	@ memcpy(tmp18, tmp6, hn * sizeof(rx))
	TTC	r0, 18
	TTC	r1, 6
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy

	@ xpoly_merge_fft(logn, tmp0, tmp12, tmp18)
	uxth	r0, r5
	TTC	r1, 0
	TTC	r2, 12
	TTC	r3, 18
	bl	fndsa_xpoly_merge_fft

Lfndsa_x_ffsamp_fft_left_inner__6:
	pop	{ r5, pc }
	.size	fndsa_x_ffsamp_fft_left_inner, .-fndsa_x_ffsamp_fft_left_inner

@ =======================================================================
@ void x_fndsa_ffsamp_fft_right_inner(sampler_state *ss,
@                                    unsigned logn, unsigned flags, rx *tmp)
@ =======================================================================

	.align	2
	.global	fndsa_x_ffsamp_fft_right_inner
	.thumb
	.thumb_func
	.type	fndsa_x_ffsamp_fft_right_inner, %function
fndsa_x_ffsamp_fft_right_inner:
	@ For the recursive calls, we use a special ABI:
	@    r4   pointer to sampler_state (unmodified)
	@    r5   lo16=logn; hi16=flags
	@    r6   tmp
	@ These values must remain unmodified.
	push	{ r4, r5, r6, lr }
	movs	r4, r0
	add	r5, r1, r2, lsl #16
	movs	r6, r3
	bl	fndsa_x_ffsamp_fft_right_inner__spec
	pop	{ r4, r5, r6, pc }

@ We reuse macro TTC from fndsa_x_ffsamp_fft_left_inner

	.thumb
	.thumb_func
	.type	fndsa_x_ffsamp_fft_right_inner__spec, %function
fndsa_x_ffsamp_fft_right_inner__spec:
	@ If logn == 1 then adjust the leaf (symplecticity) and
	@ tail-call ffsamp_x_fft_deepest().
	uxth	r3, r5
	cmp	r3, #1
	bne	Lfndsa_x_ffsamp_fft_right_inner__1
	add	r0, r6, #24
	adr	r1, rx_QQ
	movs	r2, r0
	push	{ r5, lr }
	bl	fndsa_rx_div_spec
	pop	{ r5, lr }
	movs	r0, r4
	lsrs	r1, r5, #16
	movs	r2, r6
	b.w	fndsa_x_ffsamp_fft_deepest
	.align	2
Lfndsa_x_ffsamp_fft_right_inner__1:
	push	{ r5, lr }

	@ xpoly_split_selfadj_fft(logn, tmp18, tmp21, tmp12);
	uxth	r0, r5
	TTC	r1, 18
	TTC	r2, 21
	TTC	r3, 12
	bl	fndsa_xpoly_split_selfadj_fft

	@ If init0 is not set: xpoly_split_fft(logn, tmp0, tmp12)
	tst	r5, #0x00010000
	bne	Lfndsa_x_ffsamp_fft_right_inner__2
	uxth	r0, r5
	TTC	r1, 0
	TTC	r2, 12
	bl	fndsa_xpoly_split_fft
Lfndsa_x_ffsamp_fft_right_inner__2:

	@ xpoly_LDL_fft(logn - 1, tmp6, tmp9, tmp18, tmp21)
	TTC	r1, 6
	TTC	r2, 9
	TTC	r3, 18
	TTC	r0, 21
	push	{ r0, r1 }
	uxth	r0, r5
	subs	r0, #1
	bl	fndsa_xpoly_LDL_fft
	add	sp, #8
	@ xpoly_neg(logn - 2, tmp9)
	uxth	r0, r5
	subs	r0, #2
	TTC	r1, 9
	bl	fndsa_xpoly_neg

	@ x_ffsamp_fft_right_inner(ss, logn - 1, flags & ~FLAG_NOOUT, tmp12)
	@ adjust tmp
	movs	r0, #12
	lsls	r0, r5
	adds	r6, r0
	bfc	r5, #17, #1    @ clear flag noout
	subs	r5, #1         @ decrement logn
	bl	fndsa_x_ffsamp_fft_right_inner__spec
	ldr	r5, [sp]       @ restore r5
	movs	r0, #12
	lsls	r0, r5
	subs	r6, r0         @ restore tmp

	@ memcpy(tmp18, tmp6, hn * sizeof(rx))
	TTC	r0, 18
	TTC	r1, 6
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy

	@ memcpy(tmp6, tmp12, hn * sizeof(rx))
	TTC	r0, 6
	TTC	r1, 12
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy

	@ If init0 is not set: memcpy(tmp12, tmp0, hn * sizeof(rx))
	tst	r5, #0x00010000
	bne	Lfndsa_x_ffsamp_fft_right_inner__3
	TTC	r0, 12
	TTC	r1, 0
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy
Lfndsa_x_ffsamp_fft_right_inner__3:

	@ xpoly_mul_iXadj_fft(logn - 1, tmp0, tmp6, tmp21)
	uxth	r0, r5
	subs	r0, #1
	TTC	r1, 0
	TTC	r2, 6
	TTC	r3, 21
	bl	fndsa_xpoly_mul_iXadj_fft

	@ If init0 is set:      memcpy(tmp12, tmp0, hn * sizeof(rx))
	@ If init0 is not set:  xpoly_add(logn - 1, tmp12, tmp0)
	tst	r5, #0x00010000
	beq	Lfndsa_x_ffsamp_fft_right_inner__4
	@ init0 is set
	TTC	r0, 12
	TTC	r1, 0
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy
	b	Lfndsa_x_ffsamp_fft_right_inner__5
Lfndsa_x_ffsamp_fft_right_inner__4:
	@ init0 is not set
	uxth	r0, r5
	subs	r0, #1
	TTC	r1, 12
	TTC	r2, 0
	bl	fndsa_xpoly_add
Lfndsa_x_ffsamp_fft_right_inner__5:

	@ x_ffsamp_fft_right_inner(ss, logn - 1, flags & ~FLAG_INIT0, tmp12)
	@ adjust tmp
	movs	r0, #12
	lsls	r0, r5
	adds	r6, r0
	bfc	r5, #16, #1    @ clear flag init0
	subs	r5, #1         @ decrement logn
	bl	fndsa_x_ffsamp_fft_right_inner__spec
	ldr	r5, [sp]       @ restore r5
	movs	r0, #12
	lsls	r0, r5
	subs	r6, r0         @ restore tmp

	@ If noout is set, the last few operations are skipped.
	tst	r5, #0x00020000
	bne	Lfndsa_x_ffsamp_fft_right_inner__6

	@ xpoly_sub(logn - 1, tmp12, tmp0)
	uxth	r0, r5
	subs	r0, #1
	TTC	r1, 12
	TTC	r2, 0
	bl	fndsa_xpoly_sub

	@ memcpy(tmp18, tmp6, hn * sizeof(rx))
	TTC	r0, 18
	TTC	r1, 6
	movs	r2, #6
	lsls	r2, r5
	bl	memcpy

	@ xpoly_merge_fft(logn, tmp0, tmp12, tmp18)
	uxth	r0, r5
	TTC	r1, 0
	TTC	r2, 12
	TTC	r3, 18
	bl	fndsa_xpoly_merge_fft

Lfndsa_x_ffsamp_fft_right_inner__6:
	pop	{ r5, pc }

rx_QQ:
	.word	0, 0, 151019521      @ q^2 in rx format
	.size	fndsa_x_ffsamp_fft_right_inner, .-fndsa_x_ffsamp_fft_right_inner
