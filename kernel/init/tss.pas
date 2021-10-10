{
    File:
        tss.pas
    Description:
        N/A.
    License:
        General Public License (GPL)
}

unit tss;

interface

type
  TTSSEntry = packed record
    PrevTss,
    esp0,
    ss0,
    esp1,
    ss1,
    esp2,
    ss2,
    cr3,
    eip,
    eflags,
    eax,
    ecx,
    edx,
    ebx,
    esp,
    ebp,
    esi,
    edi,
    es,
    cs,
    ss,
    ds,
    fs,
    gs,
    ldt: KernelCardinal;
    trap,
    iomap_base: Word;
  end;

var
  TSSEntry: TTSSEntry;

procedure Flush; stdcall; external name 'k_TSS_Flush';
procedure SetTSS(const Num: Integer); stdcall;
procedure SetTSSStack(const Stack: Pointer); stdcall;

implementation

uses
  gdt;

procedure SetTSS(const Num: Integer); stdcall;
var
  Base, Limit: KernelCardinal;
begin
  Base := KernelCardinal(@TSSEntry);
  Limit := Base + SizeOf(TTSSEntry);
  GDT.SetGate(Num, Base, Limit, $E9, $00);
  FillChar(TSSEntry, SizeOf(TTSSEntry), 0);
  TSSEntry.ss0 := $10;
end;

procedure SetTSSStack(const Stack: Pointer); stdcall;
begin
  TSSEntry.esp0 := KernelCardinal(Stack);
end;

end.