#include "system.h"
#include "kurowm.h"

KuroView win;
dword handle;
dword msg;

void main() {
  win.name = "Empty Window";
  win.parent = 0;
  win.x = 100;
  win.y = 100;
  win.width = 200;
  win.height = 200;
  win.isMovable = 1;
  handle = CreateWindow(#win);
  while (1) {
    if (CheckMessage(handle, #msg) == 1) {
      if (msg == KM_CLOSE) {
        CloseHandle(handle);
        break;
      }
    }
    yield();
  }
  exit();
}

byte endofcode;
