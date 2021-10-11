#include "libs/system.h"

void main() {
  printf("Trying to access something you should not be able to...\n");
  $hlt;
}

byte __endofcode;
