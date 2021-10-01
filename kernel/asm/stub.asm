format elf
use32

; MULTIBOOT header defines
MB_PAGE_ALIGN	    equ (1 shl 0)
MB_MEMORY_INFO	    equ (1 shl 1)
MB_AOUT_KLUDGE	    equ (1 shl 16)
MB_HEADER_MAGIC	    equ 0x1BADB002
MB_HEADER_FLAGS	    equ MB_PAGE_ALIGN or MB_MEMORY_INFO
MB_CHECKSUM         equ -(MB_HEADER_MAGIC + MB_HEADER_FLAGS)

KERNEL_VIRTUAL_BASE equ 0xC0000000                   ; 3GB
KERNEL_PAGE_INDEX   equ (KERNEL_VIRTUAL_BASE >> 22)  ; Page directory index of kernel's 4MB PTE.

; Kernel stack size
KERNEL_STACKSIZE    equ 0x10000

; ------------------------------
; ------------------------------
; ------------------------------

section '.text' executable
use32

align 4

public k_boot
extrn  k_code
extrn  k_bss
extrn  k_end
; ------------------------------
k_boot:
    dd    MB_HEADER_MAGIC
    dd    MB_HEADER_FLAGS
    dd    MB_CHECKSUM

public k_start                                  ; Kernel entry point
extrn  k_main                                   ; Code
; ------------------------------
k_start:
    mov   esp,KERNEL_STACK+KERNEL_STACKSIZE ; Create kernel stack
    push  esp                               ; Kernel stack
    push  eax                               ; ELFBOOT magic number
    push  ebx                               ; ELFBOOT info
    sti
    call  k_main                            ; Call kernel entrypoint
    cli
    hlt

; ------------------------------
include 'gdt.inc'
include 'idt.inc'
include 'pm2rm.inc'

; ------------------------------
; ------------------------------
; ------------------------------

section '.bss'

; Kernel stack location
KERNEL_STACK:
    rb KERNEL_STACKSIZE

section '.data'
