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
  EAX = 1;
  $int 0x69;
}

// ESI: KuroView_t*
dword kwmCreateButton(dword ESI) {
  EAX = 2;
  $int 0x69;
}

// ESI: KuroView_t*
// ECX: Image path
dword kwmCreateImage(dword ESI, ECX) {
  EAX = 3;
  $int 0x69;
}

// ESI: handle
dword kwmCloseHandle(dword ESI) {
  EAX = 0x301;
  $int 0x69;
}

// ESI: handle
// ECX: char*
void kwmSetName(dword ESI, ECX) {
  EAX = 0x201;
  $int 0x69;
}

// ESI: handle
// ECX: X
// EDX: Y
void kwmSetPosition(dword ESI, dword ECX, dword EDX) {
  EAX = 0x202;
  $int 0x69;
}

// ESI: handle
// msg: result message
dword kwmCheckMessage(dword ESI, dword *msg) {
  EAX = 0x401;
  $int 0x69;
  $mov DSDWORD[msg],ebx;
}
