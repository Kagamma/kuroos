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
    mov   eax,1
    mov   esi,str_lfcr
    int   0x71
    mov   esi,str_hello
    int   0x71
    mov   esi,str_lfcr
    int   0x71

    ; We kill this process...
    mov   eax,4
    mov   ecx,[esp + 4]
    int   0x61

iloop:
    hlt
    jmp    iloop
endprog:
    ret

data_section:
    str_hello    db 'TODO: Memtest',0
    str_lfcr     db 10,13,0

image_end:
