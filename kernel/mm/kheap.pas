{
    File:
        kheap.pas
    Description:
        Heap manager.
    License:
        General Public License (GPL)
}

unit kheap;

{$I KOS.INC}

interface

uses
  console;

type
  PHeapEntry = ^THeapEntry;
  THeapEntry = packed record
    Allocated: KernelCardinal;
    Size     : KernelCardinal;
    PID      : KernelCardinal;
    Address  : KernelCardinal;
  end;

var
  HeapEntries: array[0..199999] of THeapEntry;
  HeapEntryCount: Integer;

// Initialize first heap entry for the kernel and print init info
procedure Init; stdcall;

// Perform alloc/free for testing.
procedure Test; stdcall;
// Allocate a block of memory
function  Alloc(const ASize: KernelCardinal): Pointer; stdcall;
// Allocate a block of memory, aligned to 4KB
function  AllocAligned(const ASize: KernelCardinal): Pointer; stdcall;
{  Allocate a block of memory. If memory exists, we will delete it and move
   all its data to new block.
   TODO:
   - Need a better algorithm. }
function  ReAlloc(const APtr: Pointer; const ASize: KernelCardinal): Pointer; stdcall;
{  Allocate a block of memory, aligned to 4KB. If memory exists, we will delete it and move
   all its data to new block.
   TODO:
   - Need a better algorithm. }
function  ReAllocAligned(const APtr: Pointer; const ASize: KernelCardinal): Pointer; stdcall;

// Free memory
procedure Free(var APtr: Pointer); stdcall;
// Free all memory used by a process
procedure FreeAllMemory(const PID: PtrUInt); stdcall;
// Get memory block size
function  GetSize(const APtr: Pointer): KernelCardinal; stdcall;
// Set pointer's owner
procedure SetOwner(const APtr: Pointer; const AID: KernelCardinal); stdcall; inline;
// Calculate align for memory
function  CalcAlign(const AValue: KernelCardinal; const AAlign: KernelCardinal): KernelCardinal; stdcall; inline;

// ----- Debug functions -----

procedure Debug_PrintMemoryBlocks(const PID: Integer); stdcall;
function  Debug_PrintProcessMemoryUsage(const PID: PtrUInt): KernelCardinal; stdcall;

implementation

uses
  vmm, pmm, vbe,
  spinlock,
  schedule;

// ----- Helper functions -----

// Split a chunk into 2 smaller chunks
procedure SplitChunk(const Index: KernelCardinal; const ASize: KernelCardinal); public;
var
  PE, PENext: PHeapEntry;
  I: Integer;
begin
  Inc(HeapEntryCount);
  //for I := HeapEntryCount - 1 downto Index + 1 do
  //begin
  //  HeapEntries[I] := HeapEntries[I - 1];
  //end;
  Move(HeapEntries[Index], HeapEntries[Index + 1], (HeapEntryCount - Index - 1) * SizeOf(THeapEntry));
  PE := @HeapEntries[Index];
  PENext := @HeapEntries[Index + 1];
  PENext^.Size := PE^.Size - ASize;
  PENext^.Address := PE^.Address + ASize;
  PENext^.Allocated := 0;
  PE^.Size := ASize;
end;

// Merge 2 free chunks into 1.
procedure MergeChunk(const Index: KernelCardinal); public;
var
  PE, PENext: PHeapEntry;
  I: Integer;
begin
  PE := @HeapEntries[Index];
  PENext := @HeapEntries[Index + 1];
  PE^.Size := PE^.Size + PENext^.Size;
  PE^.Allocated := 0;
  Dec(HeapEntryCount);
  Move(HeapEntries[Index + 2], HeapEntries[Index + 1], (HeapEntryCount - Index) * SizeOf(THeapEntry));
end;

{ Find a useable chunk with base address and a given size using brute-force.
  TODO: Need a better algorithm. }
function  FindUseableChunk(const ASize: KernelCardinal; const IsPageAligned: Boolean): Pointer; stdcall; public;
var
  I, J: Integer;
  PE: PHeapEntry;
