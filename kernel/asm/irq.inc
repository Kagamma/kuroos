macro IRQ func,n {
; ------------------------------
public func
; ------------------------------
func:
	cli
  push  0                        ; TODO: We need to replace this line and push proper error code to stack.
	push  n
	jmp   irqstub
}

macro IRQ_PIC func,n {
; ------------------------------
public func
; ------------------------------
func:
	cli
	jmp   irqpicstub
}

IRQ_PIC k_IDT_IRQ0, 32
IRQ k_IDT_IRQ1, 33
IRQ k_IDT_IRQ2, 34
IRQ k_IDT_IRQ3, 35
IRQ k_IDT_IRQ4, 36
IRQ k_IDT_IRQ5, 37
IRQ k_IDT_IRQ6, 38
IRQ k_IDT_IRQ7, 39
IRQ k_IDT_IRQ8, 40
IRQ k_IDT_IRQ9, 41
IRQ k_IDT_IRQ10, 42
IRQ k_IDT_IRQ11, 43
IRQ k_IDT_IRQ12, 44
IRQ k_IDT_IRQ13, 45
IRQ k_IDT_IRQ14, 46
IRQ k_IDT_IRQ15, 47

IRQ k_IDT_IRQ20, 52
IRQ k_IDT_IRQ21, 53

IRQ k_IDT_IRQ97, 0x61
IRQ k_IDT_IRQ105, 0x69
IRQ k_IDT_IRQ113, 0x71

; ------------------------------
extrn k_IDT_IRQ_FaultHandler                   ; External function from Pascal code
extrn k_PIC_Handler                            ;
public  IRQEAXHave
public  IRQEAXValue
public  IRQEBXHave
public  IRQEBXValue
public  IRQECXHave
public  IRQECXValue
public  IRQEDXHave
public  IRQEDXValue
public  IRQESIHave
public  IRQESIValue
public  IRQEDIHave
public  IRQEDIValue
IRQEAXHave  dd 0
IRQEAXValue dd 0
IRQEBXHave  dd 0
IRQEBXValue dd 0
IRQECXHave  dd 0
IRQECXValue dd 0
IRQEDXHave  dd 0
IRQEDXValue dd 0
IRQESIHave  dd 0
IRQESIValue dd 0
IRQEDIHave  dd 0
IRQEDIValue dd 0
tmp      dd 0
; ------------------------------
irqstub:
		pusha
		push  ds
		push  es
		push  fs
		push  gs

		mov   ax,0x10                          ; load the kernel data segment descriptor
		mov   ds,ax
		mov   es,ax

		call  k_IDT_IRQ_FaultHandler

		pop   gs
		pop   fs
		pop   es
		pop   ds
   	popa
   	add   esp,8                            ; Cleans up the pushed error code and pushed ISR number

		mov   [tmp],eax
		mov   eax,[IRQEAXHave]
		cmp   eax,0
		je    eax_nothave
eax_have:
    xor   eax,eax
		mov   [IRQEAXHave],eax
		mov   eax,[IRQEAXValue]
		jmp   eax_end
eax_nothave:
		mov   eax,[tmp]
eax_end:

		mov   [tmp],ebx
		mov   ebx,[IRQEBXHave]
		cmp   ebx,0
		je    ebx_nothave
ebx_have:
    xor   ebx,ebx
		mov   [IRQEBXHave],ebx
		mov   ebx,[IRQEBXValue]
		jmp   ebx_end
ebx_nothave:
		mov   ebx,[tmp]
ebx_end:

		mov   [tmp],ecx
		mov   ecx,[IRQECXHave]
		cmp   ecx,0
		je    ecx_nothave
ecx_have:
    xor   ecx,ecx
		mov   [IRQECXHave],ecx
		mov   ecx,[IRQECXValue]
		jmp   ecx_end
ecx_nothave:
		mov   ecx,[tmp]
ecx_end:

		mov   [tmp],edx
		mov   edx,[IRQEDXHave]
		cmp   edx,0
		je    edx_nothave
edx_have:
    xor   edx,edx
		mov   [IRQEDXHave],edx
		mov   edx,[IRQEDXValue]
		jmp   edx_end
edx_nothave:
		mov   edx,[tmp]
edx_end:

		mov   [tmp],esi
		mov   esi,[IRQESIHave]
		cmp   esi,0
		je    esi_nothave
esx_have:
    xor   esi,esi
		mov   [IRQESIHave],edx
		mov   esi,[IRQESIValue]
		jmp   esi_end
esi_nothave:
		mov   esi,[tmp]
esi_end:

		mov   [tmp],edi
		mov   edi,[IRQEDIHave]
		cmp   edi,0
		je    edi_nothave
edi_have:
    xor   edi,edi
		mov   [IRQEDIHave],edi
		mov   edi,[IRQEDIValue]
		jmp   edi_end
edi_nothave:
		mov   edi,[tmp]
edi_end:

irq_stub_end:
		sti
   	iret                                   ; pops 5 things at once: CS, EIP, EFLAGS, SS, and ESP

irqpicstub:
		pusha
		push  ds
		push  es
		push  fs
		push  gs

   	mov   ax,0x10                          ; load the kernel data segment descriptor
   	mov   ds,ax
   	mov   es,ax
		mov   fs,ax
   	mov   gs,ax

		; push  8
		; push  eax
		; call  k_Console_WriteHex
		; push  ' '
		; call  k_Console_WriteChar

		mov   eax,esp
		push  eax

call  k_PIC_Handler
		mov   esp,eax

		mov   al,0x20                          ; ack IRQ
		out   0x20,al

   	pop   gs
		pop   fs
		pop   es
		pop   ds
   	popa
pic_end:
		sti
   	iret