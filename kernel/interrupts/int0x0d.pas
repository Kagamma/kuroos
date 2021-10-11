{
    File:
        int0x0d.pas
    Description:
        GPF interrupt handler.
    License:
        General Public License (GPL)
}

unit int0x0d;

{$I KOS.INC}

interface

uses
  console,
  idt;

procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;

implementation

uses
  schedule;

procedure Callback(r: TRegisters); stdcall;
begin
  if (TaskCurrent <> nil) and (TaskCurrent^.PID <> 1) then
  begin
    WriteStr('Killing process... ');
    KillProcess(TaskCurrent^.PID);
    WriteStr(stOk);
    IRQ_ENABLE;
  end else
  begin
    IRQ_DISABLE;
  end;
  INFINITE_LOOP;
end;

procedure Init; stdcall;
var
  i: Cardinal;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing GPF (0x0D)... ');
  IDT.InstallHandler($0D, @Int0x0d.Callback);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
