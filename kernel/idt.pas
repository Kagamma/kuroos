{
    File:
        idt.pas
    Description:
        N/A.
    License:
        General Public License (GPL)
}

unit idt;

{$I KOS.INC}

interface

uses
  console;

type
  TIDTEntry = packed record
    base_lo,             // The lower 16 bits of the address to jump to when this interrupt fires.
    sel    : Word;       // Kernel segment selector.
    zero,                // This must always be zero.
    attr   : Byte;       // Attributes.
    base_hi: Word;       // The upper 16 bits of the address to jump to.
  end;
  PIDTEntry = ^TIDTEntry;

  TIDTPtr = packed record
    limit: Word;
    base : Cardinal;     // The address of the first TIDTEntry struct.
  end;
  PIDTPtr = ^TIDTPtr;

  TRegisters = packed record
    //ds, es, fs, gs,
    gs, fs, es, ds,
    edi, esi, ebp, useless_value, ebx, edx, ecx, eax,
    int_no, err_code,
    eip, cs, eflags, esp, ss: Cardinal;
  end;
  PRegisters = ^TRegisters;

  TIDTHandle = procedure(r: TRegisters); stdcall;
  TPICHandle = function(AStack: Cardinal): Cardinal; stdcall;

var
  IRQEAXHave   : Cardinal; external name 'IRQEAXHave';
  IRQEAXValue  : Cardinal; external name 'IRQEAXValue';
  IRQEBXHave   : Cardinal; external name 'IRQEBXHave';
  IRQEBXValue  : Cardinal; external name 'IRQEBXValue';
  IRQECXHave   : Cardinal; external name 'IRQECXHave';
  IRQECXValue  : Cardinal; external name 'IRQECXValue';
  IRQEDXHave   : Cardinal; external name 'IRQEDXHave';
  IRQEDXValue  : Cardinal; external name 'IRQEDXValue';
  IRQESIHave   : Cardinal; external name 'IRQESIHave';
  IRQESIValue  : Cardinal; external name 'IRQESIValue';
  IRQEDIHave   : Cardinal; external name 'IRQEDIHave';
  IRQEDIValue  : Cardinal; external name 'IRQEDIValue';
  IDTEntries: array[0..255] of TIDTEntry;
  IDTPtr    : TIDTPtr;

  IDTHandles: array[0..255] of TIDTHandle;
  PICHandle : TPICHandle;

// Access ASM functions from Pascal code
procedure Flush(AGDTPtr: Cardinal); stdcall; external name 'k_IDT_Flush';

procedure ISR0; stdcall; external name 'k_IDT_ISR0';
procedure ISR1; stdcall; external name 'k_IDT_ISR1';
procedure ISR2; stdcall; external name 'k_IDT_ISR2';
procedure ISR3; stdcall; external name 'k_IDT_ISR3';
procedure ISR4; stdcall; external name 'k_IDT_ISR4';
procedure ISR5; stdcall; external name 'k_IDT_ISR5';
procedure ISR6; stdcall; external name 'k_IDT_ISR6';
procedure ISR7; stdcall; external name 'k_IDT_ISR7';
procedure ISR8; stdcall; external name 'k_IDT_ISR8';
procedure ISR9; stdcall; external name 'k_IDT_ISR9';
procedure ISR10; stdcall; external name 'k_IDT_ISR10';
procedure ISR11; stdcall; external name 'k_IDT_ISR11';
procedure ISR12; stdcall; external name 'k_IDT_ISR12';
procedure ISR13; stdcall; external name 'k_IDT_ISR13';
procedure ISR14; stdcall; external name 'k_IDT_ISR14';
procedure ISR15; stdcall; external name 'k_IDT_ISR15';
procedure ISR16; stdcall; external name 'k_IDT_ISR16';
procedure ISR17; stdcall; external name 'k_IDT_ISR17';
procedure ISR18; stdcall; external name 'k_IDT_ISR18';
procedure ISR19; stdcall; external name 'k_IDT_ISR19';
procedure ISR20; stdcall; external name 'k_IDT_ISR20';
procedure ISR21; stdcall; external name 'k_IDT_ISR21';
procedure ISR22; stdcall; external name 'k_IDT_ISR22';
procedure ISR23; stdcall; external name 'k_IDT_ISR23';
procedure ISR24; stdcall; external name 'k_IDT_ISR24';
procedure ISR25; stdcall; external name 'k_IDT_ISR25';
procedure ISR26; stdcall; external name 'k_IDT_ISR26';
procedure ISR27; stdcall; external name 'k_IDT_ISR27';
procedure ISR28; stdcall; external name 'k_IDT_ISR28';
procedure ISR29; stdcall; external name 'k_IDT_ISR29';
procedure ISR30; stdcall; external name 'k_IDT_ISR30';
procedure ISR31; stdcall; external name 'k_IDT_ISR31';

