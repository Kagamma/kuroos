include 'libs/header.inc'
include 'libs/system.inc'
include 'libs/kurowm.inc'

code_section:
    stdcall printf, str_lfcr
    stdcall printf, str_hello
    stdcall printf, str_lfcr

    stdcall ThreadCreate, thread_proc
    stdcall ThreadCreate, thread_proc
iloop:
    int   0x60
    jmp   iloop
endprog:
    ret

thread_proc:
    mov   eax,[esp + 8]
    mov   [thread_id],eax
    stdcall printf, str_t1
    stdcall printfnum, [thread_id]
    stdcall printf, str_t2
    stdcall printf, str_lfcr
tloop:
    int   0x60
    jmp   tloop
    ret

data_section:
    str_hello    db 'Create a process with 2 persistent threads! (type "ps" to see them)',0
    str_t1       db 'Thread ID ',0
    str_t2       db ' Created!',0
    str_lfcr     db 10,13,0
    thread_id    dd 0

image_end:
