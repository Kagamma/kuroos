#pragma option b32
#pragma option X
#pragma option LST
#pragma option J0

#imagebase 0x04000000

char  name[4]     = {'K', '3', '2', 0};
dword version     = 1;
dword size        = #endofcode - 0x04000000;
dword startupCode = 0x04000000;
dword startupHeap = 0x05000000;
dword stackSize   = 0x400;
dword codePoint   = #main - 0x04000000;
dword icon        = 0;

inline fastcall void exit() {
  EAX = 4;
  ECX = DSDWORD[ESP + 4];
  $int 0x61;
  while (1) {
    $hlt;
  }
}

inline fastcall void printf(dword ESI) {
  EAX = 1;
  $int 0x71;
}

inline fastcall void yield() {
  $int 0x20;
}
