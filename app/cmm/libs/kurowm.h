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
dword kwmCreateWindow(dword w) {
  EAX = 0;
  ESI = w;
  $int 0x69;
}

// ESI: KuroView_t*
dword kwmCreateButton(dword w) {
  EAX = 1;
  ESI = w;
  $int 0x69;
}

// ESI: KuroView_t*
// ECX: Image path
dword kwmCreateImage(dword w, dword path) {
  EAX = 2;
  ECX = path;
  ESI = w;
  $int 0x69;
}

// ESI: handle
dword kwmCloseHandle(dword h) {
  EAX = 200;
  ESI = h;
  $int 0x69;
}

// ESI: handle
// ECX: char*
void kwmSetName(dword h, dword s) {
  EAX = 101;
  ECX = s;
  ESI = h;
  $int 0x69;
}

// ESI: handle
// ECX: X
// EDX: Y
void kwmSetPosition(dword h, dword x, dword y) {
  EAX = 102;
  ESI = h;
  ECX = x;
  EDX = y;
  $int 0x69;
}

// ESI: handle
// msg: result message
dword kwmCheckMessage(dword h, dword *msg) {
  EAX = 300;
  ESI = h;
  $int 0x69;
  $mov DSDWORD[msg],ebx;
}
