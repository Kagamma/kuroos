#define KM_NONE 0x0
#define KM_KEYUP 0x10
#define KM_KEYDOWN 0x20
#define KM_MOUSEUP 0x30
#define KM_MOUSEDOWN 0x40
#define KM_MOUSESCROLL 0x50
#define KM_MOUSEMOVE 0x60
#define KM_PAINT 0x70
#define KM_CLOSE 0x80

struct KuroView_t {
  char *name;
  dword parent;
  dword x;
  dword y;
  dword width;
  dword height;
  dword attrFlag;
};

// ESI: KuroView_t*
dword kwmCreateWindow(dword ESI) {
  EAX = 0;
  $int 0x69;
}

// ESI: KuroView_t*
dword kwmCreateButton(dword ESI) {
  EAX = 1;
  $int 0x69;
}

// ESI: KuroView_t*
// ECX: Image path
dword kwmCreateImage(dword ESI, ECX) {
  EAX = 2;
  $int 0x69;
}

// ESI: handle
dword kwmCloseHandle(dword ESI) {
  EAX = 200;
  $int 0x69;
}

// ESI: handle
// ECX: char*
void kwmSetName(dword ESI, ECX) {
  EAX = 101;
  $int 0x69;
}

// ESI: handle
// ECX: X
// EDX: Y
void kwmSetPosition(dword ESI, dword ECX, dword EDX) {
  EAX = 102;
  $int 0x69;
}

// ESI: handle
// msg: result message
dword kwmCheckMessage(dword ESI, dword *msg) {
  EAX = 300;
  $int 0x69;
  $mov DSDWORD[msg],ebx;
}
