; ------------------------------
public k_IDT_Flush                          ; Allow the Pascal code to call k_IDT_Flush()
; ------------------------------
k_IDT_Flush :
    mov   eax,[esp+4]                       ; Get the pointer to the IDT, passed as a parameter.
    lidt  [eax]                             ; Load the IDT pointer.
    ret

include 'isr.inc'
include 'irq.inc'