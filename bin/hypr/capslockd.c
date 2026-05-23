// capslock-osd.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>

static char* find_led() {
    DIR *d = opendir("/sys/class/leds");
    if (!d) return NULL;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (strstr(e->d_name, "capslock")) {
            char *path = malloc(256);
            snprintf(path, 256, "/sys/class/leds/%s/brightness", e->d_name);
            closedir(d);
            return path;
        }
    }
    closedir(d);
    return NULL;
}

static int read_led(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    int val = 0;
    fscanf(f, "%d", &val);
    fclose(f);
    return val;
}

int main() {
    char *led = find_led();
    if (!led) { fprintf(stderr, "capslock led not found\n"); return 1; }

    int prev = read_led(led);

    while (1) {
        usleep(100000); // 200ms
        int cur = read_led(led);
        if (cur != prev) {
            system("swayosd-client --caps-lock");
            prev = cur;
        }
    }
}