begin
  if IsPageAligned then
  begin
    for I := 0 to HeapEntryCount - 1 do
    begin
      PE := @HeapEntries[I];
      if (PE^.Allocated = 0) and (PE^.Address mod PAGE_SIZE = 0) and (PE^.Size >= ASize) then
      begin
        // Split in case the the entry has more space than required
        if PE^.Size > ASize then
        begin
          SplitChunk(I, ASize);
        end;
        if (not Inbetween) and (TaskCurrent <> nil) then
          PE^.PID := TaskCurrent^.PID
        else
          PE^.PID := 0;
        PE^.Allocated := 1;
        exit(Pointer(PE^.Address));
      end else
      if (PE^.Allocated = 0) and (PE^.Size >= ASize + PAGE_SIZE * 2) then
      begin
        // Split left
        J := I;
        if PAGE_SIZE - PE^.Address mod PAGE_SIZE > 0 then
        begin
          SplitChunk(I, PAGE_SIZE - PE^.Address mod PAGE_SIZE);
          Inc(J);
        end;
        // Split right
        SplitChunk(J, ASize);
        PE := @HeapEntries[J];
        if (not Inbetween) and (TaskCurrent <> nil) then
          PE^.PID := TaskCurrent^.PID
        else
          PE^.PID := 0;
        PE^.Allocated := 1;
        exit(Pointer(PE^.Address));
      end;
    end;
  end else
  begin
    for I := 0 to HeapEntryCount - 1 do
    begin
      PE := @HeapEntries[I];
      if (PE^.Allocated = 0) and (PE^.Size >= ASize) then
      begin
        // Split in case the the entry has more space than required
        if PE^.Size > ASize then
        begin
          SplitChunk(I, ASize);
        end;
        if (not Inbetween) and (TaskCurrent <> nil) then
          PE^.PID := TaskCurrent^.PID
        else
          PE^.PID := 0;
        PE^.Allocated := 1;
        exit(Pointer(PE^.Address));
      end;
    end;
  end;
  exit(nil);
end;

function FindEntryByAddress(Addr: Pointer): PHeapEntry; public; inline; stdcall;
var
  L, R, I: KernelCardinal;
  Cur: Pointer;
begin
  L := 0;
  R := HeapEntryCount - 1;
  while L <= R do
  begin
    I := L + (R - L) div 2;
    Cur := Pointer(HeapEntries[I].Address);
    if Addr = Cur then
    begin
      exit(@HeapEntries[I]);
    end;
    if Addr > Cur then
      L := I + 1
    else
      R := I - 1;
  end;
  exit(nil);
end;

// ----- Public functions -----

procedure SetOwner(const APtr: Pointer; const AID: KernelCardinal); stdcall; inline;
var
  PE: PHeapEntry;
begin
  PE := FindEntryByAddress(Pointer(APtr));
  if PE <> nil then
    PE^.PID := AID;
end;

