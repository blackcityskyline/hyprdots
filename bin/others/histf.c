/*
 * histf.c — fish history frequency analyzer
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* ── constants ─────────────────────────────────────────────────────── */

#define MAX_CMDS        65536
#define MAX_CMD_LEN     1024
#define HT_SIZE         131072   /* power of two for hash table */
#define HT_MASK         (HT_SIZE - 1)
#define TOP_N_DEFAULT   12
#define MIN_COUNT       2        /* minimum occurrences to show */

/* ── colors ────────────────────────────────────────────────────────── */

#define COL_RED     "\033[31m"
#define COL_YEL     "\033[33m"
#define COL_GRN     "\033[32m"
#define COL_CYN     "\033[36m"
#define COL_DIM     "\033[2m"
#define COL_BOLD    "\033[1m"
#define COL_RST     "\033[0m"

/* ── hash table (open addressing, string keys) ─────────────────────── */

typedef struct {
    char  *key;
    int    count;
} HEntry;

typedef struct {
    HEntry *entries;
    int     size;     /* always HT_SIZE */
} HTable;

static HTable *ht_new(void) {
    HTable *t = calloc(1, sizeof(HTable));
    t->entries = calloc(HT_SIZE, sizeof(HEntry));
    t->size = HT_SIZE;
    return t;
}

static unsigned int ht_hash(const char *s) {
    unsigned int h = 2166136261u;
    while (*s) { h ^= (unsigned char)*s++; h *= 16777619u; }
    return h;
}

/* Returns pointer to counter (creates entry if missing) */
static int *ht_get(HTable *t, const char *key) {
    unsigned int idx = ht_hash(key) & HT_MASK;
    while (t->entries[idx].key) {
        if (strcmp(t->entries[idx].key, key) == 0)
            return &t->entries[idx].count;
        idx = (idx + 1) & HT_MASK;
    }
    t->entries[idx].key   = strdup(key);
    t->entries[idx].count = 0;
    return &t->entries[idx].count;
}

static void ht_inc(HTable *t, const char *key) {
    (*ht_get(t, key))++;
}

/* Collects non‑zero entries into array, sorts descending by count */
typedef struct { const char *key; int count; } KV;

static int kv_cmp(const void *a, const void *b) {
    return ((KV *)b)->count - ((KV *)a)->count;
}

static KV *ht_sorted(HTable *t, int *out_len) {
    int n = 0;
    for (int i = 0; i < HT_SIZE; i++)
        if (t->entries[i].key && t->entries[i].count >= MIN_COUNT) n++;

    KV *arr = malloc(n * sizeof(KV));
    int j = 0;
    for (int i = 0; i < HT_SIZE; i++)
        if (t->entries[i].key && t->entries[i].count >= MIN_COUNT)
            arr[j++] = (KV){ t->entries[i].key, t->entries[i].count };

    qsort(arr, n, sizeof(KV), kv_cmp);
    *out_len = n;
    return arr;
}

/* ── fish_history parsing ──────────────────────────────────────────── */

static int parse_history(const char *path, char cmds[][MAX_CMD_LEN], int max) {
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); return 0; }

    int  n   = 0;
    char line[MAX_CMD_LEN * 2];

    while (n < max && fgets(line, sizeof(line), f)) {
        if (strncmp(line, "- cmd: ", 7) != 0) continue;

        char *src = line + 7;
        src[strcspn(src, "\n")] = '\0';

        /* fish encodes multiline commands as literal \n → replace with space */
        char *dst = cmds[n];
        int   i   = 0;
        while (*src && i < MAX_CMD_LEN - 1) {
            if (src[0] == '\\' && src[1] == 'n') {
                dst[i++] = ' '; dst[i++] = ';'; dst[i++] = ' ';
                src += 2;
            } else {
                dst[i++] = *src++;
            }
        }
        dst[i] = '\0';
        if (i > 0) n++;
    }

    fclose(f);
    return n;
}

/* ── normalisation ─────────────────────────────────────────────────── */

/* First word (binary / utility) */
static void first_word(const char *cmd, char *out, size_t n) {
    const char *p = cmd;
    while (*p == ' ') p++;
    size_t i = 0;
    while (*p && *p != ' ' && i < n - 1) out[i++] = *p++;
    out[i] = '\0';
}

