#include "libs/system.h"
#include "libs/kurowm.h"

KuroView_t win, btn;
DateTime_t dt;
dword winHandle, buttonHandle;
dword msg;
byte sec;
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
    EAX = BASENUMBERS[digit % 10];
    *str = AL;
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
  win.width = 228;
  win.height = 34;
  win.isMovable = 1;
  winHandle = CreateWindow(#win);
  btn.name = "";
  btn.parent = winHandle;
  btn.x = 4;
  btn.y = 4;
  btn.width = 220;
  btn.height = 26;
  btn.isMovable = 0;
  buttonHandle = CreateButton(#btn);
  sec = 0xff;
  while (1) {
    if (CheckMessage(winHandle, #msg) == 1) {
      if (msg == KM_CLOSE) {
        CloseHandle(winHandle);
        break;
      }
    }
    GetDateTime(#dt);
    if (dt.second != sec) {
      timeDigit(dt.second, #timeText + 21);
      timeDigit(dt.minute, #timeText + 18);
      timeDigit(dt.hour, #timeText + 15);
      timeDigit(dt.day, #timeText + 12);
      timeDigit(dt.month, #timeText + 9);
      timeDigit(dt.year, #timeText + 6);
      SetName(buttonHandle, #timeText);
      sec = dt.second;
    }
    yield();
  }
  exit();
}

byte endofcode;
