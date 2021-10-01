#define KM_NONE 0x0
#define KM_KEYUP 0x10
#define KM_KEYDOWN 0x20
#define KM_MOUSEUP 0x30
#define KM_MOUSEDOWN 0x40
#define KM_MOUSESCROLL 0x50
#define KM_MOUSEMOVE 0x60
#define KM_PAINT 0x70
#define KM_CLOSE 0x80

struct KuroView {
  char *name;
  dword parent;
  dword x;
  dword y;
  dword width;
  dword height;
  dword isMovable;
};

inline fastcall dword CreateWindow(dword ESI) {
  EAX = 1;
  $int 0x69;
}

inline fastcall dword CloseHandle(dword ESI) {
  EAX = 0x301;
  $int 0x69;
}

dword CheckMessage(dword ESI, dword *msg) {
  EAX = 0x401;
  $int 0x69;
  $mov DSDWORD[msg],ebx;
}