/* First k words (for grouping) */
static void first_k_words(const char *cmd, int k, char *out, size_t n) {
    const char *p = cmd;
    while (*p == ' ') p++;
    size_t i   = 0;
    int    cnt = 0;
    while (*p && i < n - 1) {
        if (*p == ' ') {
            if (++cnt >= k) break;
            while (*p == ' ') p++;
            if (!*p || cnt >= k) break;
            out[i++] = ' ';
        } else {
            out[i++] = *p++;
        }
    }
    out[i] = '\0';
}

/* ── levenshtein distance ──────────────────────────────────────────── */

static void str_lower(const char *s, char *out, size_t n) {
    size_t i = 0;
    while (*s && i < n - 1) out[i++] = (char)tolower((unsigned char)*s++);
    out[i] = '\0';
}

/* Heuristic: skip env vars, paths, files */
static int is_env_or_junk(const char *word) {
    if (strchr(word, '=')) return 1;   /* environment variable */
    if (word[0] == '_') return 1;      /* internal / env var */
    if (strchr(word, '/')) return 1;   /* path */
    if (strchr(word, '.')) return 1;   /* file or extension */
    return 0;
}

static int levenshtein(const char *a, const char *b) {
    int la = (int)strlen(a), lb = (int)strlen(b);
    if (la > 32 || lb > 32) return 99;   /* skip long strings */

    int d[33][33];
    for (int i = 0; i <= la; i++) d[i][0] = i;
    for (int j = 0; j <= lb; j++) d[0][j] = j;
    for (int i = 1; i <= la; i++)
        for (int j = 1; j <= lb; j++) {
            int cost = (a[i-1] != b[j-1]);
            int del  = d[i-1][j] + 1;
            int ins  = d[i][j-1] + 1;
            int sub  = d[i-1][j-1] + cost;
            d[i][j]  = del < ins ? (del < sub ? del : sub)
                                 : (ins < sub ? ins : sub);
        }
    return d[la][lb];
}

#define KNOWN_THRESHOLD 10
#define TYPO_MIN_LEN    4
#define TYPO_MAX_DIST   1

/* ── output helpers ────────────────────────────────────────────────── */

static void print_header(const char *title) {
    printf("\n" COL_BOLD COL_CYN "── %s " COL_RST COL_DIM
           "─────────────────────────────────────────" COL_RST "\n", title);
}

static void bar(int count, int max_count) {
    int w = 20;
    int filled = (max_count > 0) ? (count * w / max_count) : 0;
    printf(COL_GRN);
    for (int i = 0; i < filled;  i++) printf("█");
    printf(COL_DIM);
    for (int i = filled; i < w; i++) printf("░");
    printf(COL_RST);
}

/* ── main ──────────────────────────────────────────────────────────── */

