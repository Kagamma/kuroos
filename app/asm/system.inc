org 0x08048000
use32

; KOS header executable (24 bytes).
    db    'K32',0                    ; Header.
    dd    1                          ; Version
    dd    image_end - 0x08048000     ; Image size.
    dd    0x400                      ; Stack size.
    dd    code_section               ; entry point
    dd    0                          ; Icon location.

include 'include/macro/struct.inc'
include 'include/macro/if.inc'
include 'include/macro/proc32.inc'

proc Exit process_id
    mov   eax,3
    mov   ecx,[process_id]
    int   0x61
iloop:
    int   0x20
    jmp   iloop
endp

proc printf address
    xor   eax,eax
    mov   esi,[address]
    int   0x71
    ret
endp

proc printfnum num
    mov   eax,1
    mov   ecx,[num]
    int   0x71
    ret
endp

proc ThreadCreate proc
    xor   eax,eax
    mov   ecx,0x400
    mov   esi,[proc]
    int   0x61
    ret
endp