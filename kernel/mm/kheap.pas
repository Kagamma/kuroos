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

const
  KERNEL_HEAP_MAGIC = $DEADC0DE;
  PROCESS_HEAP_SIZE = 4096 * 16;

type
  // 16-bytes heap header
  {PHeapNode = ^THeapNode;
  THeapNode = bitpacked record
    Magic     : Cardinal;
    Prev, Next: PHeapNode;
    Allocated : TBit1;
    Size      : TBit31;
  end;}
  PHeapNode = ^THeapNode;
  THeapNode = packed record
    _Pad1     : Cardinal;
    Magic     : Cardinal;
    Prev, Next: PHeapNode;
    Allocated : Cardinal;
    Size      : Cardinal;
    PID       : Cardinal;
    _Pad2     : Cardinal;
  end;

var
  FirstHeapNode_: PHeapNode;

// Initialize first heap node for the kernel and print init info
procedure Init; stdcall; overload;
// Initialize first heap node
procedure Init(const ALinearAddr: Pointer); stdcall; overload;

// Perform alloc/free for testing.
procedure Test; stdcall;
// Allocate a block of memory
function  Alloc(const ASize: Cardinal): Pointer; stdcall;
// Allocate a block of memory, aligned to 4KB
function  AllocAligned(const ASize: Cardinal): Pointer; stdcall;
// Allocate a block of memory, Custom align
function  AllocAlignedCustom(const ASize: Cardinal; const AAlign: Cardinal): Pointer; stdcall;
{  Allocate a block of memory. If memory exists, we will delete it and move
   all its data to new block.
   TODO:
   - Need a better algorithm. }
function  ReAlloc(const APtr: Pointer; const ASize: Cardinal): Pointer; stdcall;
{  Allocate a block of memory, aligned to 4KB. If memory exists, we will delete it and move
   all its data to new block.
   TODO:
   - Need a better algorithm. }
function  ReAllocAligned(const APtr: Pointer; const ASize: Cardinal): Pointer; stdcall;

// Free memory
procedure Free(var APtr: Pointer); stdcall;
// Free all memory used by a process
procedure FreeAllMemory(const PID: PtrUInt); stdcall;
// Get memory block size
function  GetSize(const APtr: Pointer): Cardinal; stdcall;
// Set pointer's owner
procedure SetOwner(const APtr: Pointer; const AID: Cardinal); stdcall; inline;
// Calculate align for memory
function  CalcAlign(const AValue: Cardinal; const AAlign: Cardinal): Cardinal; stdcall; inline;

// ----- Debug functions -----

procedure Debug_PrintMemoryBlocks; stdcall;
function  Debug_PrintProcessMemoryUsage(const PID: PtrUInt): Cardinal; stdcall;

implementation

uses
  vmm, pmm,
  spinlock,
  schedule;

// ----- Helper functions -----

// Get heap address
function GetHeapAddress: PHeapNode; public;
begin
  if TaskCurrent = nil then
    exit(FirstHeapNode_)
  else
    exit(TaskCurrent^.HeapAddr);
end;

// Split a chunk into 2 smaller chunks
procedure SplitChunk(const ANode: PHeapNode; const ASize: Cardinal); public;
var
  p: PHeapNode;
begin
  p            := PHeapNode(Cardinal(ANode) + SizeOf(THeapNode) + ASize);
  p^.Next      := ANode^.Next;
  p^.Prev      := ANode;
  if p^.Next <> nil then
    p^.Next^.Prev:= p;
  ANode^.Next  := p;
  p^.Magic     := KERNEL_HEAP_MAGIC;
  p^.Size      := ANode^.Size - ASize - SizeOf(THeapNode);
  p^.Allocated := 0;
  ANode^.Size  := ASize;
end;

// Merge 2 free chunks into 1 and return the 1st chunk.
function  MergeChunk(const ANode: PHeapNode): PHeapNode; public;
var
  p: PHeapNode;
begin
  p            := ANode^.Next;
  ANode^.Size  := ANode^.Size + p^.Size + SizeOf(THeapNode);
  ANode^.Next  := p^.Next;
  if p^.Next <> nil then
    p^.Next^.Prev:= ANode;

  // Erase 2nd chunk's node header.
  p^.Magic     := 0;
  p^.Size      := 0;

  exit(ANode);
