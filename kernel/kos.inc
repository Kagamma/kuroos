{$ASMMODE INTEL}
{$MACRO ON}
// Enable AnsiStrings
{$H+}

{$DEFINE DEBUG}

// Disable hand-crafted assembly in some functions
{$DEFINE PUREPASCAL}

{$DEFINE IRQ_ENABLE := asm sti end}
{$DEFINE IRQ_DISABLE:= asm cli end}
{$DEFINE INFINITE_LOOP:= ;
  asm
    @loop:
      hlt
      jmp @loop
  end
}
{$DEFINE CPU_HALT:= asm sti; hlt; end}
{$DEFINE PROCESS_WAIT:= asm int $20; end}
{$DEFINE BREAKPOINT:= asm int 3; end}
