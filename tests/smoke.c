#include <stdio.h>
#include <stdlib.h>

static volatile size_t allocation_count = 32;
static volatile size_t allocation_size = 44;
static volatile unsigned int divisor = 7;

int main(int argc, char **argv)
{
    unsigned char *slots = calloc(allocation_count, allocation_size);

    if (slots == NULL) {
        fputs("musl-cross smoke test: allocation failed\n", stderr);
        return 1;
    }

    slots[0] = (unsigned int)(argc + (argv[0] != NULL)) / divisor;
    free(slots);
    puts("musl-cross smoke test");
    return 0;
}
