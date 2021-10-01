{
    File:
        int0x71.pas
    Description:
        Syscalls for miscs: console handling

    Usage:
        AH = 0: Console
            AL = 1: Write a string to the screen
                ESI: Pointer to null-terminate string.
            AL = 2: Write a decimal number to the screen
                ECX: Number.
        AH = 1: Convert
            AL = 1: Convert number to string
                ECX: Number
                <-
                ESI: Pointer to string
            AL = 2: Convert string to number
                ESI: Pointer to string
                <-
                ECX: Number
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

// Public

procedure Callback(r: TRegisters); stdcall;
var
  r_ah,
  r_al: Byte;
begin
  r_ah:= (r.eax and $FF00) shr 8;
  r_al:= (r.eax and $FF);
  case r_ah of
    0:
      case r_al of
        1: // Print a null-terminated string
          Write(PChar(r.esi));
        2: // Print a decimal number
          Write(r.ecx);
      end;
  end;
end;

procedure Init; stdcall;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing Console Syscalls (0x71)... ');
  IDT.InstallHandler($71, @Int0x71.Callback);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
