	.syntax	unified
	.cpu	cortex-m4
	.file	"sign_rx_cm4.s"
	.text

@ =======================================================================

@ d <- a*b
@ a and d are full values (96-bit)
@ b is ufrac (64-bit, unsigned)
@ rt is a temporary register
@ ra0 and rd2 may be the same register; otherwise, no overlap allowed
.macro	RX_MUL_UFRAC  rd0, rd1, rd2, ra0, ra1, ra2, rb0, rb1, rt
	@ d0:d1 <- high((a0:a1)*(b0:b1))
	umull	\rd0, \rt, \ra0, \rb0
	umull	\rd0, \rd1, \ra0, \rb1
	umaal	\rt, \rd0, \ra1, \rb0
	umaal	\rd0, \rd1, \ra1, \rb1
	@ High bit of rt must be added to d0:d1 (rounding); we merge
	@ that into next operation.

	@ d0:d1:d2 <- (d0:d1) + a2*(b0:b1)
	@ a2 is temporarily considered unsigned
	lsr	\rd2, \rt, #31
	umaal	\rd0, \rd2, \rb0, \ra2
	umaal	\rd1, \rd2, \rb1, \ra2

	@ If a2 < 0, then subtract b0:b1 from d1:d2
	and	\rt, \rb0, \ra2, asr #31
	subs.w	\rd1, \rd1, \rt
	and	\rt, \rb1, \ra2, asr #31
	sbcs.w	\rd2, \rd2, \rt
.endm

@ d <- a*b
@ a, b and d are full values (96-bit)
@ rt is a temporary register
@ no overlap allowed
.macro	RX_MUL  rd0, rd1, rd2, ra0, ra1, ra2, rb0, rb1, rb2, rt
	@ d0:d1 <- high((a0:a1)*(b0:b1))
	umull	\rd0, \rt, \ra0, \rb0
	umull	\rd0, \rd1, \ra0, \rb1
	umaal	\rt, \rd0, \ra1, \rb0
	umaal	\rd0, \rd1, \ra1, \rb1
	@ High bit of rt must be added to d0:d1 (rounding); we merge
	@ that into next operation.

	@ d0:d1:d2 <- (d0:d1) + a2*(b0:b1)
	@ a2 is temporarily considered unsigned
	lsr	\rd2, \rt, #31
	umaal	\rd0, \rd2, \rb0, \ra2
	umaal	\rd1, \rd2, \rb1, \ra2

	@ d0:d1:d2 <- (d0:d1:d2) + b2*(a0:a1) + b2*a2*2^64
	@ b2 is temporarily consideded unsigned
	mov	\rt, #0
	umaal	\rd0, \rt, \ra0, \rb2
	umaal	\rd1, \rt, \ra1, \rb2
	umaal	\rd2, \rt, \ra2, \rb2

	@ If a2 < 0 then subtract (b0:b1)*2^32 from d
	asr	\rt, \ra2, #31
	umlal	\rd1, \rd2, \rb0, \rt
	mla	\rd2, \rb0, \rt, \rd2
	mla	\rd2, \rb1, \rt, \rd2
	@ If b2 < 0 then subtract (a0:a1)*2^32 from d
	asr	\rt, \rb2, #31
	umlal	\rd1, \rd2, \ra0, \rt
	mla	\rd2, \ra0, \rt, \rd2
	mla	\rd2, \ra1, \rt, \rd2
.endm

@ =======================================================================
@ void fndsa_rx_mul_ufrac(rx d, const rx a, uint64_t b)
@ =======================================================================

	.align	2
	.global	fndsa_rx_mul_ufrac
	.thumb
	.thumb_func
	.type	fndsa_rx_mul_ufrac, %function
fndsa_rx_mul_ufrac:
	push	{ r4, r5, r6, r7, r8 }
	ldm	r1, { r4, r5, r6 }
	RX_MUL_UFRAC  r1, r7, r8, r4, r5, r6, r2, r3, r12
	stm	r0, { r1, r7, r8 }
	pop	{ r4, r5, r6, r7, r8 }
	bx	lr
	.size	fndsa_rx_mul_ufrac, .-fndsa_rx_mul_ufrac

@ =======================================================================
@ void fndsa_rx_mul(rx d, const rx a, const rx b)
@ =======================================================================

	.align	2
	.global	fndsa_rx_mul
	.thumb
	.thumb_func
	.type	fndsa_rx_mul, %function
fndsa_rx_mul:
	push	{ r4, r5, r6, r7, r8, r10 }
	ldm.w	r2, { r4, r5, r6 }
	ldm.w	r1, { r1, r2, r3 }
	RX_MUL  r7, r8, r10, r1, r2, r3, r4, r5, r6, r12
	stm	r0, { r7, r8, r10 }
	pop	{ r4, r5, r6, r7, r8, r10 }
	bx	lr
	.size	fndsa_rx_mul, .-fndsa_rx_mul

@ =======================================================================
@ void fndsa_rx_div_spec(rx d, const rx a, const rx b)
@ =======================================================================

	.align	2
	.global	fndsa_rx_div_spec
	.thumb
	.thumb_func
	.type	fndsa_rx_div_spec, %function
fndsa_rx_div_spec:
	push	{ r0, r4, r5, r6, r7, r8, r10, r11, lr }

	@ a <- r1:r2:r3
	@ b <- r4:r5:r6
	ldm	r2!, { r4, r5, r6 }
	ldm	r1, { r1, r2, r3 }

	@ Right-shift a and b so that b < 1.
	clz	r10, r6          @ r10 <- 32 - shift
	rsb	r8, r10, #32     @ r8 <- shift
	@ b <- b/2^shift
	lsr	r4, r4, r8
	lsl	r12, r5, r10
	orr	r4, r4, r12
	lsr	r5, r5, r8
	lsl	r12, r6, r10
	orr	r5, r5, r12
	@ a <- a/2^shift
	lsr	r1, r1, r8
	lsl	r12, r2, r10
	orr	r1, r1, r12
	lsr	r2, r2, r8
	lsl	r12, r3, r10
	orr	r2, r2, r12
	asr	r3, r3, r8
	@ r6 is now free

	@ If b < 2^(-32), multiply both a and b by 2^32.
	subs	r12, r5, #1
	sbcs	r12, r12       @ r12 <- -1 if r5 == 0, 0 otherwise
	@ cmov: r5 <- r4 if r12 == -1
	bics	r5, r12
	umlal	r4, r5, r12, r4
	@ clear r4 is r12 == -1
	bics	r4, r12
	@ cmov: r3 <- r2 if r12 == -1
	bics	r3, r12
	umlal	r2, r3, r12, r2
	@ cmov: r2 <- r1 if r12 == -1
	bics	r2, r12
	umlal	r1, r2, r12, r1
	@ clear r1 is r12 == -1
	bics	r1, r12

	@ Left-shift a and b so that b >= 1/2.
	clz	r8, r5           @ r8 <- shift
	rsb	r10, r8, #32     @ r10 <- 32 - shift
	@ b <- b*2^shift
	lsl	r5, r5, r8
	lsr	r12, r4, r10
	orr	r5, r5, r12
	lsl	r4, r4, r8
	@ a <- a*2^shift
	lsl	r3, r3, r8
	lsr	r12, r2, r10
	orr	r3, r3, r12
	lsl	r2, r2, r8
	lsr	r12, r1, r10
	orr	r2, r2, r12
	lsl	r1, r1, r8

	@ Save a on the stack.
	push.w	{ r1, r2, r3 }

	@ We now compute 1/b.

	@ b is in r4:r5
	@ Let x = r6:r7:r8.

	@ x <- b*(32/17)
	adr.w	r12, RX_32_17
	ldrd	r10, r11, [r12]
	mov	r12, #1
	RX_MUL_UFRAC  r6, r7, r8, r10, r11, r12, r4, r5, r1

	@ x <- (48/17) - x
	adr.w	r12, RX_48_17
	ldrd	r10, r11, [r12]
	mov	r12, #2
	subs	r6, r10, r6
	sbcs	r7, r11, r7
	sbcs	r8, r12, r8

	@ Five iterations are enough for the target precision.
	mov	r14, #5
Lfndsa_rx_div_spec__L1:
	@ Let:
	@   y = r1:r2:r3
	@   z = r10:r11:r12
	@ y <- x*b
	RX_MUL_UFRAC  r1, r2, r3, r6, r7, r8, r4, r5, r0

	@ z <- y*x
	RX_MUL  r10, r11, r12, r1, r2, r3, r6, r7, r8, r0

	@ x <- 2*x
	adds.w	r6, r6, r6
	adcs.w	r7, r7, r7
	adcs.w	r8, r8, r8

	@ x <- x - z
	subs.w	r6, r6, r10
	sbcs.w	r7, r7, r11
	sbcs.w	r8, r8, r12

	subs	r14, #1
	bne.w	Lfndsa_rx_div_spec__L1

	@ z <- x*a
	pop.w	{ r1, r2, r3 }
	RX_MUL  r10, r11, r12, r6, r7, r8, r1, r2, r3, r0

	@ d <- z
	pop.w	{ r0 }
	stm	r0, { r10, r11, r12 }

	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }

	.align	2
