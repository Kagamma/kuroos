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
    lgdt  [gdt_protected]
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

gdt_null:
    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
gdt_r0_32bit_code:
    db 0xFF,0xFF,0x00,0x00,0x00,0x9A,0xCF,0x00
gdt_r0_32bit_data:
     db 0xFF,0xFF,0x00,0x00,0x00,0x92,0xCF,0x00
gdt_r3_32bit_code:
    db 0xFF,0xFF,0x00,0x00,0x00,0xFA,0xCF,0x00
gdt_r3_32bit_data:
    db 0xFF,0xFF,0x00,0x00,0x00,0xF2,0xCF,0x00
gdt_16bit_code:
    db 0xFF,0x00,0x00,0x00,0x00,0x9A,0x80,0x00
gdt_16bit_data:
     db 0xFF,0x00,0x00,0x00,0x00,0x92,0x80,0x00
gdt_protected:
    dw gdt_protected - gdt_null - 1
    dd gdt_null
