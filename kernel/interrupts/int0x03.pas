{
    File:
        int0x03.pas
    Description:
        Hardware breakpoint interrupt handler.
    License:
        General Public License (GPL)
}

unit int0x03;

{$I KOS.INC}

interface

uses
  console,
  idt;

procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;

implementation

uses
  keyboard;

procedure Callback(r: TRegisters); stdcall;
var
  buf: TKeyBuffer;
begin
  Keyboard.ClearBuffer;
  // Console.WriteStr('Press any key to continue...');
  // IRQ_ENABLE;
  while Keyboard.GetLastKeyStroke = 0 do ;
  Keyboard.ClearBuffer;
end;

procedure Init; stdcall;
var
  i: Cardinal;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing Breakpoint handler (0x03)... ');
  IDT.InstallHandler($03, @Int0x03.Callback);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
