include 'system.inc'
include 'kurowm.inc'

code_section:
    stdcall printf, str_lfcr
    stdcall printf, str_hello
    stdcall printf, str_lfcr

    stdcall ThreadCreate, thread_proc
    stdcall ThreadCreate, thread_proc

iloop:
    int   0x20
    jmp   iloop
endprog:
    ret

thread_proc:
    xor   eax,eax
    mov   esi,str_t1
    int   0x71
    mov   eax,1
    mov   ecx,[esp + 8]
    int   0x71
    xor   eax,eax
    mov   esi,str_t2
    int   0x71
    mov   esi,str_lfcr
    int   0x71

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
