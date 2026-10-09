/*
 * Utility functions for message recovery mode.
 */

#include "inner.h"

static void
inject_u16s(shake_context *sc, const uint16_t *a, size_t num)
{
	while (num -- > 0) {
		uint8_t tmp[2];
		tmp[0] = (uint8_t)*a;
		tmp[1] = (uint8_t)(*a >> 8);
		shake_inject(sc, tmp, 2);
		a ++;
	}
}

static void
extract_u16s(shake_context *sc, uint16_t *d, size_t num)
{
	while (num > 0) {
		uint8_t tmp[2];
		shake_extract(sc, tmp, sizeof tmp);
		unsigned x = (unsigned)tmp[0] | ((unsigned)tmp[1] << 8);
		if (x < 61445) {
			*d ++ = (uint16_t)(x % 12289);
			num --;
		}
	}
}

static void
add_mod_q(uint16_t *d, const uint16_t *a, size_t num)
{
	for (size_t i = 0; i < num; i ++) {
		uint32_t x = (uint32_t)d[i] + (uint32_t)a[i] - 12289;
		x += (x >> 16) & 12289;
		d[i] = (uint16_t)x;
	}
}

/* see inner.h */
void
mrm_make_nonce(unsigned logn, shake_context *sc, uint16_t *nonce)
{
	extract_u16s(sc, nonce, MRM_GAMMA(logn));
}

/* see inner.h */
void
mrm_H1(unsigned logn, const uint16_t *nonce,
	const uint8_t *mu, const uint8_t *embedded, size_t embedded_len,
	uint16_t *c)
{
	shake_context sc;
	shake_init(&sc, 256);
	shake_inject(&sc, "H1", 2);
	inject_u16s(&sc, nonce, MRM_GAMMA(logn));
	shake_inject(&sc, mu, 64);
	shake_inject(&sc, embedded, embedded_len);
	shake_flip(&sc);
	extract_u16s(&sc, c, MRM_LAMBDA(logn));
}

/* see inner.h */
void
mrm_H2(unsigned logn, const uint16_t *c1, uint16_t *d)
{
	size_t n = (size_t)1 << logn;
	size_t lambda = MRM_LAMBDA(logn);

	/* Compute H2(c1) into the remaining slots. */
	shake_context sc;
	shake_init(&sc, 256);
	shake_inject(&sc, "H2", 2);
	inject_u16s(&sc, c1, lambda);
	shake_flip(&sc);
	extract_u16s(&sc, d + lambda, n - lambda);
}

/* see inner.h */
void
mrm_hash_to_point(unsigned logn, const uint16_t *nonce,
	const uint8_t *mu, const uint8_t *embedded, size_t embedded_len,
	uint16_t *c)
{
	size_t gamma = MRM_GAMMA(logn);
	size_t lambda = MRM_LAMBDA(logn);

	/* c1 <- H1(nonce, mu, embedded) */
	mrm_H1(logn, nonce, mu, embedded, embedded_len, c);

	/* Compute H2(c1) into the remaining slots. */
	mrm_H2(logn, c, c);

	/* c2 <- H2(c1) + (nonce || embedded)
	   The embedded part is encoded by 163-bit chunks (yielding 12
	   elements) then 27-bit chunks (yielding 2 elements). */
	size_t j = lambda;
	add_mod_q(c + j, nonce, gamma);
	j += gamma;
	bits_reader br = { embedded, embedded_len, 0, 0 };
	size_t num_163 = MRM_NUM163(logn);
	size_t num_27 = MRM_NUM27(logn);
	while (num_163 -- > 0) {
		uint16_t td[12];
		bits_163_to_q12(&br, td);
		add_mod_q(c + j, td, 12);
		j += 12;
	}
	while (num_27 -- > 0) {
		uint16_t td[2];
		bits_27_to_q2(&br, td);
		add_mod_q(c + j, td, 2);
		j += 2;
	}
}
