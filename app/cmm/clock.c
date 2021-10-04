#include "system.h"
#include "kurowm.h"

KuroView_t win;
DateTime_t dt;
dword handle;
dword msg;
char timeText = "Time: yy/mm/dd hh:mm:ss\0";

void timeDigit(dword num, char* c) {
  char buf[14];
  byte* str;
  dword digit;

  for (digit = 0; digit < 14; digit++) {
    buf[digit] = 0;
  }
  str = #buf[12];
  *str = 0;
  digit = num;
  do {
    str -= 1;
    *str = digit % 10 + 0x30;
    digit /= 10;
  } while (digit != 0);
  str = #buf[0];
  while (*str == 0) {
    *str = '0';
    str++;
  }
  str = #buf[12] - 2;
  while (*str != 0) {
    *c = *str;
    str++;
    c++;
  }
}

void main() {
  win.name = "Clock";
  win.parent = 0;
  win.x = rnd() % 400 + 10;
  win.y = rnd() % 400 + 10;
  win.width = 250;
  win.height = 27;
  win.isMovable = 1;
  handle = CreateWindow(#win);
  while (1) {
    if (CheckMessage(handle, #msg) == 1) {
      if (msg == KM_CLOSE) {
        CloseHandle(handle);
        break;
      }
    }
    GetDateTime(#dt);
    timeDigit(dt.second, #timeText + 21);
    timeDigit(dt.minute, #timeText + 18);
    timeDigit(dt.hour, #timeText + 15);
    timeDigit(dt.day, #timeText + 12);
    timeDigit(dt.month, #timeText + 9);
    timeDigit(dt.year, #timeText + 6);
    UpdateName(handle, #timeText);
    yield();
  }
  exit();
}

byte endofcode;
