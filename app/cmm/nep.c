#include "libs/system.h"
#include "libs/kurowm.h"

KuroView_t win, image;
dword winHandle, imageHandle;
dword msg;
char* imagePath = "nep.bmp";
dword x, y;
int dx = 1, dy = 1;

void main() {
  win.name = "Nep!";
  win.parent = 0;
  win.x = 100;
  win.y = 100;
  win.width = 200;
  win.height = 150;
  win.attrFlag = 1;
  winHandle = kwmCreateWindow(#win);
  image.name = "image";
  image.parent = winHandle;
  image.x = 2;
  image.y = 2;
  image.attrFlag = 0;
  imageHandle = kwmCreateImage(#image, imagePath);
  x = image.x;
  y = image.y;
  while (1) {
    if (kwmCheckMessage(winHandle, #msg) == 1) {
      if (msg == KM_CLOSE) {
        kwmCloseHandle(winHandle);
        break;
      }
    }
    x += dx;
    y += dy;
    if ((x > 200 - 68) || (x < 2)) dx = -dx;
    if ((y > 150 - 68) || (y < 2)) dy = -dy;
    kwmSetPosition(imageHandle, x, y);
    yield();
  }
  exit();
}

byte endofcode;
