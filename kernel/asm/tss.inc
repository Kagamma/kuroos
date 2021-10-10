; ------------------------------
public k_TSS_Flush                          ; Allow the Pascal code to call k_TSS_Flush()
; ------------------------------
k_TSS_Flush :
    mov   ax,0x3B
    ltr   ax
    ret
