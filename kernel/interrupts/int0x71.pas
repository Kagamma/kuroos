{
    File:
        int0x71.pas
    Description:
        Syscalls for miscs: console handling

    Usage:e
        EAX = 0: Write a string to the screen
            ESI: Pointer to null-terminate string.
        EAX = 1: Write a decimal number to the screen
            ECX: Number.
    License:
        General Public License (GPL)
}

unit int0x71;

{$I KOS.INC}

interface

uses
  console, sysutils,
  idt;

procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;

implementation

// Private

var
  FuncTable: array[0..1] of TIDTHandle;

procedure FTWriteStr(r: TRegisters); stdcall; public;
begin
  Write(PChar(r.esi));
end;

procedure FTWriteDec(r: TRegisters); stdcall; public;
begin
  Write(r.ecx);
end;

// Public

procedure Callback(r: TRegisters); stdcall;
begin
  FuncTable[r.eax](r);
end;

procedure Init; stdcall;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing Console Syscalls (0x71)... ');
  IDT.InstallHandler($71, @Int0x71.Callback);
  FuncTable[0] := @FTWriteStr;
  FuncTable[1] := @FTWriteDec;
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
