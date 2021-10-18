macro IRQ func,n {
; ------------------------------
public func
; ------------------------------
func:
  push  0
  push  n
  jmp   irqstub
}

macro IRQ_PIC func,n {
; ------------------------------
public func
; ------------------------------
func:
  jmp   irqpicstub
}

macro IRQ_USER func,n {
; ------------------------------
public func
; ------------------------------
func:
  push  0
  push  n
  jmp   irquserstub
}

macro IRQ_USERCOOP func,n {
; ------------------------------
public func
; ------------------------------
func:
  jmp   irqusercoopstub
}

macro HAVE reg,have,value,nothavejmp,endjmp {
    mov   [tmp],reg
    mov   reg,[have]
    cmp   reg,0
    je    nothavejmp

    xor   reg,reg
    mov   [have],reg
    mov   reg,[value]
    jmp   endjmp
nothavejmp:
    mov   reg,[tmp]
endjmp:
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

IRQ_USERCOOP k_IDT_IRQ96, 0x60
IRQ_USER k_IDT_IRQ97, 0x61
IRQ_USER k_IDT_IRQ105, 0x69
IRQ_USER k_IDT_IRQ113, 0x71

; ------------------------------
extrn k_IDT_IRQ_FaultHandler                   ; External function from Pascal code
extrn k_PIC_Handler                            ;
extrn k_Coop_Handler                           ;
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
irquserstub:
    pusha
    push  ds
    push  es
    push  fs
    push  gs

    mov   ax,0x10                          ; load the kernel data segment descriptor
    mov   ds,ax
    mov   es,ax

    cli                                    ; TODO: Fix this
    call  k_IDT_IRQ_FaultHandler

    pop   gs
    pop   fs
    pop   es
    pop   ds
    popa
    add   esp,8                            ; Cleans up the pushed error code and pushed ISR number

    HAVE  eax,IRQEAXHave,IRQEAXValue,eaxnot,eaxend ; TODO: Fix this
    HAVE  ebx,IRQEBXHave,IRQEBXValue,ebxnot,ebxend
    HAVE  ecx,IRQECXHave,IRQECXValue,ecxnot,ecxend
    HAVE  edx,IRQEDXHave,IRQEDXValue,edxnot,edxend
    HAVE  esi,IRQESIHave,IRQESIValue,esinot,esiend
    HAVE  edi,IRQEDIHave,IRQEDIValue,edinot,ediend

irquserstubend:
    iret                                   ; pops 5 things at once: CS, EIP, EFLAGS, SS, and ESP

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

irqstubend:
    iret                                   ; pops 5 things at once: CS, EIP, EFLAGS, SS, and ESP

irqusercoopstub:
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

    mov   eax,esp
    push  eax

    call  k_Coop_Handler
    mov   esp,eax

    pop   gs
    pop   fs
    pop   es
    pop   ds
    popa

irqusercoopstubend:
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
picend:
    iret