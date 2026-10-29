/*
 * desi_lm — the only API the app sees of llama.cpp (native/desi_lm/).
 * Scores text with a small GGUF model; it never generates. Built into
 * app/Libraries/libllama-bundle.a by scripts/setup_llama.sh, with llama.cpp
 * and its ggml hidden inside (only desi_lm_* is exported).
 */
#ifndef DESI_LM_H
#define DESI_LM_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct desi_lm desi_lm;

/* Loads a model. n_gpu_layers: 99 = all on Metal, 0 = CPU. NULL on failure. */
desi_lm * desi_lm_load(const char * path, int n_ctx, int n_gpu_layers);

void desi_lm_free(desi_lm * lm);

/*
 * Sum of natural-log token probabilities of `text` following `prefix`.
 * Writes the sum to *out_logprob and the number of scored tokens to
 * *out_tokens. Returns 0 on success, negative on failure (-1 bad args,
 * -2 nothing to score, -3 longer than the context, -4 decode failed).
 * Not thread-safe per handle: callers serialize.
 */
int desi_lm_score(desi_lm * lm, const char * prefix, const char * text,
                  double * out_logprob, int * out_tokens);

/*
 * Per-token version of desi_lm_score, for finding the words that don't fit
 * (Review before paste). For each token of `text`: its natural-log
 * probability, and the byte offset in `text` where it ends. Writes at most
 * `capacity` entries and their number to *out_count. Same return codes.
 */
int desi_lm_token_scores(desi_lm * lm, const char * prefix, const char * text,
                         double * out_logprobs, int * out_ends, int capacity, int * out_count);

#ifdef __cplusplus
}
#endif

#endif
