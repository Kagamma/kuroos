KM_NONE equ 0x0
KM_KEYUP equ 0x10
KM_KEYDOWN equ 0x20
KM_MOUSEUP equ 0x30
KM_MOUSEDOWN equ 0x40
KM_MOUSESCROLL equ 0x50
KM_MOUSEMOVE equ 0x60
KM_PAINT equ 0x70
KM_CLOSE equ 0x80

include 'include/macro/struct.inc'
include 'include/macro/if.inc'
include 'include/macro/proc32.inc'

; beware these procs dont follow stdcall rules so they will destroy registers ..
; they only serve as a shortcut to interrupt calls

proc kwmCreateWindow kuro_struct
    xor   eax,eax
    mov   esi,[kuro_struct]
    int   0x69
    ret
endp

proc kwmCreateButton kuro_struct
    mov   eax,1
    mov   esi,[kuro_struct]
    int   0x69
    ret
endp

proc kwmCloseHandle kuro_handle
    mov   eax,200
    mov   esi,[kuro_handle]
    int   0x69
    ret
endp

proc kwmRepaint kuro_handle
    mov   eax,100
    mov   esi,[kuro_handle]
    int   0x69
    ret
endp

proc kwmSetName kuro_handle,name
    mov   eax,101
    mov   esi,[kuro_handle]
    mov   ecx,[name]
    int   0x69
    ret
endp

proc kwmCheckMessage kuro_handle
    mov   eax,300
    mov   esi,[kuro_handle]
    int   0x69
    ret
endp

proc kwmSendMessage command, param1, param2
    mov   eax,301
    mov   esi,[kuro_handle]
    mov   ebx,[command]
    mov   ecx,[param1]
    mov   edx,[param2]
    int   0x69
    ret
endp

proc Yield
    int   0x20
    ret
endp
