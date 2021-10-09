format binary
org 0x7D00

use32
; Clear the PE bit
    mov   eax,cr0
    and   al,0xFE      ; Disable PE.
    mov   cr0,eax	   ; Enter real mode.
use16
    jmp   0x0:.RealMode

.RealMode:
; Setup 16bit real mode registers
    xor   ax,ax
    mov   ds,ax
    mov   es,ax
    mov   eax,0xFFFF
    mov   esp,eax
    mov   ax,0x2000
    mov   ss,ax

; Install and enable IDT.
    lidt  [idt_real]
    sti

    mov   ax,[0x7C00 + 10]
    mov   es,ax
    mov   ax,[0x7C00 + 2]
    mov   bx,[0x7C00 + 4]
    mov   cx,[0x7C00 + 6]
    mov   dx,[0x7C00 + 8]
    mov   si,[0x7C00 + 14]
    mov   di,[0x7C00 + 16]
jmp .n
    dd    0xDEADBEEF
.n:
    int   0x10

    mov   [0x7C00 + 2],ax
    mov   [0x7C00 + 4],bx
    mov   [0x7C00 + 6],cx
    mov   [0x7C00 + 8],dx
    mov   [0x7C00 + 10],es
    mov   [0x7C00 + 14],si
    mov   [0x7C00 + 16],di

; Disable IDT, install GDT and jump to PM.
    cli
    lgdt  [0x7F00]
    mov   ecx,[0x7CFC]
    mov   eax,cr0
    or    al,1
    mov   cr0,eax
    jmp   0x8:.ReturnToPM

; Switch back to protected mode
.ReturnToPM:
use32
    jmp   ecx

idt_real:
    dw 0x3FF
    dd 0
