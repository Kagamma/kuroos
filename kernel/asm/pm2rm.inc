use32

public k_BIOS_JumpToRM

extrn  k_IDT_RemapIRQPM
extrn  k_IDT_RemapIRQRM
extrn  k_IDT_RestoreIRQs

k_BIOS_JumpToRM:
    pusha
    pushf

; Disable all IRQs
    call  k_IDT_RemapIRQRM
    mov   al,0xFF
    out   0xA1,al
    out   0x21,al

  	mov   ax,ss
    mov   [save_ss],ax        ; Save SS
	  mov   eax,esp
    mov   [save_esp],eax      ; Save ESP
  	mov   eax,cr3
    mov   [save_cr3],eax      ; Save CR3
    mov   eax,cr0
    mov   [save_cr0],eax      ; Save CR0
	and   eax,0x7FFFFFFF      ; Disable PG.
  	mov   cr0,eax

; Store the address of return code to 0x7CFC
    mov   esi,0x7CFC
    mov   [esi],dword .ReturnToPM

; Setup 16bit protected mode registers
    mov   ax,0x30
    mov   ds,ax
    mov   es,ax
    mov   fs,ax
    mov   gs,ax

    jmp   0x28:0x7D00

.ReturnToPM:
; Restore protected-mode registers
    mov   ax,0x10
    mov   ds,ax
    mov   es,ax

    mov   ax, [save_ss]
    mov   ss,ax
    mov   eax,[save_esp]
    mov   esp,eax
    mov	  eax,[save_cr3]
    mov   cr3,eax
    mov	  eax,[save_cr0]
    mov   cr0,eax

; Enable all IRQs
    call  k_IDT_RemapIRQPM
    call  k_IDT_RestoreIRQs
    mov   al,$20
    out   $A0,al
    out   $20,al

    popf
    popa
    ret

save_cr0:
    dd 0
save_cr3:
    dd 0
save_esp:
    dd 0
save_ss:
    dw 0