int main(int argc, char *argv[]) {
    int top_n = (argc > 1) ? atoi(argv[1]) : TOP_N_DEFAULT;
    if (top_n <= 0) top_n = TOP_N_DEFAULT;

    const char *home = getenv("HOME");
    if (!home) { fprintf(stderr, "HOME not set\n"); return 1; }

    char hist_path[512];
    snprintf(hist_path, sizeof(hist_path),
             "%s/.local/share/fish/fish_history", home);

    char (*cmds)[MAX_CMD_LEN] = malloc(MAX_CMDS * MAX_CMD_LEN);
    if (!cmds) { perror("malloc"); return 1; }

    int total = parse_history(hist_path, cmds, MAX_CMDS);

    printf(COL_BOLD "\nhyprfreq" COL_RST COL_DIM
           " — %d commands in history\n" COL_RST, total);

    /* ── 1. Top full commands (alias candidates) ───────────────────── */
    HTable *full_ht = ht_new();
    for (int i = 0; i < total; i++) {
        char fw[64];
        first_word(cmds[i], fw, sizeof(fw));
        if (strchr(cmds[i], ' ') || strlen(fw) > 2)
            ht_inc(full_ht, cmds[i]);
    }

    int    flen;
    KV    *fsorted = ht_sorted(full_ht, &flen);
    int    fmax    = flen > 0 ? fsorted[0].count : 1;

    print_header("top commands → aliases");
    int shown = 0;
    for (int i = 0; i < flen && shown < top_n; i++) {
        if (!strchr(fsorted[i].key, ' ')) continue;
        printf("  " COL_BOLD "%3d×" COL_RST "  ", fsorted[i].count);
        bar(fsorted[i].count, fmax);
        printf("  " COL_YEL "%s" COL_RST "\n", fsorted[i].key);
        shown++;
    }

    /* ── 2. Top utilities (first word) ─────────────────────────────── */
    HTable *bin_ht = ht_new();
    for (int i = 0; i < total; i++) {
        char fw[64];
        first_word(cmds[i], fw, sizeof(fw));
        if (fw[0]) ht_inc(bin_ht, fw);
    }

    int  blen;
    KV  *bsorted = ht_sorted(bin_ht, &blen);
    int  bmax    = blen > 0 ? bsorted[0].count : 1;

    print_header("most frequent commands");
    for (int i = 0; i < blen && i < top_n; i++) {
        printf("  " COL_BOLD "%3d×" COL_RST "  ", bsorted[i].count);
        bar(bsorted[i].count, bmax);
        printf("  " COL_CYN "%s" COL_RST "\n", bsorted[i].key);
    }

    /* ── 3. Command pairs (bigrams) ────────────────────────────────── */
    HTable *chain_ht = ht_new();
    for (int i = 1; i < total; i++) {
        char a[64], b[64];
        first_k_words(cmds[i-1], 3, a, sizeof(a));
        first_k_words(cmds[i],   3, b, sizeof(b));
        if (!a[0] || !b[0] || strcmp(a, b) == 0) continue;

        char pair[256];
        snprintf(pair, sizeof(pair), "%s  →  %s", a, b);
        ht_inc(chain_ht, pair);
    }

    int  clen;
    KV  *csorted = ht_sorted(chain_ht, &clen);
    int  cmax    = clen > 0 ? csorted[0].count : 1;

    print_header("frequent chains");
    for (int i = 0; i < clen && i < top_n; i++) {
        printf("  " COL_BOLD "%3d×" COL_RST "  ", csorted[i].count);
        bar(csorted[i].count, cmax);
        printf("  " COL_GRN "%s" COL_RST "\n", csorted[i].key);
    }

    /* ── 4. Typos ──────────────────────────────────────────────────── */
    /* Build list of "known" commands (appear >= KNOWN_THRESHOLD times) */
    int   known_n = 0;
    for (int i = 0; i < blen; i++)
        if (bsorted[i].count >= KNOWN_THRESHOLD) known_n++;

    const char **known_arr = malloc((known_n + 1) * sizeof(char *));
    int ki = 0;
    for (int i = 0; i < blen; i++)
        if (bsorted[i].count >= KNOWN_THRESHOLD)
            known_arr[ki++] = bsorted[i].key;
    known_arr[ki] = NULL;

    HTable *typo_ht = ht_new();
    for (int i = 0; i < blen; i++) {
        const char *word = bsorted[i].key;

        if (is_env_or_junk(word)) continue;
        if (strlen(word) < TYPO_MIN_LEN) continue;
        if (bsorted[i].count >= KNOWN_THRESHOLD) continue;

        char word_low[64];
        str_lower(word, word_low, sizeof(word_low));

        for (int k = 0; known_arr[k]; k++) {
            if (strlen(known_arr[k]) < TYPO_MIN_LEN) continue;

            char known_low[64];
            str_lower(known_arr[k], known_low, sizeof(known_low));

            /* Case‑only difference → not a typo */
            if (strcmp(word_low, known_low) == 0) goto next_word;

            if (levenshtein(word_low, known_low) <= TYPO_MAX_DIST) {
                char entry[128];
                snprintf(entry, sizeof(entry), "%-14s→  %s", word, known_arr[k]);
                *ht_get(typo_ht, entry) = bsorted[i].count;
                goto next_word;
            }
        }
        next_word:;
    }
    free(known_arr);

    int  tlen;
    KV  *tsorted = ht_sorted(typo_ht, &tlen);

    if (tlen > 0) {
        print_header("possible typos");
        for (int i = 0; i < tlen && i < top_n; i++) {
            printf("  " COL_BOLD "%3d×" COL_RST "  "
                   COL_RED "%s" COL_RST "\n",
                   tsorted[i].count,
                   tsorted[i].key);
        }
    }

    printf("\n");

    free(fsorted);
    free(bsorted);
    free(csorted);
    free(tsorted);
    free(cmds);
    return 0;
}
