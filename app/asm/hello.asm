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
    xor   eax,eax
    mov   esi,str_lfcr
    int   0x71
    mov   esi,str_hello
    int   0x71
    mov   esi,str_lfcr
    int   0x71

    ; We kill this process...
    mov   eax,3
    mov   ecx,[esp + 4]
    int   0x61

iloop:
    hlt
    jmp    iloop
endprog:
    ret

data_section:
    str_hello    db 'Hello, World!',0
    str_lfcr     db 10,13,0

image_end:
