#pragma option b32
#pragma option X
#pragma option LST
#pragma option J0

#imagebase 0x08048000

char  name[4]     = {'K', '3', '2', 0};
dword version     = 1;
dword size        = #__endofcode - 0x08048000;
dword stackSize   = 0x400;
dword entryPoint  = #__entry;
dword icon        = 0;

struct DateTime_t {
  byte year;
  byte month;
  byte day;
  byte second;
  byte minute;
  byte hour;
};

char BASENUMBERS[16] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };
dword __pid;
dword __argPtr;
dword __argv;
dword* __args[256];

inline fastcall __entry() {
  __pid = DSDWORD[ESP + 8];
  __argPtr = DSDWORD[ESP + 12];
  parseArgs();
  main(__argv, #__args);
  exit();
}

inline fastcall void exit() {
  EAX = 3;
  ECX = __pid;
  $int 0x61;
  while (1) {
    $int 0x20;
  }
}

inline fastcall void yield() {
  $int 0x20;
}

void parseArgs() {
  dword i;
  dword len;
  dword count = 0;
  dword isFirst = 1;
  dword isQuote = 0;
  dword isSlash = 0;
  char* arg;
  char c;
  char tmp[256];
  if (__argPtr == 0) {
    return;
  }
  memset(#tmp, 0, 256);
  __argv = 0;
  len = strlen(__argPtr);
  for (i = 0; i < len; i++) {
    EDI = __argPtr + i;
    c = DSBYTE[EDI];
    if ((isFirst == 1) && (c == '"')) {
      isQuote = 1;
      continue;
    }
    if (isQuote == 1) {
      if ((c == '"') && (isSlash == 0)) {
        EDI = #tmp + count;
        DSBYTE[EDI] = 0;
        count++;
        arg = malloc(count);
        memcpy(arg, #tmp, count);
        __args[__argv] = arg;
        count = 0;
        memset(#tmp, 0, 256);
        __argv++;
        isFirst = 1;
        isQuote = 0;
        isSlash = 0;
      } else if ((isSlash == 0) && (c == '\\')) {
        isSlash = 1;
      } else {
        EDI = #tmp + count;
        DSBYTE[EDI] = c;
        count++;
        isFirst = 0;
        isSlash = 0;
      }
    } else {
      if ((c == ' ') && (isSlash == 0)) {
        EDI = #tmp + count;
        DSBYTE[EDI] = 0;
        count++;
        arg = malloc(count);
        memcpy(arg, #tmp, count);
        __args[__argv] = arg;
        count = 0;
        memset(#tmp, 0, 256);
        __argv++;
        isFirst = 1;
        isQuote = 0;
        isSlash = 0;
      } else if ((isSlash == 0) && (c == '\\')) {
        isSlash = 1;
      } else {
        EDI = #tmp + count;
        DSBYTE[EDI] = c;
        count++;
        isFirst = 0;
        isSlash = 0;
      }
    }
  }
  if (count > 0) {
    EDI = #tmp + count;
    DSBYTE[EDI] = 0;
    count++;
    arg = malloc(count);
    memcpy(arg, #tmp, count);
    __args[__argv] = arg;
    __argv++;
  }
}

void memcpy(char* dst, char* src; dword size) {
  dword i;
  for (i = 0; i < size; i++) {
    EDI = dst + i;
    ESI = src + i;
    AL = DSBYTE[ESI];
    DSBYTE[EDI] = AL;
  }
}

void memset(char* dst, byte c, dword size) {
  dword i;
  for (i = 0; i < size; i++) {
    EDI = dst + i;
    DSBYTE[EDI] = c;
  }
}

dword strlen(char* src) {
  dword i = 0;
  do {
    ESI = src + i;
    if (DSBYTE[ESI] != 0) {
      i++;
    } else {
      break;
    }
  } while (0);
  return i;
}

// ESI: char*
void printf(dword s) {
  EAX = 0;
  ESI = s;
  $int 0x71;
}

// EDI: DateTime_t*
void GetDateTime(dword EDI) {
  EAX = 7;
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
      EAX = BASENUMBERS[digit % base];
      *str = AL;
      digit /= base;
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

// Memory
dword msize(dword mem) {
  EAX = 4;
  ESI = mem;
  $int 0x61;
}

dword malloc(dword size) {
  EAX = 5;
  ECX = size;
  $int 0x61;
}

void free(dword mem) {
  EAX = 6;
  ESI = mem;
  $int 0x61;
}