RX_32_17:
	.word	3789677026, 3789677025  @ implicit: 1
RX_48_17:
	.word	3537031891, 3537031890  @ implicit: 2
	.size	fndsa_rx_div_spec,.-fndsa_rx_div_spec

@ =======================================================================
@ void fndsa_rx_sqrt_spec(rx d, const rx a)
@ =======================================================================

	.align	2
	.global	fndsa_rx_sqrt_spec
	.thumb
	.thumb_func
	.type	fndsa_rx_sqrt_spec, %function
fndsa_rx_sqrt_spec:
	push	{ r0, r1, r4, r5, r6, r7, r8, r10, r11, lr }

	@ r10:r11:r12 <- b = a >> 12
	ldm	r1, { r10, r11, r12 }
	lsr	r10, r10, #12
	orr	r10, r10, r11, lsl #20
	lsr	r11, r11, #12
	orr	r11, r11, r12, lsl #20
	asr	r12, #12

	@ r0:r1 <- xf = 0.64
	adr.w	r0, RX_0_64
	ldrd	r0, r1, [r0]

	@ Eight iterations.
	mov	r14, #8
Lfndsa_rx_sqrt_spec__L1:
	@ r2:r3 <- yf = (xf*xf) / 2^64
	umull	r2, r4, r0, r0
	umull	r2, r3, r0, r1
	umaal	r4, r2, r1, r0
	umaal	r2, r3, r1, r1
	lsr	r4, r4, #31        @ rounding
	umlal	r2, r3, r4, r4

	@ r4:r5:r6 <- y = b*yf
	RX_MUL_UFRAC  r4, r5, r6, r10, r11, r12, r2, r3, r7

	@ y <- 3 - y
	movs	r7, #0
	subs	r4, r7, r4
	sbcs	r5, r7, r5
	mov.w	r7, #3
	sbcs	r6, r7, r6

	@ y <- y/2
	asrs.w	r6, r6, #1
	rrxs	r5, r5
	rrxs	r4, r4

	@ r2:r3:r7 <- y*yf
	RX_MUL_UFRAC  r2, r3, r7, r4, r5, r6, r0, r1, r8

	@ xf <- r2:r3
	movs	r0, r2
	movs	r1, r3

	subs	r14, #1
	bne.w	Lfndsa_rx_sqrt_spec__L1

	@ r2:r3 <- xf >> 6
	lsr	r2, r0, #6
	orr	r2, r2, r1, lsl #26
	lsr	r3, r1, #6

	@ r4:r5:r6 <- a*(xf >> 6)
	pop.w	{ r0, r1 }
	ldm	r1, { r7, r8, r10 }
	RX_MUL_UFRAC  r4, r5, r6, r7, r8, r10, r2, r3, r12

	@ Store result.
	stm	r0, { r4, r5, r6 }
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }

	.align	2
RX_0_64:
	.word	1889785610, 2748779069
	.size	fndsa_rx_sqrt_spec,.-fndsa_rx_sqrt_spec

@ =======================================================================
@ void fndsa_xpoly_FFT_pass3(unsigned logn, rx *d)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_FFT_pass3
	.thumb
	.thumb_func
	.type	fndsa_xpoly_FFT_pass3, %function
fndsa_xpoly_FFT_pass3:
	push	{ r4, r5, r6, r7, r8, r10, r11, lr }

	@ stack
	@   0    k
	@   4    d
	@   8    m
	@   12   loop2 counter
	@   16   &RNJ[j + m]
	subs	r0, #3
	movs	r3, #1
	lsl	r0, r3, r0           @ k = 1 << (logn - 3)
	movs	r2, #2               @ m = 2
	ldr	r4, RNJ_addr
	adds	r4, #24              @ r4 <- &RNJ[2]
	push	{ r0, r1, r2, r3, r4 }

