org 0x04000000
use32

; KOS header executable (28 bytes).
    db    'K32',0                    ; Header.
    dd    1                          ; Version
    dd    image_end - 0x04000000     ; Image size.
    dd    0x04000000                 ; Startup code.
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

    ; Create a new thread
    mov   eax,1
    mov   ecx,0x400
    mov   esi,thread_proc
    int   0x61
    hlt
    ;
    mov   eax,1
    mov   ecx,0x400
    mov   esi,thread_proc
    int   0x61

    ; We kill this process...
    ;mov   eax,4
    ;mov   ecx,[esp + 4]
    ;int   0x61

iloop:
    int   0x20
    jmp   iloop
endprog:
    ret

thread_proc:

    mov   eax,1
    mov   esi,str_t1
    int   0x71
    mov   eax,2
    mov   ecx,[esp + 4]
    int   0x71
    mov   eax,1
    mov   esi,str_t2
    int   0x71
    mov   esi,str_lfcr
    int   0x71

    ; We kill this thread...
    ;mov   eax,2
    ;mov   ecx,[esp + 4]
    ;int   0x61
tloop:
    int   0x20
    jmp   tloop
    ret

data_section:
    str_hello    db 'Create a process with 2 persistent threads! (type "ps" to see them)',0
    str_t1       db 'Thread ID ',0
    str_t2       db ' Created!',0
    str_lfcr     db 10,13,0

image_end:
