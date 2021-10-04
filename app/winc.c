#include "system.h"
#include "kurowm.h"

char name1 = "Sphinx C--";
char name2 = "Empty Window";
KuroView_t win;
DateTime_t dt;
dword handle;
dword msg;
dword n;

void main() {
  win.name = #name1;
  win.parent = 0;
  win.x = 100;
  win.y = 100;
  win.width = 200;
  win.height = 200;
  win.isMovable = 1;
  handle = CreateWindow(#win);
  GetDateTime(#dt);
  n = dt.second;
  while (1) {
    if (CheckMessage(handle, #msg) == 1) {
      if (msg == KM_CLOSE) {
        CloseHandle(handle);
        break;
      }
    }
    GetDateTime(#dt);
    if (dt.second != n) {
      switch (n % 2) {
        case 0:
          UpdateName(handle, #name1);
          break;
        default:
          UpdateName(handle, #name2);
          break;
      }
      n = dt.second;
    }
    yield();
  }
  exit();
}

byte endofcode;
