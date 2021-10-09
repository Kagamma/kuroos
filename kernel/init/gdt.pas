{
    File:
        gdt.pas
    Description:
        N/A.
    License:
        General Public License (GPL)
}

unit gdt;

{$I KOS.INC}

interface

uses
  console;

type
  TGDTEntry = packed record
    limit_low,           // The lower 16 bits of the limit.
    base_low: Word;      // The lower 16 bits of the base.
    base_middle,         // The next 8 bits of the base.
    access,              // Access flags, determine what ring this segment can be used in.
    granularity,
    base_high: Byte      // The last 8 bits of the base.
  end;
  PGDTEntry = ^TGDTEntry;

  TGDTPtr = packed record
    limit: Word;         // The upper 16 bits of all selector limits.
    base : Cardinal;     // The address of the first TGDTEntry struct.
  end;
  PGDTPtr = ^TGDTPtr;

var
  GDTEntries: array[0..6] of TGDTEntry;
  GDTPtr    : PGDTPtr = Pointer($7F00);

procedure Flush(AGDTPtr: Cardinal); stdcall; external name 'k_GDT_Flush';
// Set gate
procedure SetGate(AIndex: LongInt; ABase, ALimit: Cardinal; AAccess, AFlag: Byte); stdcall;
// Init table
procedure Init; stdcall;

implementation

// Set gate
procedure SetGate(AIndex: LongInt; ABase, ALimit: Cardinal; AAccess, AFlag: Byte); stdcall; inline;
begin
  GDTEntries[AIndex].base_low   := (ABase and $FFFF);
  GDTEntries[AIndex].base_middle:= (ABase shr 16) and $FF;
  GDTEntries[AIndex].base_high  := (ABase shr 24) and $FF;

  GDTEntries[AIndex].limit_low  := (ALimit and $FFFF);

  GDTEntries[AIndex].granularity:= (ALimit shr 16) and $0F;
  GDTEntries[AIndex].granularity:= GDTEntries[AIndex].granularity or ($F0 and AFlag);

  GDTEntries[AIndex].access     := AAccess;
end;

// Init table
procedure Init; stdcall; inline;
begin
  IRQ_DISABLE;
  //Console.WriteStr('Installing GDT... ');

  GDTPtr^.limit:= (SizeOf(TGDTEntry) * 7) - 1;
  GDTPtr^.base := Cardinal(@GDTEntries);

  GDT.SetGate(0, 0, 0, 0, $CF);           // Null segment
  GDT.SetGate(1, 0, $FFFFFFFF, $9A, $CF); // Code segment
  GDT.SetGate(2, 0, $FFFFFFFF, $92, $CF); // Data segment
  GDT.SetGate(3, 0, $FFFFFFFF, $FA, $CF); // User mode code segment
  GDT.SetGate(4, 0, $FFFFFFFF, $F2, $CF); // User mode data segment
  GDT.SetGate(5, 0, $FF, $9A, $8F); // Code segment (16 bit)
  GDT.SetGate(6, 0, $FF, $92, $8F); // Data segment (16 bit)

  GDT.Flush(Cardinal(GDTPtr));

  //Console.WriteStr(stOk);
  IRQ_ENABLE;
end;

end.
