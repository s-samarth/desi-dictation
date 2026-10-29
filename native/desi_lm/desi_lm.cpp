// desi_lm: score text with llama.cpp (see app/Sources/CLlamaScore/include/desi_lm.h).
// Kept tiny on purpose: tokenize, one decode, log-softmax. No sampling.
#include "desi_lm.h"

#include "llama.h"

#include <algorithm>
#include <cmath>
#include <mutex>
#include <string>
#include <vector>

struct desi_lm {
    llama_model *       model = nullptr;
    llama_context *     ctx   = nullptr;
    const llama_vocab * vocab = nullptr;
    int                 n_ctx = 0;
};

static void quiet_log(ggml_log_level, const char *, void *) {}

static std::vector<llama_token> tokenize(const llama_vocab * vocab, const std::string & s) {
    const int32_t needed = -llama_tokenize(vocab, s.c_str(), (int32_t) s.size(), nullptr, 0, true, false);
    std::vector<llama_token> out(needed > 0 ? needed : 0);
    if (needed <= 0) return out;
    const int32_t got = llama_tokenize(vocab, s.c_str(), (int32_t) s.size(), out.data(), needed, true, false);
    out.resize(got > 0 ? got : 0);
    return out;
}

extern "C" desi_lm * desi_lm_load(const char * path, int n_ctx, int n_gpu_layers) {
    static std::once_flag once;
    std::call_once(once, [] {
        llama_log_set(quiet_log, nullptr);
        llama_backend_init();
    });
    if (!path || n_ctx <= 0) return nullptr;

    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = n_gpu_layers;
    llama_model * model = llama_model_load_from_file(path, mparams);
    if (!model) return nullptr;

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx    = (uint32_t) n_ctx;
    cparams.n_batch  = (uint32_t) n_ctx;
    cparams.n_ubatch = (uint32_t) n_ctx;
    cparams.no_perf  = true;
    llama_context * ctx = llama_init_from_model(model, cparams);
    if (!ctx) {
        llama_model_free(model);
        return nullptr;
    }
    auto * lm  = new desi_lm;
    lm->model  = model;
    lm->ctx    = ctx;
    lm->vocab  = llama_model_get_vocab(model);
    lm->n_ctx  = n_ctx;
    return lm;
}

extern "C" void desi_lm_free(desi_lm * lm) {
    if (!lm) return;
    llama_free(lm->ctx);
    llama_model_free(lm->model);
    delete lm;
}

extern "C" int desi_lm_score(desi_lm * lm, const char * prefix, const char * text,
                             double * out_logprob, int * out_tokens) {
    if (!lm || !prefix || !text || !out_logprob || !out_tokens) return -1;
    const std::string               pre = prefix;
    const std::vector<llama_token>  head = tokenize(lm->vocab, pre);
    const std::vector<llama_token>  all  = tokenize(lm->vocab, pre + text);

    // Text tokens start where the joint tokenization stops matching the
    // prefix alone (BPE may merge across the seam). Token 0 has no context.
    size_t start = 0;
    while (start < head.size() && start < all.size() && head[start] == all[start]) start++;
    if (start == 0) start = 1;
    if (all.size() <= start) return -2;
    if ((int) all.size() > lm->n_ctx) return -3;

    llama_memory_clear(llama_get_memory(lm->ctx), true);
    llama_batch batch = llama_batch_init((int32_t) all.size(), 0, 1);
    for (size_t i = 0; i < all.size(); i++) {
        batch.token[i]     = all[i];
        batch.pos[i]       = (llama_pos) i;
        batch.n_seq_id[i]  = 1;
        batch.seq_id[i][0] = 0;
        // Logits at i predict token i + 1: needed for every scored token.
        batch.logits[i]    = (i + 1 >= start && i + 1 < all.size()) ? 1 : 0;
    }
    batch.n_tokens = (int32_t) all.size();
    if (llama_decode(lm->ctx, batch) != 0) {
        llama_batch_free(batch);
        return -4;
    }

    const int n_vocab = llama_vocab_n_tokens(lm->vocab);
    double    sum     = 0.0;
    for (size_t i = start; i < all.size(); i++) {
        const float * logits = llama_get_logits_ith(lm->ctx, (int32_t) (i - 1));
        float         peak   = logits[0];
        for (int v = 1; v < n_vocab; v++) peak = std::max(peak, logits[v]);
        double total = 0.0;
        for (int v = 0; v < n_vocab; v++) total += std::exp((double) (logits[v] - peak));
        sum += (double) (logits[all[i]] - peak) - std::log(total);
    }
    llama_batch_free(batch);
    *out_logprob = sum;
    *out_tokens  = (int) (all.size() - start);
    return 0;
}
