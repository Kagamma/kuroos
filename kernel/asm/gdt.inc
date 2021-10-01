; ------------------------------
public k_GDT_Flush                          ; Allow the Pascal code to call k_GDT_Flush()
; ------------------------------
k_GDT_Flush:
	mov   eax,[esp+4]                       ; Get the pointer to the GDT.
	lgdt  [eax]                             ; Load the new GDT pointer
	mov   ax,0x10                           ; 0x10 is the offset in the GDT to our data segment
   	mov   ds,ax                             ; Load all data segment selectors
   	mov   es,ax
   	mov   ss,ax
   	jmp   0x08:.flush
.flush:
    ret