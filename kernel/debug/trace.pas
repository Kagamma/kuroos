unit trace;

{$I KOS.INC}

interface

uses
  console;

// Init debug information
procedure Init; stdcall;
// Print debug information based on address
procedure WriteStackTraceformation(const Addr: Cardinal); stdcall;

implementation

uses
  cdfs, ide, kheap;

var
  DebugAddresses: PCardinal;
  DebugNames: Pointer;
  DebugAddressesSize,
  DebugNamesSize: Cardinal;

procedure Init; stdcall;
begin
  Console.WriteStr('Loading debug information... ');
  DebugAddresses := CDFSObj^.Loader(IDE.FindDrive(True), 'kernel.1');
  DebugNames := CDFSObj^.Loader(IDE.FindDrive(True), 'kernel.2');
  DebugAddressesSize := KHeap.GetSize(DebugAddresses) div 4;
  DebugNamesSize := KHeap.GetSize(DebugNames);
  Console.WriteStr(stOK);
end;

procedure WriteStackTraceformation(const Addr: Cardinal); stdcall;
var
  I, J: Cardinal;
  Pos, Pos2: Integer;
  P: PByte;
begin
  Pos := -1;
  for I := 0 to DebugAddressesSize - 1 do
  begin
    if DebugAddresses[I] > Addr then
    begin
      Pos := I - 1;
      break;
    end;
  end;
  if Pos >= 0 then
  begin
    Pos2 := 0;
    P := DebugNames;
    for I := 0 to DebugNamesSize - 1 do
    begin
      if P^ = 0 then
      begin
        Inc(Pos2);
      end;
      if Pos2 = Pos then
      begin
        Inc(Pos2);
        for J := I to DebugNamesSize - 1 do
        begin
          Console.WriteChar(Char(P^));
          Inc(P);
          if P^ = 0 then
            exit;
        end;
      end;
      Inc(P);
    end;
  end;
end;

end.