include 'libs/header.inc'
include 'libs/system.inc'
include 'libs/kurowm.inc'

code_section:
    mov   eax,[esp + 8]
    mov   [process_id],eax
    stdcall printf, str_lfcr
    stdcall printf, str_hello
    stdcall printf, str_lfcr

    ; We kill this process...
    stdcall Exit, [process_id]

data_section:
    str_hello    db 'Hello, World from Userspace!',0
    str_lfcr     db 10,13,0
    process_id   dd 0

image_end:
