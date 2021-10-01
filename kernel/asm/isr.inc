macro ISR func,n {
; ------------------------------
public func                                    ; Allow the Pascal code to call k_IDT_ISRXX()
; ------------------------------
func:
	cli
	push  0
	push  n
	jmp   isr_common_stub
}

ISR k_IDT_ISR0, 0
ISR k_IDT_ISR1, 1
ISR k_IDT_ISR2, 2
ISR k_IDT_ISR3, 3
ISR k_IDT_ISR4, 4
ISR k_IDT_ISR5, 5
ISR k_IDT_ISR6, 6
ISR k_IDT_ISR7, 7
ISR k_IDT_ISR8, 8
ISR k_IDT_ISR9, 9
ISR k_IDT_ISR10, 10
ISR k_IDT_ISR11, 11
ISR k_IDT_ISR12, 12
ISR k_IDT_ISR13, 13
ISR k_IDT_ISR14, 14
ISR k_IDT_ISR15, 15
ISR k_IDT_ISR16, 16
ISR k_IDT_ISR17, 17
ISR k_IDT_ISR18, 18
ISR k_IDT_ISR19, 19
ISR k_IDT_ISR20, 20
ISR k_IDT_ISR21, 21
ISR k_IDT_ISR22, 22
ISR k_IDT_ISR23, 23
ISR k_IDT_ISR24, 24
ISR k_IDT_ISR25, 25
ISR k_IDT_ISR26, 26
ISR k_IDT_ISR27, 27
ISR k_IDT_ISR28, 28
ISR k_IDT_ISR29, 29
ISR k_IDT_ISR30, 30
ISR k_IDT_ISR31, 31

; ------------------------------
extrn k_IDT_ISR_FaultHandler                   ; Call from Pascal code
; ------------------------------
isr_common_stub:
		pusha
		push  ds
		push  es
		push  fs
		push  gs

		mov   ax,0x10                          ; load the kernel data segment descriptor
		mov   ds,ax
		mov   es,ax

		call  k_IDT_ISR_FaultHandler

		pop   gs
		pop   fs
		pop   es
		pop   ds
		popa
		add   esp,8                            ; Cleans up the pushed error code and pushed ISR number
		sti
		iret                                    ; pops 5 things at once: CS, EIP, EFLAGS, SS, and ESP