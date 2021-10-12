#include "libs/system.h"

void main(dword argv, dword* args) {
  dword i;
  for (i = 1; i < argv; i++) {
    EDX = i * 4;
    EDI = args + EDX;
    printf(DSDWORD[EDI]);
    if (i < argv - 1) {
      printf(" ");
    }
  }
  printf("\n");
}

byte __endofcode;
