#include "libs/system.h"

dword m;
char c[20];

void main() {
  printf("Allocating 200 bytes... ");
  m = malloc(200);
  itoa(msize(m), c, 10);
  printf(c);
  printf(" bytes allocated!\n");
  printf("The OS should automatically clean up allocated memory even if the process doesn't free it.\n");
}

byte endofcode;
