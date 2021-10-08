{
    File:
        int0x0e.pas
    Description:
        Faulting interrupt handler.
    License:
        General Public License (GPL)
}

unit int0x0e;

{$I KOS.INC}

interface

uses
  console,
  idt;

procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;

implementation

procedure Callback(r: TRegisters); stdcall;
var
  present,
  rw,
  us,
  reserved,
  id,
  faultAddr: Cardinal;
begin
  asm
    mov  eax,cr2
    mov  faultAddr,eax
  end ['eax'];

  present := not (r.err_code and 1);
  rw      := r.err_code and 2;
  us      := r.err_code and 4;
  reserved:= r.err_code and 8;
  id      := r.err_code and 16;

  Console.WriteStr('Faulting (');

  if Boolean(present) then
    Console.WriteStr(' present');
  if Boolean(rw) then
    Console.WriteStr(' read-only');
  if Boolean(us) then
    Console.WriteStr(' user-mode');
  if Boolean(reserved) then
    Console.WriteStr(' reserved');

  Console.WriteStr(' ) at 0x'); Console.WriteHex(faultAddr, 8);
  Console.WriteStr(#10#13);

  INFINITE_LOOP;
end;

procedure Init; stdcall;
var
  i: Cardinal;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing PFC (0x0E)... ');
  IDT.InstallHandler($0E, @Int0x0e.Callback);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