procedure IRQ0; stdcall; external name 'k_IDT_IRQ0';
procedure IRQ1; stdcall; external name 'k_IDT_IRQ1';
procedure IRQ2; stdcall; external name 'k_IDT_IRQ2';
procedure IRQ3; stdcall; external name 'k_IDT_IRQ3';
procedure IRQ4; stdcall; external name 'k_IDT_IRQ4';
procedure IRQ5; stdcall; external name 'k_IDT_IRQ5';
procedure IRQ6; stdcall; external name 'k_IDT_IRQ6';
procedure IRQ7; stdcall; external name 'k_IDT_IRQ7';
procedure IRQ8; stdcall; external name 'k_IDT_IRQ8';
procedure IRQ9; stdcall; external name 'k_IDT_IRQ9';
procedure IRQ10; stdcall; external name 'k_IDT_IRQ10';
procedure IRQ11; stdcall; external name 'k_IDT_IRQ11';
procedure IRQ12; stdcall; external name 'k_IDT_IRQ12';
procedure IRQ13; stdcall; external name 'k_IDT_IRQ13';
procedure IRQ14; stdcall; external name 'k_IDT_IRQ14';
procedure IRQ15; stdcall; external name 'k_IDT_IRQ15';

procedure IRQ20; stdcall; external name 'k_IDT_IRQ20';
procedure IRQ21; stdcall; external name 'k_IDT_IRQ21';

procedure IRQ97; stdcall; external  name 'k_IDT_IRQ97';
procedure IRQ105; stdcall; external  name 'k_IDT_IRQ105';
procedure IRQ113; stdcall; external name 'k_IDT_IRQ113';

// Set interrupt
procedure SetGate(AIndex: LongInt; ABase: Cardinal; sel: Word; attr: Byte); stdcall;
// Init interrupt descriptor table
procedure Init; stdcall;
// Install Handle
procedure InstallHandler(AIndex: Byte; AHandle: TIDTHandle); stdcall;
procedure InstallPICHandler(AHandle: TPICHandle); stdcall;
// Remap the irq for pm.
procedure RemapIRQPM; stdcall;
// Remap the irq for rm.
procedure RemapIRQRM; stdcall;
// Restore IRQ
procedure RestoreIRQs; stdcall;

implementation

// Set interrupt
procedure SetGate(AIndex: LongInt; ABase: Cardinal; sel: Word; attr: Byte); stdcall;
begin
  IDTEntries[AIndex].base_lo:= ABase and $FFFF;
  IDTEntries[AIndex].base_hi:= (ABase shr 16) and $FFFF;

  IDTEntries[AIndex].sel    := sel;
  IDTEntries[AIndex].zero   := 0;
  // We must uncomment the or below when we get to using user-mode.
  // It sets the interrupt gate's privilege level to 3.
  IDTEntries[AIndex].attr   := attr; // or $60
end;

