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
        EAX = 2: Param parser
            ESI: Pointer to null-terminate string.
            <-
            EAX: Param length
            ECX: Param array
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

uses
  kheap;

// Private

var
  FuncTable: array[0..2] of TIDTHandle;

procedure FTWriteStr(r: TRegisters); stdcall; public;
begin
  Write(PChar(r.esi));
end;

procedure FTWriteDec(r: TRegisters); stdcall; public;
begin
  Write(r.ecx);
end;

procedure FTParseArgs(r: TRegisters); stdcall; public;
var
  I, Len, Len2: Integer;
  IsFirst, IsQuote, IsSlash: Boolean;
  Argv: PCardinal;
  Arg, ArgPtr: PChar;
  Tmp: ShortString;
  C, CP: Char;
begin
  IRQEAXHave := 1;
  IRQECXHave := 1;
  IRQEAXValue := 0;
  IRQECXValue := 0;
  if r.esi <> 0 then
  begin
    Tmp := '';
    IsFirst := True;
    IsQuote := False;
    IsSlash := False;
    IRQEAXValue := 0;
    ArgPtr := PChar(r.esi);
    Argv := KHeap.Alloc(256 * SizeOf(Cardinal));
    Len := Length(ArgPtr);
    CP := ' ';
    for I := 0 to Len - 1 do
    begin
      C := ArgPtr[I];
      if IsFirst and (C = '"') then
      begin
        CP := '"';
        continue;
      end;
      if IsSlash and (C = CP) then
      begin
        Len2 := Length(Tmp);
        Arg := KHeap.Alloc(Len2 + 1);
        Move(Tmp[1], Arg[0], Len2);
        Arg[Len2 - 1] := #0;
        Tmp := '';
        Argv[IRQEAXValue] := Cardinal(Arg);
        Inc(IRQEAXValue);
        IsFirst := True;
        CP := ' ';
        IsSlaSh := False;
      end else
      if (not IsSLash) and (c = '\') then
      begin
        IsSlash := True;
      end else
      begin
        Tmp := Tmp + C;
        IsFirst := False;
        IsSlash := False;
      end;
    end;
    if Length(Tmp) > 0 then
    begin
      Len2 := Length(Tmp);
      Arg := KHeap.Alloc(Len2 + 1);
      Move(Tmp[1], Arg[0], Len2);
      Arg[Len2 - 1] := #0;
      Argv[IRQEAXValue] := Cardinal(Arg);
      Inc(IRQEAXValue);
    end;
    IRQECXValue := Cardinal(Argv);
  end;
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
  FuncTable[2] := @FTParseArgs;
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
