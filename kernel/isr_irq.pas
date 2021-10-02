{
    File:
        isr_irq.pas
    Description:
        N/A.
    License:
        General Public License (GPL)
}

unit isr_irq;

{$I KOS.INC}

interface

uses
  console, idt;

procedure k_IDT_WriteRegisters(const r: TRegisters); stdcall;
procedure k_IDT_ISR_FaultHandler(r: TRegisters); cdecl;
procedure k_IDT_IRQ_FaultHandler(r: TRegisters); cdecl;
function  k_PIC_Handler(AStack: Cardinal): Cardinal; cdecl;

implementation

uses
  vga, vbe, schedule;

const
  ISR_ERRORCODE: array[0..15] of PChar =
    ('Divide by zero',
     'Debug',
     'Non-maskable Interrupt',
     'Breakpoint',
     'Overflow',
     'Bound Range Exceeded',
     'Invalid Opcode',
     'Device Not Available',
     'Double Fault',
     '',
     'Invalid TSS',
     'Segment Not Present',
     'Stack-Segment Fault',
     'General Protection Fault',
     'Page Fault',
     '');

// Print register information to the screen
procedure k_IDT_WriteRegisters(const r: TRegisters); stdcall;
var
  reg_cr0,
  reg_cr2,
  reg_cr3,
  reg_cr4: Cardinal;
begin
  asm
      mov eax,cr0
      mov reg_cr0,eax
      mov eax,cr2
      mov reg_cr2,eax
      mov eax,cr3
      mov reg_cr3,eax
      mov eax,cr4
      mov reg_cr4,eax
  end;

  Console.WriteStr(#10#13);
 // Console.WriteStr(('interrupt: 0x'); Console.WriteHex(r.int_no, 8);   Console.WriteStr((#10#13);
  Console.WriteStr(    'CS : 0x'); Console.WriteHex(r.cs , 8);
  Console.WriteStr('    DS : 0x'); Console.WriteHex(r.ds , 8);
  Console.WriteStr('    ES : 0x'); Console.WriteHex(r.es , 8);
  Console.WriteStr('    SS : 0x'); Console.WriteHex(r.ss , 8); Console.WriteStr(#10#13);

  Console.WriteStr(    'FS : 0x'); Console.WriteHex(r.fs , 8);
  Console.WriteStr('    GS : 0x'); Console.WriteHex(r.gs , 8);
  Console.WriteStr('    EIP: 0x'); Console.WriteHex(r.eip, 8);
  Console.WriteStr('    EF : 0x'); Console.WriteHex(r.eflags, 8); Console.WriteStr(#10#13);

  //Console.WriteStr(#10#13);
  //Console.WriteStr('GENERAL REGISTERS:'+#10#13);
  //Console.WriteStr('-----------------------'+#10#13);

  Console.WriteStr(    'EAX: 0x'); Console.WriteHex(r.eax, 8);
  Console.WriteStr('    EBX: 0x'); Console.WriteHex(r.ebx, 8);
  Console.WriteStr('    ECX: 0x'); Console.WriteHex(r.ecx, 8);
  Console.WriteStr('    EDX: 0x'); Console.WriteHex(r.edx, 8); Console.WriteStr(#10#13);

  Console.WriteStr(    'ESI: 0x'); Console.WriteHex(r.esi, 8);
  Console.WriteStr('    EDI: 0x'); Console.WriteHex(r.edi, 8);
  Console.WriteStr('    ESP: 0x'); Console.WriteHex(r.esp, 8);
  Console.WriteStr('    EBP: 0x'); Console.WriteHex(r.ebp, 8); Console.WriteStr(#10#13);

  //Console.WriteStr(#10#13);
  //Console.WriteStr('CONTROL REGISTERS:'+#10#13);
  //Console.WriteStr('-----------------------'+#10#13);

  Console.WriteStr(    'CR0: 0x'); Console.WriteHex(reg_cr0, 8);
  Console.WriteStr('    CR2: 0x'); Console.WriteHex(reg_cr2, 8);
  Console.WriteStr('    CR3: 0x'); Console.WriteHex(reg_cr3, 8);
  Console.WriteStr('    CR4: 0x'); Console.WriteHex(reg_cr4, 8); Console.WriteStr(#10#13);

 // Console.WriteStr('useresp: 0x'); Console.WriteHex(r.useresp, 8); Console.WriteStr(#10#13);
end;

procedure k_IDT_ISR_FaultHandler(r: TRegisters); cdecl; [public, alias: 'k_IDT_ISR_FaultHandler'];
var
  IDTHandle: TIDTHandle;
  lIsGUI   : Boolean;
  attrib   : Byte;
  i        : Integer;
begin
  // TODO:
  if (r.int_no < 32)  then
  begin
    lIsGUI:= IsGUI;
    if lIsGUI then
    begin
      VBE.ReturnToTextMode;
    end
    else
    begin
      Console.SaveState;
      VGA.SetMode(vga80x25x4);
    end;
    Console.SetFgColor(15);
    Console.SetBgColor(1);

    //Console.ClearScreen;
    attrib:= (1 shl 4) or (15 and $0F);
    for i:= 0 to (VGA.GetScreenWidth * 7)-1 do
      TEXTMODE_MEMORY[i]:= Word((attrib shl 8) or TEXTMODE_BLANK);
    Console.SetCursorPos(0, 0);
    //Console.WriteStr('Kernel Panic!'#10#13#10#13);

    Console.WriteStr('Exception ');
    Console.WriteDec(r.int_no, 0);
    Console.WriteStr(': ');
    if r.int_no < 16 then
      Console.WriteStr(ISR_ERRORCODE[r.int_no])
    else
      Console.WriteStr('UNKNOWN');
    Console.WriteStr(' | ');

    Console.WriteStr('Error Code: ');
    Console.WriteDec(r.err_code, 0);

    k_IDT_WriteRegisters(r);
    if TaskCurrent <> nil then
    begin
      Console.WriteStr('Current Task: ');
      if TaskCurrent^.PID = 0 then
        Console.WriteDec(TaskCurrent^.PPID)
      else
        Console.WriteDec(TaskCurrent^.PID);
      Console.WriteStr('[');
      Console.WriteStr(@TaskCurrent^.Name[1]);
      Console.WriteStr(']'#10#13);
    end;

    IDTHandle:= IDTHandles[r.int_no];
    if IDTHandle <> nil then
      IDTHandle(r)
    else
      INFINITE_LOOP;

    Console.LoadState;
    if lIsGUI then
    begin
      VBE.ReturnToGraphicsMode;
    end;
  end;
end;

procedure k_IDT_IRQ_FaultHandler(r: TRegisters); cdecl; [public, alias: 'k_IDT_IRQ_FaultHandler'];
var
  IDTHandle: TIDTHandle;
begin
  IDTHandle:= IDTHandles[r.int_no];
  if IDTHandle <> nil then
    IDTHandle(r);
  /// Reset the PICs.
  if r.int_no >= $8 then
    outb($A0, $20);
  outb($20, $20);
end;

function  k_PIC_Handler(AStack: Cardinal): Cardinal; cdecl; [public, alias: 'k_PIC_Handler'];
begin
  if PICHandle <> nil then
    k_PIC_Handler:= PICHandle(AStack)
  else
    k_PIC_Handler:= AStack;
end;

end.