Lfndsa_xpoly_FFT_pass3__L1:
	ldr.w	r0, [sp, #8]          @ r0 <- m
	str.w	r0, [sp, #12]         @ set loop2 counter
	ldr.w	r1, [sp, #4]          @ r1 <- &d[0]
	ldr.w	r14, [sp]             @ r14 <- k
	add	r2, r14, r14, lsl #1  @ r2 <- 3*k
	add	r2, r1, r2, lsl #2    @ r2 <- &d[k]

Lfndsa_xpoly_FFT_pass3__L2:
	@ r10:r11:r12 <- RNJ[j + m]
	ldr.w	r4, [sp, #16]
	ldm	r4!, { r10, r11, r12 }
	str.w	r4, [sp, #16]

	@ loop3 counter
	ldr.w	r14, [sp]             @ r14 <- k

Lfndsa_xpoly_FFT_pass3__L3:
	@ Upon entry:
	@    r1            &d[mj]
	@    r2            &d[mj + k]
	@    r10:r11:r12   RNJ[j + m]
	@    r14           current loop3 counter

	@ r3:r4:r5 <- d[mj + i + k]
	ldm	r2, { r3, r4, r5 }

	@ r6:r7:r8 <- xz = d[mj + i + k]*RNJ[j + m]
	RX_MUL  r6, r7, r8, r3, r4, r5, r10, r11, r12, r0

	@ r3:r4:r5 <- d[mj + i]
	ldm	r1, { r3, r4, r5 }

	@ d[mj + i + k] <- d[mj + i] - xz
	@ r2 updated
	subs.w	r0, r3, r6
	str	r0, [r2], #4
	sbcs.w	r0, r4, r7
	str	r0, [r2], #4
	sbcs.w	r0, r5, r8
	str	r0, [r2], #4

	@ d[mj + i] <- d[mj + i] + xz
	@ r1 updated
	adds.w	r0, r3, r6
	str	r0, [r1], #4
	adcs.w	r0, r4, r7
	str	r0, [r1], #4
	adcs.w	r0, r5, r8
	str	r0, [r1], #4

	@ Loop k times.
	subs	r14, #1
	bne.w	Lfndsa_xpoly_FFT_pass3__L3

	@ Update r1 and r2 for next loop2 iteration.
	ldr.w	r3, [sp]               @ r3 <- k
	add	r3, r3, r3, lsl #1     @ r3 <- 3*k
	mov.w	r1, r2
	add	r2, r1, r3, lsl #2

	@ Loop2 control.
	ldr	r0, [sp, #12]
	subs	r0, #1
	str	r0, [sp, #12]
	bne	Lfndsa_xpoly_FFT_pass3__L2

	@ Update k and m for next loop1 iteration.
	@ k = 1 for last iteration of loop1.
	ldr	r0, [sp]
	ldr	r3, [sp, #8]
	lsls	r3, #1
	str	r3, [sp, #8]
	lsrs	r0, #1
	str	r0, [sp]
	bne	Lfndsa_xpoly_FFT_pass3__L1

	add	sp, #20
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }

	.align	2
RNJ_addr:
	.word	fndsa_RNJ
	.size	fndsa_xpoly_FFT_pass3, .-fndsa_xpoly_FFT_pass3

@ =======================================================================
@ void fndsa_xpoly_add(unsigned logn, rx *a, const rx *b)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_add
	.thumb
	.thumb_func
	.type	fndsa_xpoly_add, %function
fndsa_xpoly_add:
	push.w	{ r4, r5, r6, r7 }
	mov	r12, #1
	lsl	r12, r12, r0

Lfndsa_xpoly_add__L1:
	ldm	r1, { r0, r3, r4 }
	ldm	r2!, { r5, r6, r7 }
	adds	r0, r5
	adcs	r3, r6
	adcs	r4, r7
	stm	r1!, { r0, r3, r4 }
	subs	r12, #1
	bne	Lfndsa_xpoly_add__L1

	pop	{ r4, r5, r6, r7 }
	bx	lr
	.size	fndsa_xpoly_add, .-fndsa_xpoly_add

@ =======================================================================
@ void fndsa_xpoly_sub(unsigned logn, rx *a, const rx *b)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_sub
	.thumb
	.thumb_func
	.type	fndsa_xpoly_sub, %function
fndsa_xpoly_sub:
	push.w	{ r4, r5, r6, r7 }
	mov	r12, #1
	lsl	r12, r12, r0

Lfndsa_xpoly_sub__L1:
	ldm	r1, { r0, r3, r4 }
	ldm	r2!, { r5, r6, r7 }
	subs	r0, r5
	sbcs	r3, r6
	sbcs	r4, r7
	stm	r1!, { r0, r3, r4 }
	subs	r12, #1
	bne	Lfndsa_xpoly_sub__L1

	pop	{ r4, r5, r6, r7 }
	bx	lr
	.size	fndsa_xpoly_sub, .-fndsa_xpoly_sub

@ =======================================================================
@ void fndsa_xpoly_neg(unsigned logn, rx *a)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_neg
	.thumb
	.thumb_func
	.type	fndsa_xpoly_neg, %function
fndsa_xpoly_neg:
	push	{ r4, r5 }
	movs	r5, #0
	mov	r12, #1
	lsl	r12, r12, r0

Lfndsa_xpoly_neg__L1:
	ldm	r1, { r0, r3, r4 }
	subs.w	r0, r5, r0
	sbcs.w	r3, r5, r3
	sbcs.w	r4, r5, r4
	stm	r1!, { r0, r3, r4 }
	subs	r12, #1
	bne	Lfndsa_xpoly_neg__L1

	pop	{ r4, r5 }
	bx	lr
	.size	fndsa_xpoly_neg, .-fndsa_xpoly_neg

@ =======================================================================
@ void fndsa_xpoly_mul_fft(unsigned logn, rx *a, const rx *b)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_mul_fft
	.thumb
	.thumb_func
	.type	fndsa_xpoly_mul_fft, %function
fndsa_xpoly_mul_fft:
	push	{ r4, r5, r6, r7, r8, r10, r11, lr }
	sub.w	sp, #28

	@ r14 <- 6*n = 12*hn
	mov	r14, #6
	lsl	r14, r14, r0
	@ sp[24] <- 6*n
	str.w	r14, [sp, #24]

Lfndsa_xpoly_mul_fft__L1:
	ldr	r0, [sp, #24]   @ r0 <- 12*hn

	@ r6:r7:r8 <- a_im = a[i + hn]
	add	r6, r1, r0
	ldm.w	r6, { r6, r7, r8 }
	@ r3:r4:r5 <- a_re = a[i]
	ldm.w	r1, { r3, r4, r5 }
	@ r10:r11:r12 <- t_re = a_re + a_im
	adds	r10, r3, r6
	adcs	r11, r4, r7
	adcs	r12, r5, r8

	@ r6:r7:r8 <- b_im = b[i + hn]
	add	r6, r2, r0
	ldm.w	r6, { r6, r7, r8 }
	@ r3:r4:r5 <- b_re = b[i]
	ldm.w	r2, { r3, r4, r5 }
	@ r6:r7:r8 <- t_im = b_re + b_im
	adds.w	r6, r3, r6
	adcs.w	r7, r4, r7
	adcs.w	r8, r5, r8

	@ sp[12..23] <- t_re*t_im
	RX_MUL  r3, r4, r5, r6, r7, r8, r10, r11, r12, r0
	str.w	r3, [sp, #12]
	str.w	r4, [sp, #16]
	str.w	r5, [sp, #20]

	@ r3:r4:r5 <- a_im
	ldr	r0, [sp, #24]   @ r0 <- 12*hn
	add	r3, r1, r0
	ldm.w	r3, { r3, r4, r5 }
	@ r6:r7:r8 <- b_im
	add	r6, r2, r0
	ldm.w	r6, { r6, r7, r8 }
	@ sp[0..11] <- a_im*b_im
	RX_MUL  r10, r11, r12, r3, r4, r5, r6, r7, r8, r0
	str.w	r10, [sp]
	str.w	r11, [sp, #4]
	str.w	r12, [sp, #8]

	@ r3:r4:r5 <- a_re
	ldm.w	r1, { r3, r4, r5 }
	@ r6:r7:r8 <- b_re  (and update r2)
	ldm.w	r2!, { r6, r7, r8 }
	@ r10:r11:r12 <- a_re*b_re
	RX_MUL  r10, r11, r12, r3, r4, r5, r6, r7, r8, r0

	@ r3:r4:r5 <- a_im*b_im
	@ r6:r7:r8 <- t_re*t_im
	mov.w	r3, sp
	ldm.w	r3, { r3, r4, r5, r6, r7, r8 }

	@ a[i + hn] <- t_re*t_im - a_re*b_re - a_im*b_im = a_re*b_im + a_im*b_re
	subs.w	r6, r6, r3
	sbcs.w	r7, r7, r4
	sbcs.w	r8, r8, r5
	subs.w	r6, r6, r10
	sbcs.w	r7, r7, r11
	sbcs.w	r8, r8, r12
	ldr.w	r0, [sp, #24]
	add.w	r0, r0, r1
	stm.w	r0, { r6, r7, r8 }

	@ a[i] <- a_re*b_re - a_im*b_im  (and update r1)
	subs.w	r10, r10, r3
	sbcs.w	r11, r11, r4
	sbcs.w	r12, r12, r5
	stm.w	r1!, { r10, r11, r12 }

	@ r14 starts at 6*n; we want n/2 iterations.
	subs	r14, #12
	bne	Lfndsa_xpoly_mul_fft__L1

	add	sp, #28
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }
	.size	fndsa_xpoly_mul_fft, .-fndsa_xpoly_mul_fft

@ =======================================================================
@ void fndsa_xpoly_div_selfadj_spec_fft(unsigned logn, rx *a, const rx *b)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_div_selfadj_spec_fft
	.thumb
	.thumb_func
	.type	fndsa_xpoly_div_selfadj_spec_fft, %function
fndsa_xpoly_div_selfadj_spec_fft:
	@ r0 <- 12*hn
	mov	r12, #2
	lsl	r12, r12, r0
	add	r0, r12, r12, lsl #1

	push.w	{ r0, r1, r2, r4, r5, r6, r7, r8, r10, r11, lr }
	sub.w	sp, #12

	mov.w	r11, r0    @ r11 <- loop counter
Lfndsa_xpoly_div_selfadj_spec_fft__L1:
	@ sp[0..11]   xb
	@ sp[12]      12*hn
	@ sp[16]      &a[i]
	@ sp[20]      &b[i]

	@ xb <- 1/b[i]
	@ update &b[i]
	mov	r0, sp
	adr	r1, RX_ONE
	ldr.w	r2, [sp, #20]
	add.w	r3, r2, #12
	str.w	r3, [sp, #20]
	bl	fndsa_rx_div_spec

	@ r0:r1:r2 <- xb
	ldr.w	r0, [sp]
	ldr.w	r1, [sp, #4]
	ldr.w	r2, [sp, #8]

	@ r12 <- &a[i]
	ldr.w	r12, [sp, #16]

	@ a[i] <- a[i]*xb
	@ r3 <- &a[i]
	@ update a[i]
	ldm.w	r12, { r3, r4, r5 }
	RX_MUL	r6, r7, r8, r0, r1, r2, r3, r4, r5, r10
	mov.w	r3, r12
	stm.w	r12!, { r6, r7, r8 }
	str.w	r12, [sp, #16]

	@ r12 <- &a[i + hn]
	ldr.w	r4, [sp, #12]
	add.w	r12, r3, r4

	@ a[i + hn] <- a[i + hn]*xb
	ldm.w	r12, { r3, r4, r5 }
	RX_MUL	r6, r7, r8, r0, r1, r2, r3, r4, r5, r10
	stm.w	r12, { r6, r7, r8 }

	@ We run n/2 iterations.
	subs	r11, #12
	bne	Lfndsa_xpoly_div_selfadj_spec_fft__L1

	add	sp, #24
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }
RX_ONE:
	.word	0, 0, 1
	.size	fndsa_xpoly_div_selfadj_spec_fft, .-fndsa_xpoly_div_selfadj_spec_fft

@ =======================================================================
@ void fndsa_xpoly_mul_iXadj_fft(unsigned logn, rx *d, const rx *a, const rx *b)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_mul_iXadj_fft
	.thumb
	.thumb_func
	.type	fndsa_xpoly_mul_iXadj_fft, %function
fndsa_xpoly_mul_iXadj_fft:
	push	{ r4, r5, r6, r7, r8, r10, r11, lr }

	@ r14 <- 12*hn  (loop counter)
	mov.w	r14, #6
	lsl	r14, r14, r0

	ldr.w	r0, X_PLUS_1_SQUARED_OVER_X_addr
	add.w	r0, r14
	ldr.w	r4, X_MINUS_1_OVER_X_PLUS_1_TIMES_I_addr
	add.w	r4, r14
	push.w	{ r0, r3, r4, r14 }
	sub.w	sp, #12

	@ Stack:
	@   0..11   slot for bt
	@   12      &X_PLUS_1_SQUARED_OVER_X_addr[i + hn]
	@   16      &b[i]
	@   20      &X_MINUS_1_OVER_X_PLUS_1_TIMES_I[i + hn]
	@   24      12*hn
	@ We keep:
	@   r1      &d[i]
	@   r2      &a[i]
Lfndsa_xpoly_mul_iXadj_fft__L1:
	@ r3:r4:r5 <- b[i]  (and update b pointer)
	ldr.w	r0, [sp, #16]
	ldm.w	r0!, { r3, r4, r5 }
	str.w	r0, [sp, #16]

	@ r6:r7:r8 <- X_PLUS_1_SQUARED_OVER_X[i + hn]  (and update pointer)
	ldr.w	r0, [sp, #12]
	ldm.w	r0!, { r6, r7, r8 }
	str.w	r0, [sp, #12]

	@ sp[0..11] <- bt = (b[i]*X_PLUS_1_SQUARED_OVER_X[i + hn])/2
	RX_MUL  r10, r11, r12, r3, r4, r5, r6, r7, r8, r0
	asrs	r12, r12, #1
	str.w	r12, [sp, #8]
	rrxs	r11, r11
	str.w	r11, [sp, #4]
	rrxs	r10, r10
	str.w	r10, [sp]

	@ r3:r4:r5 <- a[i + hn]
	ldr.w	r0, [sp, #24]
	add.w	r0, r2, r0
	ldm.w	r0, { r3, r4, r5 }

	@ r6:r7:r8 <- X_MINUS_1_OVER_X_PLUS_1_TIMES_I[i + hn]
	ldr.w	r0, [sp, #20]
	ldm.w	r0, { r6, r7, r8 }

	@ r10:r11:r12 <- t = a[i + hn]*X_MINUS_1_OVER_X_PLUS_1_TIMES_I[i + hn]
	RX_MUL  r10, r11, r12, r3, r4, r5, r6, r7, r8, r0

	@ r10:r11:r12 <- u = t + a[i]
	ldm.w	r2, { r3, r4, r5 }
	adds	r10, r10, r3
	adcs	r11, r11, r4
	adcs	r12, r12, r5

	@ d[i] <- bt*u
	ldr.w	r3, [sp]
	ldr.w	r4, [sp, #4]
	ldr.w	r5, [sp, #8]
	RX_MUL  r6, r7, r8, r3, r4, r5, r10, r11, r12, r0
	stm.w	r1, { r6, r7, r8 }

	@ r3:r4:r5 <- a[i]
	ldm.w	r2, { r3, r4, r5 }

	@ r6:r7:r8 <- X_MINUS_1_OVER_X_PLUS_1_TIMES_I[i + hn] (updated)
	ldr.w	r0, [sp, #20]
	ldm.w	r0!, { r6, r7, r8 }
	str.w	r0, [sp, #20]

	@ r10:r11:r12 <- v = a[i]*X_MINUS_1_OVER_X_PLUS_1_TIMES_I[i + hn]
	RX_MUL  r10, r11, r12, r3, r4, r5, r6, r7, r8, r0

	@ r10:r11:r12 <- w = a[i + hn] - v
	ldr.w	r0, [sp, #24]
	add.w	r0, r0, r2
	ldm.w	r0, { r3, r4, r5 }
	subs.w	r10, r3, r10
	sbcs.w	r11, r4, r11
	sbcs.w	r12, r5, r12

	@ d[i + hn] <- bt*w
	ldr.w	r6, [sp]
	ldr.w	r7, [sp, #4]
	ldr.w	r8, [sp, #8]
	RX_MUL  r3, r4, r5, r6, r7, r8, r10, r11, r12, r0
	ldr.w	r0, [sp, #24]
	add.w	r0, r0, r1
	stm.w	r0, { r3, r4, r5 }

	@ update &d[i] and &a[i]
	adds	r1, r1, #12
	adds	r2, r2, #12

	subs	r14, #12
	bne	Lfndsa_xpoly_mul_iXadj_fft__L1

	add	sp, #28
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }

	.align	2
X_PLUS_1_SQUARED_OVER_X_addr:
	.word	fndsa_X_PLUS_1_SQUARED_OVER_X
X_MINUS_1_OVER_X_PLUS_1_TIMES_I_addr:
	.word	fndsa_X_MINUS_1_OVER_X_PLUS_1_TIMES_I
	.size	fndsa_xpoly_mul_iXadj_fft, .-fndsa_xpoly_mul_iXadj_fft

@ =======================================================================
@ void fndsa_xpoly_LDL_fft(unsigned logn, rx *d, rx *e,
@                          const rx *a0, const rx *b1)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_LDL_fft
	.thumb
	.thumb_func
	.type	fndsa_xpoly_LDL_fft, %function
fndsa_xpoly_LDL_fft:
	cmp	r0, #1
	bne	Lfndsa_xpoly_LDL_fft__L1

	push.w	{ r4, lr }
	ldr.w	r4, [sp, #8]    @ r4 <- b1

	@ n = 2
	@ e[0] <- b1[0]/(2*a[0])
	@ d[0] <- a[0] - e[0]*b1

	@ sp[0..11] <- t = b1[0]/a[0]
	push.w	{ r1, r2, r3 }
	sub	sp, #12
	mov	r0, sp
	movs	r1, r4
	movs	r2, r3
	bl	fndsa_rx_div_spec

	@ sp[0..11]   t
	@ sp[12]      d
	@ sp[16]      e
	@ sp[20]      a0
	@ r4          b1

	@ e[0] <- t/2
	ldr.w	r0, [sp]
	ldr.w	r1, [sp, #4]
	ldr.w	r2, [sp, #8]
	asrs.w	r2, r2, #1
	rrxs	r1, r1
	rrxs	r0, r0
	ldr.w	r3, [sp, #16]
	stm.w	r3, { r0, r1, r2 }

	@ r3:r4:r5 <- t' = e[0]*b1[0]
	push.w	{ r5, r6, r7, r8 }
	ldm.w	r4, { r6, r7, r8 }
	RX_MUL  r3, r4, r5, r6, r7, r8, r0, r1, r2, r12

	@ d[0] <- a0[0] - t'
	ldr.w	r12, [sp, #36]
	ldm.w	r12, { r0, r1, r2 }
	subs.w	r0, r0, r3
	sbcs.w	r1, r1, r4
	sbcs.w	r2, r2, r5
	ldr.w	r12, [sp, #28]
	stm.w	r12, { r0, r1, r2 }

	pop.w	{ r5, r6, r7, r8 }
	add	sp, #24
	pop	{ r4, pc }

	.align	2
Lfndsa_xpoly_LDL_fft__L1:
	@ r12 <- n
	mov	r12, #1
	lsl	r12, r12, r0

	@ r0 <- &X_PLUS_1_SQUARED_OVER_X[hn]
	ldr.w	r0, X_PLUS_1_SQUARED_OVER_X_addr
	add	r0, r0, r12, lsl #2
	add	r0, r0, r12, lsl #1
	push.w	{ r0, r1, r2, r3, r4, r5, r6, r7, r8, r11, lr }
	sub.w	sp, #12

	@ r11   loop counter (b/2 iterations, starts at n)
	mov.w	r11, r12
Lfndsa_xpoly_LDL_fft__L2:
	@ sp[0..11]   t
	@ sp[12]      &X_PLUS_1_SQUARED_OVER_X[hn + i]
	@ sp[16]      &d[i]
	@ sp[20]      &e[i]
	@ sp[24]      &a0[i]
	@ sp[56]      &b1[i]
	@ r11         loop counter

	@ sp[0..11] <- t = a0[i]*X_PLUS_1_SQUARED_OVER_X[hn + i]
	@ pointer &X_PLUS_1_SQUARED_OVER_X[hn + i] is updated
	ldr.w	r12, [sp, #12]
	ldm.w	r12!, { r0, r1, r2 }
	str.w	r12, [sp, #12]
	ldr.w	r12, [sp, #24]
	ldm.w	r12, { r3, r4, r5 }
	RX_MUL  r6, r7, r8, r3, r4, r5, r0, r1, r2, r12
	str.w	r6, [sp]
	str.w	r7, [sp, #4]
	str.w	r8, [sp, #8]

	@ e[i] <- b1[i]/t
	ldr.w	r0, [sp, #20]
	ldr.w	r1, [sp, #56]
	mov.w	r2, sp
	bl	fndsa_rx_div_spec

	@ r6:r7:r8 <- t' = e[i]*b1[i]
	@ &e[i] and &b1[i] are updated
	ldr.w	r12, [sp, #20]
	ldm.w	r12!, { r0, r1, r2 }
	str.w	r12, [sp, #20]
	ldr.w	r12, [sp, #56]
	ldm.w	r12!, { r3, r4, r5 }
	str.w	r12, [sp, #56]
	RX_MUL  r6, r7, r8, r0, r1, r2, r3, r4, r5, r12

	@ d[i] <- a0[i] - t'
	@ &d[i] and &a0[i] are updated
	ldr.w	r12, [sp, #24]
	ldm.w	r12!, { r0, r1, r2 }
	str.w	r12, [sp, #24]
	subs.w	r0, r0, r6
	sbcs.w	r1, r1, r7
	sbcs.w	r2, r2, r8
	ldr.w	r12, [sp, #16]
	stm.w	r12!, { r0, r1, r2 }
	str.w	r12, [sp, #16]

	subs	r11, #2
	bne	Lfndsa_xpoly_LDL_fft__L2

	add	sp, #28
	pop	{ r4, r5, r6, r7, r8, r11, pc }
	.size	fndsa_xpoly_LDL_fft, .-fndsa_xpoly_LDL_fft

@ =======================================================================
@ void fndsa_xpoly_split_fft(unsigned logn, rx *f, rx *f1)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_split_fft
	.thumb
	.thumb_func
	.type	fndsa_xpoly_split_fft, %function
fndsa_xpoly_split_fft:
	cmp	r0, #1
	bne	Lfndsa_xpoly_split_fft__1

	@ logn = 1
	@ f1[0] <- f[1]
	adds	r1, #12
	ldm	r1, { r0, r1, r3 }
	stm	r2!, { r0, r1, r3 }
	bx	lr

	.align	2
Lfndsa_xpoly_split_fft__1:
	cmp	r0, #2
	bne	Lfndsa_xpoly_split_fft__2

	push	{ r4, r5, r6, r7, r8, r10, r11, lr }
	@ logn = 2
	@ hn = 2, qn = 1
	@ s_re = s_im = x_SIN[1] = 13043817825332782212 = s
	@ t_re = f[0] + f[1]
	@ u_re = f[0] - f[1]
	@ t_im = f[2] + f[3]
	@ u_im = f[2] - f[3]
	@ f[0] <- t_re/2
	@ f[1] <- t_im/2
	@ t0 <- u_re*s
	@ t1 <- u_im*s
	@ f1[0] <- (t1 + t0)/2
	@ f1[1] <- (t1 - t0)/2

	@ r3:r4:r5 <- f[0]
	@ r6:r7:r8 <- f[1]
	ldm	r1, { r3, r4, r5, r6, r7, r8 }

	@ f[0] <- (f[0] + f[1])/2
	adds	r10, r3, r6
	adcs	r11, r4, r7
	adcs	r12, r5, r8
	asrs	r12, r12, #1
	rrxs	r11, r11
	rrxs	r10, r10
	stm	r1!, { r10, r11, r12 }

	@ r10:r11:r12 <- u_re = f[0] - f[1]
	subs	r10, r3, r6
	sbcs	r11, r4, r7
	sbcs	r12, r5, r8

	@ r3:r4:r5 <- f[2]
	@ r6:r7:r8 <- f[3]
	adds	r1, #12
	ldm	r1, { r3, r4, r5, r6, r7, r8 }

	@ f[1] <- (f[2] + f[3])/2
	adds	r0, r3, r6
	adcs	r14, r4, r7
	push	{ r0 }
	adcs	r0, r5, r8
	asrs	r0, r0, #1
	str	r0, [r1, #-4]
	rrxs	r14, r14
	str	r14, [r1, #-8]
	pop	{ r0 }
	rrxs	r0, r0
	str	r0, [r1, #-12]

	@ r1 is now free

	@ r3:r4:r5 <- u_im = f[2] - f[3]
	subs	r3, r3, r6
	sbcs	r4, r4, r7
	sbcs	r5, r5, r8

	@ r0:r1 <- s
	adr.w	r0, x_SIN_1
	ldrd	r0, r1, [r0]

	@ r6:r7:r8 <- t0 = u_re*s
	RX_MUL_UFRAC  r6, r7, r8, r10, r11, r12, r0, r1, r14

	@ r10:r11:r12 <- t1 = u_im*s
	RX_MUL_UFRAC  r10, r11, r12, r3, r4, r5, r0, r1, r14

	@ r3:r4:r5 <- (t0 + t1)/2
	adds	r3, r6, r10
	adcs	r4, r7, r11
	adcs	r5, r8, r12
	asrs	r5, r5, #1
	rrxs	r4, r4
	rrxs	r3, r3

	@ r6:r7:r8 <- (t1 - t0)/2
	subs	r6, r10, r6
	sbcs	r7, r11, r7
	sbcs	r8, r12, r8
	asrs	r8, r8, #1
	rrxs	r7, r7
	rrxs	r6, r6

	@ write f1[0] and f1[1]
	stm	r2, { r3, r4, r5, r6, r7, r8 }
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }

	.align	2
Lfndsa_xpoly_split_fft__2:
	push	{ r4, r5, r6, r7, r8, r10, r11, lr }
	sub.w	sp, #24

	@ r0 <- qn*8
	mov	r12, #2
	lsl	r0, r12, r0
	push.w	{ r0, r1, r2 }

	@ Stack layout:
	@    0       saved r0 = 8*qn
	@    4       saved f (updated)
	@    8       saved f1 (updated)
	@   12..23   slot 1 (12 bytes)
	@   24..35   slot 2 (12 bytes)

	@ Loop runs for qn/2 iterations.
	lsr	r14, r0, #1
Lfndsa_xpoly_split_fft__3:
	@ At loop entry:
	@   r14 = 8*(qn/2 - (i >> 1))

	ldr.w	r0, [sp]              @ r0 <- 8*qn

	@ r1 <- 8*(qn + (i >> 1))
	sub	r1, r0, r14
	add	r1, r1, r0, lsr #1

	@ Update r14 for next iteration.
	sub	r14, #8               @ r14 <- 8*(qn/2 - 1 - (i >> 1))

	@ r2 <- 8*(hn - 1 - (i >> 1))
	add	r2, r14, r0, lsr #1
	add.w	r2, r2, r0

	@ r8:r10 <- s_re = x_SIN[hn - 1 - (i >> 1)]
	@ r11:r12 <- s_im = x_SIN[qn + (i >> 1)]
	ldr.w	r10, x_SIN_addr
	add	r8, r10, r1
	ldrd	r11, r12, [r8]
	add	r8, r10, r2
	ldrd	r8, r10, [r8]

	@ ====== i = 0 mod 2 ======

	@ r2:r3:r4 <- f[j]
	@ r5:r6:r7 <- f[j + 1]
	ldr.w	r1, [sp, #4]
	ldm	r1, { r2, r3, r4, r5, r6, r7 }

	@ update f for next iteration
	add	r0, r1, #24
	str.w	r0, [sp, #4]

	@ sp[12..23] <- u_re = f[j] - f[j + 1]
	subs	r0, r2, r5
	str	r0, [sp, #12]
	sbcs	r0, r3, r6
	str	r0, [sp, #16]
	sbcs	r0, r4, r7
	str	r0, [sp, #20]

	@ f[j] <- (f[j] + f[j + 1])/2
	adds	r2, r2, r5
	adcs	r3, r3, r6
	adcs	r4, r4, r7
	asrs	r4, r4, #1
	rrxs	r3, r3
	rrxs	r2, r2
	stm	r1, { r2, r3, r4 }

	@ r2:r3:r4 <- f[j + hn]
	@ r5:r6:r7 <- f[j + 1 + hn]
	ldr.w	r0, [sp]              @ r0 <- 8*qn
	add	r0, r0, r0, lsr #1    @ r0 <- 12*qn
	add	r1, r1, r0, lsl #1    @ r1 <- &f[j + hn]
	ldm	r1, { r2, r3, r4, r5, r6, r7 }

	@ sp[24..35] <- u_im = f[j + hn] - f[j + 1 + hn]
	subs	r0, r2, r5
	str	r0, [sp, #24]
	sbcs	r0, r3, r6
	str	r0, [sp, #28]
	sbcs	r0, r4, r7
	str	r0, [sp, #32]

	@ f[j + hn] <- (f[j + hn] + f[j + 1 + hn])/2
	adds	r2, r2, r5
	adcs	r3, r3, r6
	adcs	r4, r4, r7
	asrs	r4, r4, #1
	rrxs	r3, r3
	rrxs	r2, r2
	stm	r1, { r2, r3, r4 }

	@ r0:r1:r2 <- t2 = u_re*s_im
	ldr.w	r3, [sp, #12]
	ldr.w	r4, [sp, #16]
	ldr.w	r5, [sp, #20]
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r11, r12, r7

	@ sp[12..23] <- t2
	str.w	r0, [sp, #12]
	str.w	r1, [sp, #16]
	str.w	r2, [sp, #20]

	@ r0:r1:r2 <- t0 = u_re*s_re
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r8, r10, r7

	@ r3:r4:r5 <- u_im
	ldr.w	r3, [sp, #24]
	ldr.w	r4, [sp, #28]
	ldr.w	r5, [sp, #32]

	@ sp[24..35] <- t0
	str.w	r0, [sp, #24]
	str.w	r1, [sp, #28]
	str.w	r2, [sp, #32]

	@ r0:r1:r2 <- t1 = u_im*s_im
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r11, r12, r7

	@ f1[i] <- (t0 + t1)/2
	ldrd	r6, r7, [sp, #24]
	adds.w	r0, r0, r6
	ldr.w	r6, [sp, #32]
	adcs.w	r1, r1, r7
	adcs.w	r2, r2, r6
	asrs.w	r2, #1
	rrxs	r1, r1
	rrxs	r0, r0
	ldr.w	r6, [sp, #8]      @ r6 <- &f1[i]
	stm	r6, { r0, r1, r2 }

	@ r0:r1:r2 <- t3 = u_im*s_re
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r8, r10, r7

	@ f1[i + qn] <- (t3 - t2)/2
	ldr.w	r3, [sp, #12]
	ldr.w	r4, [sp, #16]
	ldr.w	r5, [sp, #20]
	subs.w	r0, r0, r3
	sbcs.w	r1, r1, r4
	sbcs.w	r2, r2, r5
	asrs.w	r2, #1
	rrxs	r1, r1
	rrxs	r0, r0
	ldr.w	r7, [sp]             @ r7 <- 8*qn
	add	r7, r7, r7, lsr #1   @ r7 <- 12*qn
	add.w	r7, r6, r7           @ r7 <- &f1[i + qn]
	stm	r7, { r0, r1, r2 }

	@ update f1
	add.w	r6, #12
	str.w	r6, [sp, #8]

	@ ====== i = 1 mod 2 ======

	@ r2:r3:r4 <- f[j]
	@ r5:r6:r7 <- f[j + 1]
	ldr.w	r1, [sp, #4]
	ldm	r1, { r2, r3, r4, r5, r6, r7 }

	@ update f for next iteration
	add	r0, r1, #24
	str.w	r0, [sp, #4]

	@ sp[12..23] <- u_re = f[j] - f[j + 1]
	subs	r0, r2, r5
	str	r0, [sp, #12]
	sbcs	r0, r3, r6
	str	r0, [sp, #16]
	sbcs	r0, r4, r7
	str	r0, [sp, #20]

	@ f[j] <- (f[j] + f[j + 1])/2
	adds	r2, r2, r5
	adcs	r3, r3, r6
	adcs	r4, r4, r7
	asrs	r4, r4, #1
	rrxs	r3, r3
	rrxs	r2, r2
	stm	r1, { r2, r3, r4 }

	@ r2:r3:r4 <- f[j + hn]
	@ r5:r6:r7 <- f[j + 1 + hn]
	ldr.w	r0, [sp]              @ r0 <- 8*qn
	add	r0, r0, r0, lsr #1    @ r0 <- 12*qn
	add	r1, r1, r0, lsl #1    @ r1 <- &f[j + hn]
	ldm	r1, { r2, r3, r4, r5, r6, r7 }

	@ sp[24..35] <- u_im = f[j + hn] - f[j + 1 + hn]
	subs	r0, r2, r5
	str	r0, [sp, #24]
	sbcs	r0, r3, r6
	str	r0, [sp, #28]
	sbcs	r0, r4, r7
	str	r0, [sp, #32]

	@ f[j + hn] <- (f[j + hn] + f[j + 1 + hn])/2
	adds	r2, r2, r5
	adcs	r3, r3, r6
	adcs	r4, r4, r7
	asrs	r4, r4, #1
	rrxs	r3, r3
	rrxs	r2, r2
	stm	r1, { r2, r3, r4 }

	@ r0:r1:r2 <- t2 = u_re*s_re
	ldr.w	r3, [sp, #12]
	ldr.w	r4, [sp, #16]
	ldr.w	r5, [sp, #20]
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r8, r10, r7

	@ sp[12..23] <- t2
	str.w	r0, [sp, #12]
	str.w	r1, [sp, #16]
	str.w	r2, [sp, #20]

	@ r0:r1:r2 <- t0 = u_re*s_im
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r11, r12, r7

	@ r3:r4:r5 <- u_im
	ldr.w	r3, [sp, #24]
	ldr.w	r4, [sp, #28]
	ldr.w	r5, [sp, #32]

	@ sp[24..35] <- t0
	str.w	r0, [sp, #24]
	str.w	r1, [sp, #28]
	str.w	r2, [sp, #32]

	@ r0:r1:r2 <- t1 = u_im*s_re
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r8, r10, r7

	@ f1[i] <- (t1 - t0)/2
	ldrd	r6, r7, [sp, #24]
	subs.w	r0, r0, r6
	ldr.w	r6, [sp, #32]
	sbcs.w	r1, r1, r7
	sbcs.w	r2, r2, r6
	asrs.w	r2, #1
	rrxs	r1, r1
	rrxs	r0, r0
	ldr.w	r6, [sp, #8]      @ r6 <- &f1[i]
	stm	r6, { r0, r1, r2 }

	@ r0:r1:r2 <- t3 = u_im*s_im
	RX_MUL_UFRAC  r0, r1, r2, r3, r4, r5, r11, r12, r7

	@ f1[i + qn] <- -(t2 + t3)/2
	ldr.w	r3, [sp, #12]
	ldr.w	r4, [sp, #16]
	ldr.w	r5, [sp, #20]
	adds.w	r0, r0, r3
	adcs.w	r1, r1, r4
	adcs.w	r2, r2, r5
	mov.w	r3, #0
	subs.w	r0, r3, r0
	sbcs.w	r1, r3, r1
	sbcs.w	r2, r3, r2
	asrs.w	r2, #1
	rrxs	r1, r1
	rrxs	r0, r0
	ldr.w	r7, [sp]             @ r7 <- 8*qn
	add	r7, r7, r7, lsr #1   @ r7 <- 12*qn
	add.w	r7, r6, r7           @ r7 <- &f1[i + qn]
	stm	r7, { r0, r1, r2 }

	@ update f1
	add.w	r6, #12
	str.w	r6, [sp, #8]

	@ Iterate until qn/2 - (i >> 1) reaches 0.
	cmp	r14, #0
	bne	Lfndsa_xpoly_split_fft__3

	@ Second pass: squeeze holes out in f.
	@ At this point, sp+4 contains &f[hn]
	ldrd	r0, r1, [sp]
	add	r0, r0, r0, lsl #1    @ r0 <- 24*qn = 12*hn
	subs	r1, r1, r0            @ r1 <- &f[0]
	movs	r2, r1                @ r2 <- &f[0]

Lfndsa_xpoly_split_fft__4:
	ldm	r2!, { r3, r4, r5 }
	adds	r2, #12
	stm	r1!, { r3, r4, r5 }
	subs	r0, #12
	bne	Lfndsa_xpoly_split_fft__4

	add	sp, #36
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }
	.size	fndsa_xpoly_split_fft,.-fndsa_xpoly_split_fft

@ =======================================================================
@ void fndsa_xpoly_split_selfadj_fft(unsigned logn, rx *a0, rx *b1, const rx *a)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_split_selfadj_fft
	.thumb
	.thumb_func
	.type	fndsa_xpoly_split_selfadj_fft, %function
fndsa_xpoly_split_selfadj_fft:
	cmp	r0, #1
	bne	Lfndsa_xpoly_split_selfadj_fft__1

	@ a0[0] <- a[0]
	@ b1[0] <- 0
	ldm	r3, { r0, r3, r12 }
	stm	r1, { r0, r3, r12 }
	movs	r0, #0
	str	r0, [r2], #4
	str	r0, [r2], #4
	str	r0, [r2], #4
	bx	lr

	.align	2
Lfndsa_xpoly_split_selfadj_fft__1:
	cmp	r0, #2
	bne	Lfndsa_xpoly_split_selfadj_fft__2

	push	{ r4, r5, r6, r7, r8, r10, r11 }

	@ r3:r4:r5 <- a[0]
	@ r6:r7:r8 <- a[1]
	ldm	r3, { r3, r4, r5, r6, r7, r8 }

	@ a0[0] <- (a[0] + a[1])/2
	adds	r10, r3, r6
	adcs	r11, r4, r7
	adcs	r12, r5, r8
	asrs	r12, r12, #1
	rrxs	r11, r11
	rrxs	r10, r10
	stm.w	r1, { r10, r11, r12 }

	@ r3:r4:r5 <- t1 = a[0] - a[1]
	subs.w	r3, r3, r6
	sbcs.w	r4, r4, r7
	sbcs.w	r5, r5, r8

	@ b1[0] <- t1*IRNJ[1]
	ldr.w	r6, IRNJ_addr
	ldrd	r6, r7, [r6, #8]

	@ b1[0] <- t1*IRNJ[1]
	RX_MUL_UFRAC  r10, r11, r12, r3, r4, r5, r6, r7, r0
	stm	r2, { r10, r11, r12 }

	pop	{ r4, r5, r6, r7, r8, r10, r11 }
	bx	lr

	.align	2
Lfndsa_xpoly_split_selfadj_fft__2:
	push	{ r4, r5, r6, r7, r8, r10, r11, lr }

	@ r14 <- 8*qn
	mov	r14, #2
	lsl	r14, r14, r0

	@ r12 <- &IRNJ[qn]
	ldr.w	r12, IRNJ_addr
	add.w	r12, r12, r14

Lfndsa_xpoly_split_selfadj_fft__3:
	@ ====== i = 0 mod 2 ======

	@ r4:r5:r6 <- a[2*i + 0]
	@ r7:r8:r10 <- a[2*i + 1]
	@ update pointer &a[2*i]
	ldm	r3!, { r4, r5, r6, r7, r8, r10 }

	@ a0[i] <- (a[2*i + 0] + a[2*i + 1])/2 (updated)
	push	{ r12 }
	adds.w	r0, r4, r7
	adcs.w	r11, r5, r8
	adcs.w	r12, r6, r10
	asrs	r12, r12, #1
	rrxs	r11, r11
	rrxs	r0, r0
	stm	r1!, { r0, r11, r12 }
	pop	{ r12 }

	@ r7:r8:r10 <- t1 = a[2*i + 0] - a[2*i + 1]
	subs.w	r7, r4, r7
	sbcs.w	r8, r5, r8
	sbcs.w	r10, r6, r10

	@ r6:r11 <- IRNJ[qn + i]  (and update pointer)
	ldm.w	r12!, { r6, r11 }

	@ b1[i] <- t1*IRNJ[qn + i]  (and update pointer)
	RX_MUL_UFRAC  r4, r5, r7, r7, r8, r10, r6, r11, r0
	stm.w	r2!, { r4, r5, r7 }

	@ ====== i = 1 mod 2 ======

	@ r4:r5:r6 <- a[2*i + 0]
	@ r7:r8:r10 <- a[2*i + 1]
	@ update pointer &a[2*i]
	ldm	r3!, { r4, r5, r6, r7, r8, r10 }

	@ a0[i] <- (a[2*i + 0] + a[2*i + 1])/2 (updated)
	push	{ r12 }
	adds.w	r0, r4, r7
	adcs.w	r11, r5, r8
	adcs.w	r12, r6, r10
	asrs	r12, r12, #1
	rrxs	r11, r11
	rrxs	r0, r0
	stm	r1!, { r0, r11, r12 }
	pop	{ r12 }

	@ r7:r8:r10 <- t1 = a[2*i + 1] - a[2*i + 0]
	subs.w	r7, r7, r4
	sbcs.w	r8, r8, r5
	sbcs.w	r10, r10, r6

	@ r6:r11 <- IRNJ[qn + i]  (and update pointer)
	ldm.w	r12!, { r6, r11 }

	@ b1[i] <- t1*IRNJ[qn + i]  (and update pointer)
	RX_MUL_UFRAC  r4, r5, r7, r7, r8, r10, r6, r11, r0
	stm.w	r2!, { r4, r5, r7 }

	subs	r14, #16
	bne	Lfndsa_xpoly_split_selfadj_fft__3

	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }

	.align	2
IRNJ_addr:
	.word	fndsa_IRNJ
	.size	fndsa_xpoly_split_selfadj_fft, .-fndsa_xpoly_split_selfadj_fft

@ =======================================================================
@ void fndsa_xpoly_merge_fft(unsigned logn, rx *f, const rx *f0, const rx *f1)
@ =======================================================================

	.align	2
	.global	fndsa_xpoly_merge_fft
	.thumb
	.thumb_func
	.type	fndsa_xpoly_merge_fft, %function
fndsa_xpoly_merge_fft:
	cmp	r0, #1
	bne	Lfndsa_xpoly_merge_fft__1

	@ logn = 1
	@ f[0] <- f0[0]
	@ f[1] <- f1[0]
	ldm	r2, { r0, r2, r12 }
	stm	r1!, { r0, r2, r12 }
	ldm	r3, { r0, r2, r12 }
	stm	r1!, { r0, r2, r12 }
	bx	lr

	.align	2
Lfndsa_xpoly_merge_fft__1:
	cmp	r0, #2
	bne	Lfndsa_xpoly_merge_fft__2

	push	{ r1, r2, r4, r5, r6, r7, r8, r10, r11 }
	@ logn = 2
	@ hn = 2, qn = 1
	@ s_re = s_im = x_SIN[1] = 13043817825332782212 = s
	@ b_re = (f1[0] - f1[1])*s
	@ b_im = (f1[0] + f1[1])*s

	@ r0:r1:r2 <- f1[0]
	@ r3:r4:r5 <- f1[1]
	ldm.w	r3, { r0, r1, r2, r3, r4, r5 }

	@ r6:r7:r8 <- f1[0] + f1[1]
	adds.w	r6, r0, r3
	adcs.w	r7, r1, r4
	adcs.w	r8, r2, r5

	@ r0:r1:r2 <- f1[0] - f1[1]
	subs.w	r0, r0, r3
	sbcs.w	r1, r1, r4
	sbcs.w	r2, r2, r5

	@ r11:r12 <- s = x_SIN[1]
	adr.w	r11, x_SIN_1
	ldrd	r11, r12, [r11]

	@ r3:r4:r5 <- b_re = (f1[0] - f1[1])*s
	RX_MUL_UFRAC  r3, r4, r5, r0, r1, r2, r11, r12, r10

	@ r0:r1:r2 <- b_im = (f1[0] + f1[1])*s
	RX_MUL_UFRAC  r0, r1, r2, r6, r7, r8, r11, r12, r10

	pop	{ r11, r12 }            @ (r11, r12) <- (f, f0)

	@ f[0] <- f0[0] + b_re
	@ f[1] <- f0[0] - b_re
	ldm	r12!, { r6, r7, r8 }    @ r6:r7:r8 <- f0[0]
	adds	r10, r6, r3
	str	r10, [r11], #4
	adcs	r10, r7, r4
	str	r10, [r11], #4
	adcs	r10, r8, r5
	str	r10, [r11], #4
	subs	r10, r6, r3
	str	r10, [r11], #4
	sbcs	r10, r7, r4
	str	r10, [r11], #4
	sbcs	r10, r8, r5
	str	r10, [r11], #4

	@ f[2] <- f0[1] + b_im
	@ f[3] <- f0[1] - b_im
	ldm	r12!, { r6, r7, r8 }    @ r6:r7:r8 <- f0[1]
	adds	r10, r6, r0
	str	r10, [r11], #4
	adcs	r10, r7, r1
	str	r10, [r11], #4
	adcs	r10, r8, r2
	str	r10, [r11], #4
	subs	r10, r6, r0
	str	r10, [r11], #4
	sbcs	r10, r7, r1
	str	r10, [r11], #4
	sbcs	r10, r8, r2
	str	r10, [r11], #4

	pop	{ r4, r5, r6, r7, r8, r10, r11 }
	bx	lr

	.align	2
Lfndsa_xpoly_merge_fft__2:
	push	{ r4, r5, r6, r7, r8, r10, r11, lr }
	sub.w	sp, #24

	@ r0 <- qn*8
	mov	r12, #2
	lsl	r0, r12, r0
	push.w	{ r0, r1, r2, r3 }

	@ Stack layout:
	@    0       saved r0 = 8*qn
	@    4       saved f (updated)
	@    8       saved f0 (updated)
	@   12       saved f1 (updated)
	@   16..27   slot 1 (12 bytes)
	@   28..39   slot 2 (12 bytes)

	@ Loop runs for qn/2 iterations.
	lsr	r14, r0, #1
Lfndsa_xpoly_merge_fft__3:
	@ At loop entry:
	@   r14 = 8*(qn/2 - (i >> 1))

	ldr.w	r0, [sp]              @ r0 <- 8*qn

	@ r1 <- 8*(qn + (i >> 1))
	sub	r1, r0, r14
	add	r1, r1, r0, lsr #1

	@ Update r14 for next iteration.
	sub	r14, #8               @ r14 <- 8*(qn/2 - 1 - (i >> 1))

	@ r2 <- 8*(hn - 1 - (i >> 1))
	add	r2, r14, r0, lsr #1
	add.w	r2, r2, r0

	@ r8:r10 <- s_re = x_SIN[hn - 1 - (i >> 1)]
	@ r11:r12 <- s_im = x_SIN[qn + (i >> 1)]
	ldr.w	r10, x_SIN_addr
	add	r8, r10, r1
	ldrd	r11, r12, [r8]
	add	r8, r10, r2
	ldrd	r8, r10, [r8]

	@ ====== i = 0 mod 2 ======

	@ r4:r5:r6 <- f1[i + qn]
	ldr.w	r3, [sp, #12]         @ r3 <- &f1[i]
	add	r4, r3, r0
	add	r4, r4, r0, lsr #1    @ r3 <- &f1[i + qn]
	ldm.w	r4, { r4, r5, r6 }

	@ sp[16..27] <- t1 = f1[i + qn]*s_im
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r11, r12, r7
	str.w	r0, [sp, #16]
	str.w	r1, [sp, #20]
	str.w	r2, [sp, #24]

	@ sp[28..39] <- t3 = f1[i + qn]*s_re
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r8, r10, r7
	str.w	r0, [sp, #28]
	str.w	r1, [sp, #32]
	str.w	r2, [sp, #36]

	@ r4:r5:r6 <- f1[i] (and update f1)
	ldm	r3!, { r4, r5, r6 }
	str	r3, [sp, #12]

	@ r0:r1:r2 <- t0 = f1[i]*s_re
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r8, r10, r7

	@ sp[16..27] <- b_re = t0 - t1
	ldrd	r3, r7, [sp, #16]
	subs.w	r0, r3
	str.w	r0, [sp, #16]
	sbcs.w	r1, r7
	str.w	r1, [sp, #20]
	ldr.w	r3, [sp, #24]
	sbcs.w	r2, r3
	str.w	r2, [sp, #24]

	@ r0:r1:r2 <- t2 = f1[i]*s_im
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r11, r12, r7

	@ r0:r1:r2 <- b_im = t2 + t3
	ldr	r4, [sp, #28]
	ldr	r5, [sp, #32]
	ldr	r6, [sp, #36]
	adds	r0, r4
	adcs	r1, r5
	adcs	r2, r6

	@ r4:r5:r6 <- f0[i + qn]
	ldr	r4, [sp, #8]
	ldr	r7, [sp]
	add	r7, r7, r7, lsr #1    @ r7 <- qn*12
	add.w	r4, r4, r7
	ldm.w	r4, { r4, r5, r6 }

	@ f[(i << 1) + 0 + hn] <- f0[i + qn] + b_im
	ldr	r3, [sp, #4]
	add	r3, r3, r7, lsl #1    @ r3 <- &f[(i << 1) + 0 + hn]
	adds.w	r7, r0, r4
	str	r7, [r3], #4
	adcs.w	r7, r1, r5
	str	r7, [r3], #4
	adcs.w	r7, r2, r6
	str	r7, [r3], #4

	@ f[(i << 1) + 1 + hn] <- f0[i + qn] - b_im
	subs.w	r7, r4, r0
	str	r7, [r3], #4
	sbcs.w	r7, r5, r1
	str	r7, [r3], #4
	sbcs.w	r7, r6, r2
	str	r7, [r3], #4

	@ r0:r1:r2 <- b_re
	ldr.w	r0, [sp, #16]
	ldr.w	r1, [sp, #20]
	ldr.w	r2, [sp, #24]

	@ r4:r5:r6 <- f0[i] (and update f0)
	ldr.w	r3, [sp, #8]
	ldm.w	r3!, { r4, r5, r6 }
	str.w	r3, [sp, #8]

	@ f[(i << 1) + 0] <- f0[i] + b_re
	ldr.w	r3, [sp, #4]          @ r3 <- &f[(i << 1) + 0]
	adds.w	r7, r0, r4
	str	r7, [r3], #4
	adcs.w	r7, r1, r5
	str	r7, [r3], #4
	adcs.w	r7, r2, r6
	str	r7, [r3], #4

	@ f[(i << 1) + 1] <- f0[i] - b_re
	subs.w	r7, r4, r0
	str	r7, [r3], #4
	sbcs.w	r7, r5, r1
	str	r7, [r3], #4
	sbcs.w	r7, r6, r2
	str	r7, [r3], #4

	@ update f
	str.w	r3, [sp, #4]

	@ ====== i = 1 mod 2 ======

	ldr.w	r0, [sp]

	@ r4:r5:r6 <- f1[i + qn]
	ldr.w	r3, [sp, #12]         @ r3 <- &f1[i]
	add	r4, r3, r0
	add	r4, r4, r0, lsr #1    @ r3 <- &f1[i + qn]
	ldm.w	r4, { r4, r5, r6 }

	@ sp[28..39] <- t1 = f1[i + qn]*s_im
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r11, r12, r7
	str.w	r0, [sp, #28]
	str.w	r1, [sp, #32]
	str.w	r2, [sp, #36]

	@ sp[16..27] <- t3 = f1[i + qn]*s_re
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r8, r10, r7
	str.w	r0, [sp, #16]
	str.w	r1, [sp, #20]
	str.w	r2, [sp, #24]

	@ r4:r5:r6 <- f1[i] (and update f1)
	ldm	r3!, { r4, r5, r6 }
	str	r3, [sp, #12]

	@ r0:r1:r2 <- t2 = f1[i]*s_im
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r11, r12, r7

	@ sp[16..27] <- b_re = t2 + t3
	ldrd	r3, r7, [sp, #16]
	adds.w	r0, r3
	str.w	r0, [sp, #16]
	adcs.w	r1, r7
	str.w	r1, [sp, #20]
	ldr.w	r3, [sp, #24]
	adcs.w	r2, r3
	str.w	r2, [sp, #24]

	@ r0:r1:r2 <- t0 = f1[i]*s_re
	RX_MUL_UFRAC  r0, r1, r2, r4, r5, r6, r8, r10, r7

	@ r0:r1:r2 <- b_im = t0 - t1
	ldr	r4, [sp, #28]
	ldr	r5, [sp, #32]
	ldr	r6, [sp, #36]
	subs	r0, r4
	sbcs	r1, r5
	sbcs	r2, r6

	@ r4:r5:r6 <- f0[i + qn]
	ldr	r4, [sp, #8]
	ldr	r7, [sp]
	add	r7, r7, r7, lsr #1    @ r7 <- qn*12
	add.w	r4, r4, r7
	ldm.w	r4, { r4, r5, r6 }

	@ f[(i << 1) + 0 + hn] <- f0[i + qn] + b_im
	ldr	r3, [sp, #4]
	add	r3, r3, r7, lsl #1    @ r3 <- &f[(i << 1) + 0 + hn]
	adds.w	r7, r0, r4
	str	r7, [r3], #4
	adcs.w	r7, r1, r5
	str	r7, [r3], #4
	adcs.w	r7, r2, r6
	str	r7, [r3], #4

	@ f[(i << 1) + 1 + hn] <- f0[i + qn] - b_im
	subs.w	r7, r4, r0
	str	r7, [r3], #4
	sbcs.w	r7, r5, r1
	str	r7, [r3], #4
	sbcs.w	r7, r6, r2
	str	r7, [r3], #4

	@ r0:r1:r2 <- b_re
	ldr.w	r0, [sp, #16]
	ldr.w	r1, [sp, #20]
	ldr.w	r2, [sp, #24]

	@ r4:r5:r6 <- f0[i] (and update f0)
	ldr.w	r3, [sp, #8]
	ldm.w	r3!, { r4, r5, r6 }
	str.w	r3, [sp, #8]

	@ f[(i << 1) + 0] <- f0[i] - b_re
	ldr.w	r3, [sp, #4]          @ r3 <- &f[(i << 1) + 0]
	subs.w	r7, r4, r0
	str	r7, [r3], #4
	sbcs.w	r7, r5, r1
	str	r7, [r3], #4
	sbcs.w	r7, r6, r2
	str	r7, [r3], #4

	@ f[(i << 1) + 1] <- f0[i] + b_re
	adds.w	r7, r0, r4
	str	r7, [r3], #4
	adcs.w	r7, r1, r5
	str	r7, [r3], #4
	adcs.w	r7, r2, r6
	str	r7, [r3], #4

	@ update f
	str.w	r3, [sp, #4]

	@ Iterate until qn/2 - (i >> 1) reaches 0.
	cmp	r14, #0
	bne	Lfndsa_xpoly_merge_fft__3

	add	sp, #40
	pop	{ r4, r5, r6, r7, r8, r10, r11, pc }

	.align	2
x_SIN_addr:
	.word	fndsa_x_SIN
x_SIN_1:
	.word	4192101508, 3037000499
	.size	fndsa_xpoly_merge_fft,.-fndsa_xpoly_merge_fft
