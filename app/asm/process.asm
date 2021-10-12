include 'system.inc'
include 'kurowm.inc'

code_section:
    mov   eax,[esp + 8]
    mov   [process_id],eax
    stdcall printf, str_lfcr
    stdcall printf, str_p1
    stdcall printf, str_lfcr
    stdcall printf, str_pid
    stdcall printfnum, [process_id]
    stdcall printf, str_lfcr

iloop:
    int   0x20
    jmp   iloop
endprog:
    ret

data_section:
    str_p1       db 'This is a persistent process! (type "ps" to see it)',0
    str_pid      db 'Process ID: ',0
    str_lfcr     db 10,13,0
    process_id   dd 0

image_end:
