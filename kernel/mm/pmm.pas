{
    File:
        pmm.pas
    Description:
        Unit contains basic physics memory management. Useful when there's no
        heap management available.
    License:
        General Public License (GPL)
}

unit pmm;

{$I KOS.INC}

interface

uses
  console,
  spinlock;

const
  CACHE_SIZE = $10000 * 4 - 1; // 256KB of cache

var
  SLock: PSpinlock;
  MemCache: Pointer;

function  Alloc_Default(const ASize: KernelCardinal; const isAligned: Boolean): Pointer; stdcall;
// Allocate a memory (unaligned).
function  Alloc(const ASize: KernelCardinal): Pointer; stdcall;
// Allocate a memory (aligned).
function  AllocAligned(const ASize: KernelCardinal): Pointer; stdcall;
// Free a block of memory.
procedure Free(var APtr: Pointer); stdcall;
procedure Init; stdcall;

implementation

uses
  kheap, vmm;

function  Alloc_Default(const ASize: KernelCardinal; const isAligned: Boolean): Pointer; stdcall; inline;
var
  p: Pointer;
begin
  if not IsPaging then
  begin
    if isAligned and ((KernelCardinal(PlacementAddr) mod PAGE_SIZE) <> 0) then
    begin
      // Align the placement address
      p:= PlacementAddr;
      p:= Pointer((KernelCardinal(p) + (PAGE_SIZE shl 2)) - (KernelCardinal(p) mod PAGE_SIZE));
      PlacementAddr:= p;
    end;
    Alloc_Default:= PlacementAddr;
    PlacementAddr:= PlacementAddr + ASize;
  end
  else
  begin
    case isAligned of
      True:
        exit(KHeap.AllocAligned(ASize));
      False:
        exit(KHeap.Alloc(ASize));
    end;
  end;
end;

function  Alloc(const ASize: KernelCardinal): Pointer; stdcall;
begin
  exit(PMM.Alloc_Default(ASize, False));
end;

function  AllocAligned(const ASize: KernelCardinal): Pointer; stdcall;
begin
  exit(PMM.Alloc_Default(ASize, True));
end;

procedure Free(var APtr: Pointer); stdcall;
begin
  if IsPaging then
    KHeap.Free(APtr);
end;

procedure Init; stdcall;
begin
  // We create a spinlock in physical address...
  SLock:= PMM.Alloc(SizeOf(TSpinlock));
  IncDecLock:= PMM.Alloc(SizeOf(TSpinlock));
  // Cache size for kernel
  MemCache := PMM.AllocAligned(CACHE_SIZE);
  //Console.WriteStr('Installing PMM ... ');
  //Console.WriteStr(stOk);
end;

end.


