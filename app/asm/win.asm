org 0x04000000
use32

; KOS header executable (32 bytes).
    db    'K32',0                    ; Header.
    dd    1                          ; Version
    dd    image_end - 0x04000000     ; Image size.
    dd    0x04000000                 ; Startup code.
    dd    0x05000000                 ; Startup heap.
    dd    0x400                      ; Stack size.
    dd    code_section - 0x04000000  ; code point
    dd    0                          ; Icon location.

code_section:
    hlt
    mov   eax,[esp+4]
    mov   [process_id],eax
    jmp   start

include 'kurowm.inc'

start:
    stdcall CreateWindow, kuro_win_struct
    mov   [kuro_handle],eax
    mov   esi,btn_struct
    mov   [esi + 4],eax
    stdcall CreateButton, btn_struct
    mov   [btn_handle],eax

.while 1
    stdcall CheckMessage, [btn_handle]
    .if eax = 1
      .if ebx = KM_MOUSEUP
        stdcall UpdateName, [kuro_handle], btn_clicked_str
      .endif
    .endif
    stdcall CheckMessage, [kuro_handle]        ; Check the message to see if any incoming message around
    .if eax = 1                                ; 1 = yes we have message
      .if ebx = KM_KEYDOWN
        .if cl = 27                            ; ESC? Terminate process
          stdcall Kill
        .else
          stdcall UpdateName, [kuro_handle], key_down_str
        .endif
      .elseif ebx = KM_KEYUP
        stdcall UpdateName, [kuro_handle], key_up_str
      .elseif ebx = KM_MOUSEDOWN
        stdcall UpdateName, [kuro_handle], mouse_down_str
      .elseif ebx = KM_MOUSEUP
        stdcall UpdateName, [kuro_handle], mouse_up_str
      .elseif ebx = KM_CLOSE
        stdcall Kill
      .endif
    .else
      stdcall Yield
    .endif
.endw

proc Kill
    stdcall CloseHandle, [kuro_handle]
    stdcall EndProcess, [process_id]
    ret
endp

data_section:
    kuro_win_struct:
      dd kuro_name                      ; Name
      dd 0                              ; Parent
      dd 255, 87, 300, 200              ; X, Y, Width, Height
      dd 1                              ; IsMovable

    btn_struct:
      dd btn_str                        ; Name
      dd 0                              ; Parent
      dd 80, 130, 140, 24               ; X, Y, Width, Height
      dd 0                              ; IsMovable

    kuro_name        db 'Hello, KuroWin!',0
    key_down_str     db 'Key pressed!',0
    key_up_str       db 'Key released!',0
    mouse_down_str   db 'Mouse down!',0
    mouse_up_str     db 'Mouse up!',0
    btn_clicked_str  db 'Button clicked!',0
    btn_str          db 'Click me!',0
    kuro_handle      dd 0
    btn_handle       dd 0
    process_id       dd 0

image_end: