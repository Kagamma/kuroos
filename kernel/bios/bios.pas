{
    File:
        bios.pas
    Description:
        Handling BIOS calls from protected mode.
    License:
        General Public License (GPL)
}

unit bios;

{$I KOS.INC}

interface

uses
  real,
  sysutils,
  console,
  kheap;

const
  BIOS_INT_MAGIC = $DEADBEEF;

type
  TX86Registers = packed record
    ax, bx, cx, dx, es, si, di: Word;
  end;

// Make an interrupt call in real mode
procedure Int(var Regs: TX86Registers; const AInt: Byte); stdcall;
// This is used to jump from protected mode to real mode
procedure JumpToRM; stdcall; external name 'k_BIOS_JumpToRM';
// Write down real interrupt handler to address 0x7D00
procedure Init; stdcall;

implementation

var
  IntPos_: Cardinal = 0;

procedure Init; stdcall;
var
  i: Cardinal;
  p: Pointer;
begin
  // We store our asm handler in $7D00
  p:= Pointer($7D00);
  for i:= 0 to REAL_SIZE-1 do
  begin
    Byte(p^):= REAL_DATA[i];
    if Cardinal((p - 4)^) = BIOS_INT_MAGIC then
      IntPos_:= $7D00 + i + 1;
    Inc(p);
  end;
end;

procedure Int(var Regs: TX86Registers; const AInt: Byte); stdcall;
var
  p: Pointer;
begin
  p:= Pointer($7C00);
//  Byte((p +  0)^):= Byte(int);

  Byte(Pointer(IntPos_)^):= AInt;

  Word((p +  2)^):= Regs.ax;
  Word((p +  4)^):= Regs.bx;
  Word((p +  6)^):= Regs.cx;
  Word((p +  8)^):= Regs.dx;
  Word((p + 10)^):= Regs.es;
  Word((p + 14)^):= Regs.si;
  Word((p + 16)^):= Regs.di;

  IRQ_DISABLE;
  BIOS.JumpToRM;
  IRQ_ENABLE;

  // Return register results from interrupt
  Regs.ax:= Word((p +  2)^);
  Regs.bx:= Word((p +  4)^);
  Regs.cx:= Word((p +  6)^);
  Regs.dx:= Word((p +  8)^);
  Regs.es:= Word((p + 10)^);
  Regs.si:= Word((p + 14)^);
  Regs.di:= Word((p + 16)^);
end;

end.
