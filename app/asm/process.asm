org 0x04000000
use32

; KOS header executable (24 bytes).
    db    'K32',0                    ; Header.
    dd    1                          ; Version
    dd    image_end - 0x04000000     ; Image size.
    dd    0x400                      ; Stack size.
    dd    code_section               ; code point
    dd    0                          ; Icon location.

code_section:
    mov   eax,1
    mov   esi,str_lfcr
    int   0x71
    mov   esi,str_p1
    int   0x71
    mov   esi,str_lfcr
    int   0x71
    mov   esi,str_pid
    int   0x71
    mov   ecx,[esp + 4]
    mov   eax,2
    int   0x71
    mov   eax,1
    mov   esi,str_lfcr
    int   0x71

iloop:
    int   0x20
    jmp   iloop
endprog:
    ret

data_section:
    str_p1       db 'This is a persistent process! (type "ps" to see it)',0
    str_pid      db 'Process ID: ',0
    str_lfcr     db 10,13,0

image_end:
