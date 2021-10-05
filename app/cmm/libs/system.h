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

struct DateTime_t {
  byte year;
  byte month;
  byte day;
  byte second;
  byte minute;
  byte hour;
};

inline fastcall void exit() {
  EAX = 4;
  ECX = DSDWORD[ESP + 4];
  $int 0x61;
  while (1) {
    $hlt;
  }
}

// ESI: char*
inline fastcall void printf(dword ESI) {
  EAX = 1;
  $int 0x71;
}

inline fastcall void yield() {
  $int 0x20;
}

// EDI: DateTime_t*
void GetDateTime(dword EDI) {
  EAX = 0x202;
  $int 0x61;
  EDI.DateTime_t.second = AL;
  EDI.DateTime_t.minute = AH;
  EDI.DateTime_t.hour = dword EAX >> 16;
  EDI.DateTime_t.day = CL;
  EDI.DateTime_t.month = CH;
  EDI.DateTime_t.year = dword ECX >> 16;
  if (EDI.DateTime_t.hour > 80)
    EDI.DateTime_t.hour = EDI.DateTime_t.hour - 80 + 12;
}

void itoa(int num, char* c, byte base) {
  char buf[14];
  byte* str;
  dword digit;
  byte isNeg = 0;

  for (digit = 0; digit < 14; digit++) {
    buf[digit] = 0;
  }
  str = #buf[12];
  *str = 0;
  if (num < 0) {
    isNeg = 1;
    num = -num;
  }
  digit = num;
  if (digit == 0) {
    *str = '0';
  } else {
    do {
      str -= 1;
      EAX = digit % 10 + 0x30;
      *str = AL;
      digit /= 10;
    } while (digit != 0);
  }
  str = #buf[0];
  while (*str == 0) {
    str++;
  }
  if (isNeg == 1) {
    *c = '-';
    c++;
  }
  while (*str != 0) {
    *c = *str;
    str++;
    c++;
  }
  *c = 0;
}

dword seed;

dword rnd() {
  seed = 214013 * seed + 2531011;
  EAX = seed >> 16;
  return (EAX & 0x7FFF);
}