procedure Init; stdcall; overload;
begin
  FillChar(HeapEntries[0], SizeOf(HeapEntries), 0);
  HeapEntries[0].Address := KERNEL_HEAP_START;
  HeapEntries[0].Size := MaxKernelHeapSize_;
  HeapEntryCount := 1;

  Console.WriteStr('Kernel heap started at 0x');
  Console.WriteHex(KERNEL_HEAP_START, 8);
  Console.WriteStr(#10#13);

  Console.WriteStr('Kernel heap size: ');
  Console.WriteDec(MaxKernelHeapSize_, 0);
  Console.WriteStr(' bytes'#10#13);
end;

procedure Test; stdcall;
var
  a,
  b,
  c,
  d,
  e,
  f,
  g,
  h,
  i: Pointer;
begin
  Console.SetFgColor(14);
  Console.WriteStr('Trying to allocate 4 memory chunks, each chunk has 8 bytes header... ');
  Console.SetFgColor(7);

  Console.WriteStr(#10#13);
  a:= KHeap.Alloc(8);
  Console.WriteStr('a: 0x');
  Console.WriteHex(KernelCardinal(a), 8);
  b:= KHeap.Alloc(8);
  Console.WriteStr(', b: 0x');
  Console.WriteHex(KernelCardinal(b), 8);
  c:= KHeap.Alloc(8);
  Console.WriteStr(', c: 0x');
  Console.WriteHex(KernelCardinal(c), 8);
  d:= KHeap.Alloc(8);
  Console.WriteStr(', d: 0x');
  Console.WriteHex(KernelCardinal(d), 8);

  Console.SetFgColor(14);
  Console.WriteStr(#10#13'Freeing chunk b and c... ');
  Console.SetFgColor(7);
  KHeap.Free(b);
  KHeap.Free(c);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Trying to allocate another 4-bytes chunk... ');
  Console.SetFgColor(7);
  e:= KHeap.Alloc(4);
  Console.WriteStr(#10#13);
  Console.WriteStr('e: 0x');
  Console.WriteHex(KernelCardinal(e), 8);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Trying to allocate another 10-bytes chunk... ');
  Console.SetFgColor(7);
  f:= KHeap.Alloc(10);
  Console.WriteStr(#10#13);
  Console.WriteStr('f: 0x');
  Console.WriteHex(KernelCardinal(f), 8);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Freeing all chunks... ');
  Console.SetFgColor(7);
  KHeap.Free(a);
  KHeap.Free(d);
  KHeap.Free(e);
  KHeap.Free(f);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Trying to allocate 128-bytes aligned chunks...');
  Console.SetFgColor(7);
  g:= KHeap.AllocAligned(128);
  Console.WriteStr(#10#13);
  Console.WriteStr('g: 0x');
  Console.WriteHex(KernelCardinal(g), 8);
  h:= KHeap.AllocAligned(128);
  Console.WriteStr(', h: 0x');
  Console.WriteHex(KernelCardinal(h), 8);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Freeing all chunks... ');
  Console.SetFgColor(7);
  KHeap.Free(g);
  KHeap.Free(h);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Trying to allocate another 4096-bytes chunk...');
  Console.SetFgColor(7);
  i:= KHeap.Alloc(4096);
  Console.WriteStr(#10#13);
  Console.WriteStr('i: 0x');
  Console.WriteHex(KernelCardinal(i), 8);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Freeing all chunks... ');
  Console.SetFgColor(7);
  KHeap.Free(i);
  Console.WriteStr(#10#13);
end;

function  Alloc(const ASize: KernelCardinal): Pointer; stdcall;
var
  p: Pointer;
begin
  Spinlock.Lock(PMM.SLock);
  p:= KHeap.FindUseableChunk(ASize, False);
  while p = nil do
  begin
    // Try to ask VMM to allocate new page if possible
    // ExpandHeap(GetHeapNode, ASize);
    // p:= KHeap.FindUseableChunk(GetHeapNode, ASize, 2);
    if IsGUI then
      VBE.ReturnToTextMode;
    Console.WriteStr('KHeap.Alloc: Not enough memory.');
    INFINITE_LOOP;
  end;
  Spinlock.Unlock(PMM.SLock);
  exit(p);
end;

function  ReAlloc(const APtr: Pointer; const ASize: KernelCardinal): Pointer; stdcall;
var
  size      : KernelCardinal;
  newP, oldP: Pointer;
begin
  oldP:= APtr;
  newP:= KHeap.Alloc(ASize);
  if oldP <> nil then
    size:= KHeap.GetSize(oldP)
  else
    size:= 0;
  if (oldP = nil) or (size = 0) then
    exit(newP);
  if size > ASize then
    size:= ASize;
  Move(oldP^, newP^, size);
  if oldP <> nil then
    KHeap.Free(oldP);
  exit(newP);
end;

function  ReAllocAligned(const APtr: Pointer; const ASize: KernelCardinal): Pointer; stdcall;
var
  size      : KernelCardinal;
  newP, oldP: Pointer;
begin
  oldP:= APtr;
  newP:= KHeap.AllocAligned(ASize);
  if oldP <> nil then
    size:= KHeap.GetSize(oldP)
  else
    size:= 0;
  if (oldP = nil) or (size = 0) then
    exit(newP);
  if size > ASize then
    size:= ASize;
  Move(oldP^, newP^, size);
  if oldP <> nil then
    KHeap.Free(oldP);
  exit(newP);
end;

function  AllocAligned(const ASize: KernelCardinal): Pointer; stdcall;
var
  p: Pointer;
begin
  Spinlock.Lock(PMM.SLock);
  p:= KHeap.FindUseableChunk(ASize, True);
  while p = nil do
  begin
    // Try to ask VMM to allocate new page if possible
    // ExpandHeap(GetHeapNode, ASize);
    // p:= KHeap.FindUseableChunk(GetHeapNode, ASize, PAGE_SIZE);
    if IsGUI then
      VBE.ReturnToTextMode;
    Console.WriteStr('KHeap.AllocAligned: Not enough memory.');
    INFINITE_LOOP;
  end;
  Spinlock.Unlock(PMM.SLock);
  exit(p);
end;

procedure FreeEntry(Index: KernelCardinal); stdcall;
var
  PE: PHeapEntry;
begin
  PE := @HeapEntries[Index];
  PE^.Allocated := 0;
  // Merge forward
  while (Index < HeapEntryCount - 1) and ((PE + 1)^.Allocated = 0)  do
    MergeChunk(Index);
  // Merge backward
  while (Index > 0) and ((PE - 1)^.Allocated = 0)  do
  begin
    Dec(Index);
    MergeChunk(Index);
    PE := PE - 1;
  end;
end;

procedure Free(var APtr: Pointer); stdcall;
var
  I, J: Integer;
  PE: PHeapEntry;
begin
  Spinlock.Lock(PMM.SLock);
  for I := 0 to HeapEntryCount - 1 do
  begin
    PE := @HeapEntries[I];
    if (Pointer(PE^.Address) = APtr) and (PE^.Allocated = 1) then
    begin
      FreeEntry(I);
      break;
    end;
  end;
  Spinlock.Unlock(PMM.SLock);
end;

procedure FreeAllMemory(const PID: PtrUInt); stdcall;
var
  I: Integer;
  PE: PHeapEntry;
begin
  if PID = 0 then
    exit;
  Spinlock.Lock(PMM.SLock);
  I := HeapEntryCount - 1;
  while I >= 0 do
  begin
    PE := @HeapEntries[I];
    if (PE^.PID = PID) and (PE^.Allocated = 1) then
    begin
      FreeEntry(I);
      I := HeapEntryCount;
    end;
    Dec(I);
  end;
  Spinlock.Unlock(PMM.SLock);
end;

function  GetSize(const APtr: Pointer): KernelCardinal; stdcall;
var
  I: Integer;
  PE: PHeapEntry;
begin
  Spinlock.Lock(PMM.SLock);
  PE := FindEntryByAddress(APtr);
  if PE <> nil then
  begin
    Spinlock.Unlock(PMM.SLock);
    exit(PE^.Size);
  end;
  Spinlock.Unlock(PMM.SLock);
  exit(0);
end;

// ----- Debug functions -----

procedure Debug_PrintMemoryBlocks(const PID: Integer); stdcall;
var
  i, j, count: Integer;
  PE: PHeapEntry;
  c: Char;
begin
  Console.SetFgColor(14);      // 8 12 12 8
  Console.WriteStr('#       Address     Size        Status  PID' + #10#13);
  Console.SetFgColor(7);
  Console.WriteStr('-------------------------------------------------' + #10#13);
  Count := 0;
  for I := 0 to HeapEntryCount - 1 do
  begin
    PE := @HeapEntries[I];
    if PID >= 0 then
    begin
      if (PID <> PE^.PID) or (PE^.Allocated = 0) then continue;
      Inc(Count);
      Console.WriteDec(Count, 0);
      Console.SetCursorPos(8, Console.GetCursorPosY);
      Console.WriteHex(PE^.Address, 8);
      Console.SetCursorPos(20, Console.GetCursorPosY);
      Console.WriteHex(PE^.Size, 8);
      Console.SetCursorPos(32, Console.GetCursorPosY);
      case PE^.Allocated of
        0: Console.WriteStr('Free');
        1:
          begin
            Console.WriteStr('Used');
            Console.SetCursorPos(40, Console.GetCursorPosY);
            case PE^.PID of
              0: Console.WriteStr('0 <Kernel>');
              else
                Write(PE^.PID);
            end;
          end;
      end;
      Console.WriteStr(#10#13);
    end else
    begin
      Inc(Count);
      Console.WriteDec(Count, 0);
      Console.SetCursorPos(8, Console.GetCursorPosY);
      Console.WriteHex(PE^.Address, 8);
      Console.SetCursorPos(20, Console.GetCursorPosY);
      Console.WriteHex(PE^.Size, 8);
      Console.SetCursorPos(32, Console.GetCursorPosY);
      case PE^.Allocated of
        0: Console.WriteStr('Free');
        1:
          begin
            Console.WriteStr('Used');
            Console.SetCursorPos(40, Console.GetCursorPosY);
            case PE^.PID of
              0: Console.WriteStr('0 <Kernel>');
              else
                Write(PE^.PID);
            end;
          end;
      end;
      Console.WriteStr(#10#13);
    end;
  end;
end;

function  Debug_PrintProcessMemoryUsage(const PID: PtrUInt): KernelCardinal; stdcall;
var
  Ret, I: KernelCardinal;
  PE: PHeapEntry;
begin
  Ret:= 0;
  for I := 0 to HeapEntryCount - 1 do
  begin
    PE := @HeapEntries[I];
    if (PE^.PID = PID) and (PE^.Allocated = 1) then
      Ret:= Ret + PE^.Size;
  end;
  exit(Ret);
end;

function  CalcAlign(const AValue: KernelCardinal; const AAlign: KernelCardinal): KernelCardinal; stdcall; inline;
begin
  if AValue < AAlign then
    CalcAlign:= AAlign
  else
    CalcAlign:= AValue + AAlign - AValue mod AAlign;
end;

end.