end;

{ Find a useable chunk with base address and a given size using brute-force.
  TODO: Need a better algorithm. }
function  FindUseableChunk(const AStartAddr: Pointer; const ASize: Cardinal; const AAligned: Cardinal): Pointer; stdcall; public;
var
  p: PHeapNode;
  align,
  alignMargin: Cardinal;
begin
  p:= AStartAddr;
  alignMargin:= AAligned + SizeOf(THeapNode);
  while p <> nil do
  begin
    if (p^.Allocated = 0) and
       (p^.Size > ASize) then
    begin
      if (AAligned > 0) then
      begin
        if ((p^.size >= alignMargin) or
            (p^.Next^.size - p^.size > alignMargin)) then
        begin
          align:= (Cardinal(p) + SizeOf(THeapNode) shl 1) mod AAligned;
          if align > 0 then
          begin
            align:= AAligned - align;
            KHeap.SplitChunk(p, align);
            p^.Allocated:= 0;
            p:= Pointer(Cardinal(p) + SizeOf(THeapNode) + align);
          end;
        end
        else
        begin
          p:= p^.Next;
          continue;
        end;
      end;

      // If the hole is larger than necessary, we split this chunk into 2.
      if p^.Size - (ASize + SizeOf(THeapNode)) > 0 then
        KHeap.SplitChunk(p, ASize);
      p^.Allocated:= 1;
      // We need to know which process/thread this memory block belong to!
      if (not Inbetween) and (TaskCurrent <> nil) then
      begin
        p^.PID:= TaskCurrent^.PID;
      end
      else
        p^.PID:= 0;
        //
      exit(Pointer(Cardinal(p) + SizeOf(THeapNode)));
    end;
    p:= p^.Next;
  end;
  exit(nil);
end;

