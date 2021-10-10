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
    ldt: Cardinal;
    trap,
    iomap_base: Word;
  end;

var
  TSSEntry: TTSSEntry;
  KernelStack: array[0..4096] of Byte;

procedure Flush; stdcall; external name 'k_TSS_Flush';
procedure SetTSS(const Num: Integer); stdcall;

implementation

uses
  gdt;

procedure SetTSS(const Num: Integer); stdcall;
var
  Base, Limit: Cardinal;
begin
  Base := Cardinal(@TSSEntry);
  Limit := Base + SizeOf(TTSSEntry);
  GDT.SetGate(Num, Base, Limit, $E9, $00);
  FillChar(TSSEntry, SizeOf(TTSSEntry), 0);
  TSSEntry.ss0 := $08;
  TSSEntry.esp0 := Cardinal(@KernelStack) + SizeOf(KernelStack) - 4;
  TSSEntry.cs := $0B;
  TSSEntry.ss := $13;
  TSSEntry.ds := $13;
  TSSEntry.es := $13;
  TSSEntry.fs := $13;
  TSSEntry.gs := $13;
end;

end.