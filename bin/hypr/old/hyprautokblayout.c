/*
 * hyprautokblayout.c — автопереключение раскладки клавиатуры для Hyprland
 */

#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define MAX_LINE 4096
#define LAYOUT_NAME_MAX 64
#define LAYOUT_FILE "/tmp/hypr-layout"
#define SWITCH_DELAY_MS 150

/* Приложения, которые требуют английской раскладки */
static const char *ENGLISH_APPS[] = {
    "nvim", "vim",   "btop", "htop",    "alacritty",
    "foot", "kitty", "mpv",  "pcmanfm", "app.hiddify.com",
    NULL};

/*
 * Layer-surface приложения по точному имени.
 * Launcher'ы (rofi, wofi, noctalia и любые другие с "launcher" в имени)
 * обрабатываются отдельно через is_launcher_layer().
 */
static const char *LAYER_APPS[] = {"rofi", "wofi", NULL};

/* ------------------------------------------------------------------ */
/*  Вспомогательные                                                   */
/* ------------------------------------------------------------------ */

/* Безопасное копирование: всегда NUL-терминирует, возвращает 0 если влезло */
static int safe_copy(char *dst, const char *src, size_t n) {
  if (n == 0)
    return -1;
  size_t i;
  for (i = 0; i + 1 < n && src[i]; i++)
    dst[i] = src[i];
  dst[i] = '\0';
  return (src[i] == '\0') ? 0 : -1; /* -1 = обрезано */
}

/* Монотонное время в миллисекундах */
static long long now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (long long)ts.tv_sec * 1000LL + ts.tv_nsec / 1000000;
}

/* ------------------------------------------------------------------ */
/*  Чтение/запись раскладки                                           */
/* ------------------------------------------------------------------ */

/*
 * Читаем файл при каждом вызове — не кешируем в памяти.
 *
 * Причина: пользователь может переключить раскладку вручную в любой момент.
 * Кеш не знает об этом → set_layout() считает что "уже en" → ничего не делает.
 * fopen/fclose на каждое событие — несущественная цена (события редкие).
 */
static void layout_get(char *buf, size_t n) {
  FILE *f = fopen(LAYOUT_FILE, "r");
  if (!f) {
    safe_copy(buf, "en", n);
    return;
  }
  if (!fgets(buf, (int)n, f))
    safe_copy(buf, "en", n);
  fclose(f);
  buf[strcspn(buf, "\n")] = '\0';
}

static void layout_write(const char *lang) {
  FILE *f = fopen(LAYOUT_FILE, "w");
  if (f) {
    fputs(lang, f);
    fclose(f);
  }
}

/* ------------------------------------------------------------------ */
/*  Переключение раскладки (без system())                              */
/* ------------------------------------------------------------------ */

/*
 * Вызываем ~/bin/hypr/hyprxkblayout напрямую через fork+execv.
 * Плюсы: нет shell, нет уязвимости к инъекциям, нет лишнего процесса.
 */
static void switch_layout(const char *lang) {
  const char *home = getenv("HOME");
  if (!home)
    return;

  char exe[512];
  if (snprintf(exe, sizeof(exe), "%s/bin/hypr/hyprxkblayout", home) >=
      (int)sizeof(exe)) {
    fprintf(stderr, "hyprautokblayout: HOME path too long\n");
    return;
  }

  pid_t pid = fork();
  if (pid < 0) {
    perror("fork");
    return;
  }

  if (pid == 0) {
    /* дочерний процесс */
    char *argv[] = {exe, (char *)lang, NULL};
    execv(exe, argv);
    perror("execv"); /* сюда попадём только при ошибке */
    _exit(127);
  }

  /* родитель: ждём завершения, чтобы раскладка применилась до следующего
   * события */
  int status;
  while (waitpid(pid, &status, 0) < 0 && errno == EINTR)
    ;
}

/* ------------------------------------------------------------------ */
/*  Логика переключения                                                */
/* ------------------------------------------------------------------ */

static char g_saved_layout[LAYOUT_NAME_MAX] = "";
static int g_saved_valid = 0;

static void set_layout(const char *lang) {
  char cur[LAYOUT_NAME_MAX];
  layout_get(cur, sizeof(cur));
  if (strcmp(cur, lang) == 0)
    return;
  switch_layout(lang);
  layout_write(lang);
}

static void save_and_set_en(void) {
  if (!g_saved_valid) {
    /* Читаем актуальное состояние — ловим ручные переключения */
    layout_get(g_saved_layout, sizeof(g_saved_layout));
    g_saved_valid = 1;
  }
  set_layout("en");
}

static void restore_layout(void) {
  if (!g_saved_valid)
    return;
  char saved[LAYOUT_NAME_MAX];
  safe_copy(saved, g_saved_layout, sizeof(saved));
  g_saved_valid = 0;
  g_saved_layout[0] = '\0';
  set_layout(saved);
}

/* ------------------------------------------------------------------ */
/*  Парсинг событий Hyprland                                          */
/* ------------------------------------------------------------------ */