// Init interrupt descriptor table
procedure Init; stdcall;
begin
  IRQ_DISABLE;

  //Console.WriteStr('Installing IDT... ');
  IDTPtr.limit:= (SizeOf(TIDTEntry) * 256) - 1;
  IDTPtr.base := Cardinal(@IDTEntries);

  FillChar(IDTEntries[0], SizeOf(TIDTEntry) * 256, 0);
  FillChar(IDTHandles[0], SizeOf(TIDTHandle) * 256, 0);
  PICHandle:= nil;

  IDT.SetGate(0, Cardinal(@IDT.ISR0), $08, $8E);
  IDT.SetGate(1, Cardinal(@IDT.ISR1), $08, $8E);
  IDT.SetGate(2, Cardinal(@IDT.ISR2), $08, $8E);
  IDT.SetGate(3, Cardinal(@IDT.ISR3), $08, $8E);
  IDT.SetGate(4, Cardinal(@IDT.ISR4), $08, $8E);
  IDT.SetGate(5, Cardinal(@IDT.ISR5), $08, $8E);
  IDT.SetGate(6, Cardinal(@IDT.ISR6), $08, $8E);
  IDT.SetGate(7, Cardinal(@IDT.ISR7), $08, $8E);
  IDT.SetGate(8, Cardinal(@IDT.ISR8), $08, $8E);
  IDT.SetGate(9, Cardinal(@IDT.ISR9), $08, $8E);
  IDT.SetGate(10, Cardinal(@IDT.ISR10), $08, $8E);
  IDT.SetGate(11, Cardinal(@IDT.ISR11), $08, $8E);
  IDT.SetGate(12, Cardinal(@IDT.ISR12), $08, $8E);
  IDT.SetGate(13, Cardinal(@IDT.ISR13), $08, $8E);
  IDT.SetGate(14, Cardinal(@IDT.ISR14), $08, $8E);
  IDT.SetGate(15, Cardinal(@IDT.ISR15), $08, $8E);
  IDT.SetGate(16, Cardinal(@IDT.ISR16), $08, $8E);
  IDT.SetGate(17, Cardinal(@IDT.ISR17), $08, $8E);
  IDT.SetGate(18, Cardinal(@IDT.ISR18), $08, $8E);
  IDT.SetGate(19, Cardinal(@IDT.ISR19), $08, $8E);
  IDT.SetGate(20, Cardinal(@IDT.ISR20), $08, $8E);
  IDT.SetGate(21, Cardinal(@IDT.ISR21), $08, $8E);
  IDT.SetGate(22, Cardinal(@IDT.ISR22), $08, $8E);
  IDT.SetGate(23, Cardinal(@IDT.ISR23), $08, $8E);
  IDT.SetGate(24, Cardinal(@IDT.ISR24), $08, $8E);
  IDT.SetGate(25, Cardinal(@IDT.ISR25), $08, $8E);
  IDT.SetGate(26, Cardinal(@IDT.ISR26), $08, $8E);
  IDT.SetGate(27, Cardinal(@IDT.ISR27), $08, $8E);
  IDT.SetGate(28, Cardinal(@IDT.ISR28), $08, $8E);
  IDT.SetGate(29, Cardinal(@IDT.ISR29), $08, $8E);
  IDT.SetGate(30, Cardinal(@IDT.ISR30), $08, $8E);
  IDT.SetGate(31, Cardinal(@IDT.ISR31), $08, $8E);

  IDT.SetGate($20, Cardinal(@IDT.IRQ0), $08, $8E);
  IDT.SetGate($21, Cardinal(@IDT.IRQ1), $08, $8E);
  IDT.SetGate($22, Cardinal(@IDT.IRQ2), $08, $8E);
  IDT.SetGate($23, Cardinal(@IDT.IRQ3), $08, $8E);
  IDT.SetGate($24, Cardinal(@IDT.IRQ4), $08, $8E);
  IDT.SetGate($25, Cardinal(@IDT.IRQ5), $08, $8E);
  IDT.SetGate($26, Cardinal(@IDT.IRQ6), $08, $8E);
  IDT.SetGate($27, Cardinal(@IDT.IRQ7), $08, $8E);
  IDT.SetGate($28, Cardinal(@IDT.IRQ8), $08, $8E);
  IDT.SetGate($29, Cardinal(@IDT.IRQ9), $08, $8E);
  IDT.SetGate($2A, Cardinal(@IDT.IRQ10), $08, $8E);
  IDT.SetGate($2B, Cardinal(@IDT.IRQ11), $08, $8E);
  IDT.SetGate($2C, Cardinal(@IDT.IRQ12), $08, $8E);
  IDT.SetGate($2D, Cardinal(@IDT.IRQ13), $08, $8E);
  IDT.SetGate($2E, Cardinal(@IDT.IRQ14), $08, $8E);
  IDT.SetGate($2F, Cardinal(@IDT.IRQ15), $08, $8E);

  IDT.SetGate($34, Cardinal(@IDT.IRQ20), $08, $8E);
  IDT.SetGate($35, Cardinal(@IDT.IRQ21), $08, $8E);

  IDT.SetGate($61, Cardinal(@IDT.IRQ97), $08, $8E);
  IDT.SetGate($69, Cardinal(@IDT.IRQ105), $08, $8E);
  IDT.SetGate($71, Cardinal(@IDT.IRQ113), $08, $8E);

  IDT.RemapIRQPM;
  IDT.RestoreIRQs;

  //Console.WriteStr(stOk);
  IRQ_ENABLE;
end;

// Install Handle
procedure InstallHandler(AIndex: Byte; AHandle: TIDTHandle); stdcall; [public, alias: 'k_IDT_InstallHandle'];
begin
  IDTHandles[AIndex]:= AHandle;
end;

procedure InstallPICHandler(AHandle: TPICHandle); stdcall; [public, alias: 'k_IDT_InstallPICHandle'];
begin
  PICHandle:= AHandle;
end;

// Remap the irq for pm.
procedure RemapIRQPM; stdcall; [public, alias: 'k_IDT_RemapIRQPM'];
begin
  // Remap the irq table.
  outb($20, $11); { write ICW1 to PICM, we are gonna write commands to PICM }
  outb($A0, $11); { write ICW1 to PICS, we are gonna write commands to PICS }
  outb($21, $20); { remap PICM to 0x20 (32 decimal) }
  outb($A1, $28); { remap PICS to 0x28 (40 decimal) }
  outb($21, $04); { IRQ2 -> connection to slave }
  outb($A1, $02);
  outb($21, $01); { write ICW4 to PICM, we are gonna write commands to PICM }
  outb($A1, $01); { write ICW4 to PICS, we are gonna write commands to PICS }
  outb($21, $0);  { enaIDT.RestoreIRQsble all IRQs on PICM }
  outb($A1, $0);  { enable all IRQs on PICS }
end;

// Remap the irq for rm.
procedure RemapIRQRM; stdcall; [public, alias: 'k_IDT_RemapIRQRM'];
begin
  // Remap the irq table.
  outb($20, $11);
  outb($A0, $11);
  outb($21, $00);
  outb($A1, $08);
  outb($21, $04);
  outb($A1, $02);
  outb($21, $01);
  outb($A1, $01);
  outb($21, $0);
  outb($A1, $0);
end;

// Restore IRQs
procedure RestoreIRQs; stdcall; [public, alias: 'k_IDT_RestoreIRQs'];
begin
  IDT.Flush(Cardinal(@IDTPtr));
end;

end.