{ Expand the heap by allocating a new 4KB page and add the number to the last node's size }
procedure ExpandHeap(const AStartAddr: Pointer; Size: Cardinal); stdcall; public;
var
  p: PHeapNode;
  i: Cardinal;
begin
  Size := Size div PAGE_SIZE;
  p:= AStartAddr;
  while p^.Next <> nil do
    p := p^.Next;
  for i := 0 to Size do
  begin
    VMM.AllocPage(TaskCurrent^.Page, Cardinal(p) + p^.Size, 1);
    p^.Size := p^.Size + PAGE_SIZE;
  end;
end;

function GetHeapNode: PHeapNode; inline;
begin
  if TaskCurrent = nil then
    exit(FirstHeapNode_)
  else
    exit(TaskCurrent^.HeapAddr);
end;

// ----- Public functions -----

procedure SetOwner(const APtr: Pointer; const AID: Cardinal); stdcall; inline;
begin
  PHeapNode(APtr - SizeOf(THeapNode))^.PID:= AID;
end;

procedure Init; stdcall; overload;
begin
  FirstHeapNode_:= PHeapNode(KERNEL_HEAP_START);
  KHeap.Init(FirstHeapNode_);

  Console.WriteStr('Kernel heap started at 0x');
  Console.WriteHex(Cardinal(FirstHeapNode_), 8);
  Console.WriteStr(#10#13);

  Console.WriteStr('Kernel heap size: ');
  Console.WriteDec(MaxKernelHeapSize_, 0);
  Console.WriteStr(' bytes'#10#13);
end;

procedure Init(const ALinearAddr: Pointer); stdcall; overload;
var
  heapNode: PHeapNode;
begin
  // Now we perform heap allocation.
  // We will map all heap memory to a single block and mark that block as unallocated;
  heapNode           := ALinearAddr;
  heapNode^.Magic    := KERNEL_HEAP_MAGIC;
  heapNode^.Prev     := nil;
  heapNode^.Next     := nil;
  heapNode^.Allocated:= 0;
  heapNode^.Size     := MaxKernelHeapSize_ - SizeOf(THeapNode);
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
  Console.WriteStr('Trying to allocate 4 memory chunks, each chunk has 8 bytes+16 bytes header... ');
  Console.SetFgColor(7);

  Console.WriteStr(#10#13);
  a:= KHeap.Alloc(8);
  Console.WriteStr('a: 0x');
  Console.WriteHex(Cardinal(a), 8);
  b:= KHeap.Alloc(8);
  Console.WriteStr(', b: 0x');
  Console.WriteHex(Cardinal(b), 8);
  c:= KHeap.Alloc(8);
  Console.WriteStr(', c: 0x');
  Console.WriteHex(Cardinal(c), 8);
  d:= KHeap.Alloc(8);
  Console.WriteStr(', d: 0x');
  Console.WriteHex(Cardinal(d), 8);

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
  Console.WriteHex(Cardinal(e), 8);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Trying to allocate another 10-bytes chunk... ');
  Console.SetFgColor(7);
  f:= KHeap.Alloc(10);
  Console.WriteStr(#10#13);
  Console.WriteStr('f: 0x');
  Console.WriteHex(Cardinal(f), 8);
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
  Console.WriteHex(Cardinal(g), 8);
  h:= KHeap.AllocAligned(128);
  Console.WriteStr(', h: 0x');
  Console.WriteHex(Cardinal(h), 8);
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
  Console.WriteHex(Cardinal(i), 8);
  Console.WriteStr(#10#13);

  Console.SetFgColor(14);
  Console.WriteStr('Freeing all chunks... ');
  Console.SetFgColor(7);
  KHeap.Free(i);
  Console.WriteStr(#10#13);
end;

function  Alloc(const ASize: Cardinal): Pointer; stdcall;
var
  p: Pointer;
begin
  Spinlock.Lock(PMM.SLock);
  p:= KHeap.FindUseableChunk(GetHeapNode, ASize, 2);
  while p = nil do
  begin
    // Try to ask VMM to allocate new page if possible
    ExpandHeap(GetHeapNode, ASize);
    p:= KHeap.FindUseableChunk(GetHeapNode, ASize, 2);
    // Console.WriteStr('KHeap.Alloc: Not enough memory!');
    // INFINITE_LOOP;
  end;
  Spinlock.Unlock(PMM.SLock);
  exit(p);
end;

function  ReAlloc(const APtr: Pointer; const ASize: Cardinal): Pointer; stdcall;
var
  size      : Cardinal;
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

function  ReAllocAligned(const APtr: Pointer; const ASize: Cardinal): Pointer; stdcall;
var
  size      : Cardinal;
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

function  AllocAligned(const ASize: Cardinal): Pointer; stdcall;
var
  p: Pointer;
begin
  Spinlock.Lock(PMM.SLock);
  p:= KHeap.FindUseableChunk(GetHeapNode, ASize, PAGE_SIZE);
  while p = nil do
  begin
    // Try to ask VMM to allocate new page if possible
    ExpandHeap(GetHeapNode, ASize);
    p:= KHeap.FindUseableChunk(GetHeapNode, ASize, PAGE_SIZE);
    // Console.WriteStr('KHeap.AllocAligned: Not enough memory!');
    // INFINITE_LOOP;
  end;
  Spinlock.Unlock(PMM.SLock);
  exit(p);
end;

function  AllocAlignedCustom(const ASize: Cardinal; const AAlign: Cardinal): Pointer; stdcall;
var
  p: Pointer;
begin
  Spinlock.Lock(PMM.SLock);
  p:= KHeap.FindUseableChunk(GetHeapNode, ASize, AAlign);
  while p = nil do
  begin
    // Try to ask VMM to allocate new page if possible
    ExpandHeap(GetHeapNode, ASize);
    p:= KHeap.FindUseableChunk(GetHeapNode, ASize, AAlign);
    // Console.WriteStr('KHeap.AllocAlignedCustom: Not enough memory!');
    // INFINITE_LOOP;
  end;
  Spinlock.Unlock(PMM.SLock);
  exit(p);
end;

procedure Free(var APtr: Pointer); stdcall;
var
  p: PHeapNode;
begin
  Spinlock.Lock(PMM.SLock);
  p:= PHeapNode(APtr - SizeOf(THeapNode));

  if p^.Magic <> KERNEL_HEAP_MAGIC then
    exit;
  p^.Allocated:= 0;

  // MoveP forward to merge free chunks
  while (p^.Next <> nil) and (p^.Next^.Magic = KERNEL_HEAP_MAGIC) and (p^.Next^.Allocated = 0) do
  begin
    //Console.WriteStr(#10#13 + 'Merging forward: 0x');
    //Console.WriteHex(Cardinal(p^.Next), 8);
    p:= KHeap.MergeChunk(p);
  end;
  // MoveP backward to merge free chunks
  while (p^.Prev <> nil) and (p^.Prev^.Magic = KERNEL_HEAP_MAGIC) and (p^.Prev^.Allocated = 0) do
  begin
    //Console.WriteStr(#10#13 + 'Merging backward: 0x');
    //Console.WriteHex(Cardinal(p^.Prev), 8);
    p:= KHeap.MergeChunk(p^.Prev);
  end;
  APtr:= nil;
  Spinlock.Unlock(PMM.SLock);
end;

procedure FreeAllMemory(const PID: PtrUInt); stdcall;
var
  p: PHeapNode;
  m: Pointer;
begin
  if PID = 0 then
    exit;
  p:= FirstHeapNode_;
  while p <> nil do
  begin
    if (p^.PID = PID) and (p^.Allocated = 1) then
    begin
      m:= Pointer(p) + SizeOf(THeapNode);
      p:= p^.Next;
      Free(m);
    end
    else
      p:= p^.Next;
  end;
end;

function  GetSize(const APtr: Pointer): Cardinal; stdcall;
var
  p: PHeapNode;
begin
  p:= PHeapNode(APtr - SizeOf(THeapNode));
  if p^.Magic = KERNEL_HEAP_MAGIC then
    exit(p^.Size)
  else
    exit(0);
end;

// ----- Debug functions -----

procedure Debug_PrintMemoryBlocks; stdcall;
var
  i, j: Integer;
  p: PHeapNode;
  c: Char;
begin
  Console.SetFgColor(14);       // 12       // 24   // 32
  Console.WriteStr('Address     Size        Status  PID' + #10#13);
  Console.SetFgColor(7);
  Console.WriteStr('--------------------------------------' + #10#13);
  p:= FirstHeapNode_;
  while p <> nil do
  begin
    Console.WriteHex(Cardinal(p) + SizeOf(THeapNode), 8);
    Console.SetCursorPos(12, Console.GetCursorPosY);
    Console.WriteHex(p^.Size, 8);
    Console.SetCursorPos(24, Console.GetCursorPosY);
    case p^.Allocated of
      0: Console.WriteStr('Free');
      1:
        begin
          Console.WriteStr('Used');
          Console.SetCursorPos(32, Console.GetCursorPosY);
          case p^.PID of
            0: Console.WriteStr('Kernel');
            else
              Write(p^.PID);
          end;
        end;
    end;
    Console.WriteStr(#10#13);
    {if (p^.Allocated = 1) and (p^.Size <= 80) and (p^.Size > 0) then
    begin
      Console.SetFgColor(7);
      for j:= 0 to p^.Size-1 do
      begin
        c:= Char((Pointer(p) + SizeOf(THeapNode) + j)^);
        if Byte(c) in [32..127] then
          Console.WriteChar(c)
        else
          Console.WriteChar('?');
      end;
      Console.WriteStr(#10#13);
    end; }
    p:= p^.Next;
  end;
end;

function  Debug_PrintProcessMemoryUsage(const PID: PtrUInt): Cardinal; stdcall;
var
  Ret: Cardinal;
  p: PHeapNode;
begin
  Ret:= 0;
  p:= GetHeapNode;
  while p <> nil do
  begin
    if (p^.PID = PID) and (p^.Allocated = 1) then
      Ret:= Ret + p^.Size;
    p:= p^.Next;
  end;
  exit(Ret);
end;

function  CalcAlign(const AValue: Cardinal; const AAlign: Cardinal): Cardinal; stdcall; inline;
begin
  if AValue < AAlign then
    CalcAlign:= AAlign
  else
    CalcAlign:= AValue + AAlign - AValue mod AAlign;
end;

end.