static void parse_activewindow(const char *line, char *class_out,
                               size_t class_n, char *title_out,
                               size_t title_n) {
  class_out[0] = title_out[0] = '\0';

  const char *p = line + sizeof("activewindow>>") - 1;

  size_t i = 0;
  while (*p && *p != ',' && i < class_n - 1)
    class_out[i++] = (char)tolower((unsigned char)*p++);
  class_out[i] = '\0';

  if (*p == ',')
    p++;

  i = 0;
  while (*p && i < title_n - 1)
    title_out[i++] = *p++;
  title_out[i] = '\0';
}

/* "openlayer>>NAME" или "closelayer>>NAME" → name_out */
static int parse_layer_event(const char *line, const char *prefix,
                             char *name_out, size_t n) {
  size_t plen = strlen(prefix);
  if (strncmp(line, prefix, plen) != 0)
    return 0;
  safe_copy(name_out, line + plen, n);
  return 1;
}

/* ------------------------------------------------------------------ */
/*  Классификация приложений                                           */
/* ------------------------------------------------------------------ */

static int is_english_class(const char *class) {
  for (int i = 0; ENGLISH_APPS[i]; i++)
    if (strcmp(class, ENGLISH_APPS[i]) == 0)
      return 1;
  return 0;
}

static int is_named_layer_app(const char *name) {
  for (int i = 0; LAYER_APPS[i]; i++)
    if (strcmp(name, LAYER_APPS[i]) == 0)
      return 1;
  return 0;
}

/*
 * Любой слой с подстрокой "launcher" в имени.
 * Покрывает noctalia-launcher, rofi-launcher, wofi-launcher и т.д.
 */
static int is_launcher_layer(const char *name) {
  return strstr(name, "launcher") != NULL;
}

static int is_english_layer(const char *name) {
  return is_named_layer_app(name) || is_launcher_layer(name);
}

/* ------------------------------------------------------------------ */
/*  Обработчики событий                                                */
/* ------------------------------------------------------------------ */

static long long last_switch_ms = 0;

static int g_layer_active = 0;

static void handle_window(const char *line) {
  long long now = now_ms();
  if (now - last_switch_ms < SWITCH_DELAY_MS)
    return;
  last_switch_ms = now;

  char cls[256], title[512];
  parse_activewindow(line, cls, sizeof(cls), title, sizeof(title));

  if (is_english_class(cls)) {
    save_and_set_en();
  } else {
    /* cls пустой или не-английское приложение */
    if (g_saved_valid)
      restore_layout();
  }
}

static void handle_layer_open(const char *name) {
  if (!is_english_layer(name))
    return;

  long long now = now_ms();
  last_switch_ms = now;

  g_layer_active = 1;
  save_and_set_en();
}

static void handle_layer_close(const char *name) {
  if (!is_english_layer(name))
    return;

  long long now = now_ms();
  last_switch_ms = now;

  g_layer_active = 0;
  if (g_saved_valid)
    restore_layout();
}

/* ------------------------------------------------------------------ */
/*  Подключение к сокету Hyprland                                     */
/* ------------------------------------------------------------------ */

static int connect_socket(void) {
  const char *sig = getenv("HYPRLAND_INSTANCE_SIGNATURE");
  const char *xdg = getenv("XDG_RUNTIME_DIR");
  if (!sig || !xdg) {
    fprintf(
        stderr,
        "Missing env vars: HYPRLAND_INSTANCE_SIGNATURE / XDG_RUNTIME_DIR\n");
    return -1;
  }

  char path[256];
  if (snprintf(path, sizeof(path), "%s/hypr/%s/.socket2.sock", xdg, sig) >=
      (int)sizeof(path)) {
    fprintf(stderr, "Socket path too long\n");
    return -1;
  }

  int fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd < 0) {
    perror("socket");
    return -1;
  }

  struct sockaddr_un addr = {.sun_family = AF_UNIX};
  safe_copy(addr.sun_path, path, sizeof(addr.sun_path));

  if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    perror("connect");
    close(fd);
    return -1;
  }
  return fd;
}

/* ------------------------------------------------------------------ */
/*  main                                                              */
/* ------------------------------------------------------------------ */

int main(void) {
  int fd = connect_socket();
  if (fd < 0)
    return 1;

  FILE *sock = fdopen(fd, "r");
  if (!sock) {
    perror("fdopen");
    close(fd);
    return 1;
  }

  char line[MAX_LINE];
  char layer_name[128];

  while (fgets(line, sizeof(line), sock)) {
    line[strcspn(line, "\n")] = '\0';

    if (strncmp(line, "activewindow>>", 14) == 0) {
      handle_window(line);
      continue;
    }

    if (parse_layer_event(line, "openlayer>>", layer_name,
                          sizeof(layer_name))) {
      handle_layer_open(layer_name);
      continue;
    }

    if (parse_layer_event(line, "closelayer>>", layer_name,
                          sizeof(layer_name))) {
      handle_layer_close(layer_name);
      continue;
    }
  }

  fclose(sock);
  return 0;
}
