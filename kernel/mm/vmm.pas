{
    File:
        vmm.pas
    Description:
        Virtual Memory Manager.
    License:
        General Public License (GPL)
}

unit vmm;

{$I KOS.INC}

interface

uses
  mboot,
  console;

const
  KERNEL_HEAP_START  = $80000000;
  KERNEL_HEAP_END    = $DE000000;
  PAGE_MEMORY_BLOCK  = $400000;
  KERNEL_SIZE        = 1024 * 1024 * 8;
  MINIMAL_SIZE       = 1024 * 1024 * 4;
  FIXED_PAGETABLE_SIZE = 768;

type
  TPageTableEntry = bitpacked record
    Present, RWAble, UserMode, WriteThrough,
    NotCacheable, Accessed, Dirty, AttrIndex,
    Global    : TBit1;
    Avail     : TBit3;
    FrameAddr : TBit20;
  end;
  PPageTableEntry = ^TPageTableEntry;

  TPageDirEntry = bitpacked record
    Present, RWAble, UserMode, WriteThrough,
    NotCacheable, Accessed, Reserved, PageSize,
    Global    : TBit1;
    Avail     : TBit3;
    TableAddr : TBit20;
  end;
  PPageDirEntry = ^TPageDirEntry;

  TPageTable = packed record
    Entries: array[0..1023] of TPageTableEntry;
  end;
  PPageTable = ^TPageTable;

  TPageDir = packed record
    Entries: array[0..1023] of TPageDirEntry;
  end;
  PPageDir = ^TPageDir;

  TPageStruct = packed record
    Directory : TPageDir;
    PhysAddr  : Cardinal;
  end;
  PPageStruct = ^TPageStruct;

var
  // The kernel's page directory.
  KernelPageStruct_ : PPageStruct;
  // The current page directory.
  CurrentPageDir_   : PPageDir;
  // Max heap
  MaxKernelHeapSize_: Cardinal;
  // Keep track allocated frames
  Frames: array[0..1024*1024 div 32 - 1] of Cardinal;
  // Big ass array to keep track the allocated PageTable
  PageTables: PPageTable;
  PageTableTracks: array[0..FIXED_PAGETABLE_SIZE div 32 - 1] of Cardinal;


function IsFixedPageTable(APageFrame: Cardinal): Boolean;
procedure SetFrame(AFrames: PCardinal; Addr: Cardinal); stdcall;
function  GetFrame(AFrames: PCardinal; Addr: Cardinal): Cardinal; stdcall;
procedure ClearFrame(AFrames: PCardinal; Addr: Cardinal); stdcall;
// Purge all allocated frames from a task
procedure PurgeFramesFromTask(AFrames: PCardinal); stdcall;
function  FindFirstFreeFrame(AFrames: PCardinal): Cardinal; stdcall;
procedure DisablePageDir;
procedure EnablePageDir(APageDir: PPageDir);
procedure SwitchPageDir(APageDir: PPageDir);
// Create a new empty page table, ignore if page table exists
function CreatePageTable(APageStruct: PPageStruct; AVirtualAddr: Cardinal; RWAble: TBit1): PPageTable; stdcall;
// Fill the page table with pages
procedure FillPageTable(PageTable: PPageTable; APhysicAddr: Cardinal; RWAble: TBit1); stdcall;
// Alloc page table
function AllocPageTable: PPageTable; stdcall;
// Free page table
procedure FreePageTable(PageTable: PPageTable); stdcall;
// Ask for a new empty page for the next virtual address
function AllocPage(APageStruct: PPageStruct; AVirtualAddr: Cardinal; RWAble: TBit1): PPageTableEntry; stdcall; overload;
// Ask for a new empty page for the next virtual address, with custom physic address
function AllocPage(APageStruct: PPageStruct; AVirtualAddr, APhysicAddr: Cardinal; RWAble: TBit1): PPageTableEntry; stdcall; overload;
function  CreatePageDirectory: Pointer; stdcall;
// Perform mapping kernel to virtual memory
procedure Init; stdcall;

implementation

uses
  pic,
  pmm,
  vbe,
  schedule,
  spinlock;

var
  NumFrames: Cardinal;
  SLock: PSpinlock;

function  GetIndex(AValue: Cardinal): Cardinal; inline;
begin
  GetIndex:= AValue div 32;
end;

function  GetOffset(AValue: Cardinal): Cardinal; inline;
begin
  GetOffset:= AValue mod 32;
end;

function IsFixedPageTable(APageFrame: Cardinal): Boolean;
var
  APhysAddr: Cardinal;
begin
  APageFrame := APageFrame * PAGE_SIZE;
  if (APhysAddr >= Cardinal(@PageTables[0])) and
    (APhysAddr + SizeOf(TPageTable) <= Cardinal(@PageTables[FIXED_PAGETABLE_SIZE-1])) then
    exit(true);
  exit(false);
end;

procedure SetFrame(AFrames: PCardinal; Addr: Cardinal); stdcall;
var
  frame,
  index,
  offset: Cardinal;
begin
  frame := Addr div PAGE_SIZE;
  index := GetIndex(frame);
  offset:= GetOffset(frame);
  AFrames[index]:= AFrames[index] or (1 shl offset);
end;

function  GetFrame(AFrames: PCardinal; Addr: Cardinal): Cardinal; stdcall;
var
  frame,
  index,
  offset: Cardinal;
begin
  frame := Addr div PAGE_SIZE;
  index := GetIndex(frame);
  offset:= GetOffset(frame);
  exit((AFrames[index] and (1 shl offset)) shr offset);
end;

procedure ClearFrame(AFrames: PCardinal; Addr: Cardinal); stdcall;
var
  frame,
  index,
  offset: Cardinal;
begin
  frame := Addr div PAGE_SIZE;
  index := GetIndex(frame);
  offset:= GetOffset(frame);
  AFrames[index]:= AFrames[index] and NOT (1 shl offset);
end;

function  FindFirstFreeFrame(AFrames: PCardinal): Cardinal; stdcall;
var
  i, j, line: Cardinal;
begin
  for j:= 0 to GetIndex(NumFrames) div 32 - 1 do
  begin
    if AFrames[j] <> $FFFFFFFF then
    begin
      for i:= 0 to 31 do
      begin
        line:= $1 shl i;
        if (AFrames[j] and line) = 0 then
          exit(j*32 + i);
      end;
    end;
  end;
  // TODO: Try to collect free memory from processes
  // TODO: Page out to external device to free memory
  if IsGUI then
    VBE.ReturnToTextMode;
  IRQ_DISABLE;
  Console.WriteStr('Not enough memory.');
  INFINITE_LOOP;
end;

procedure PurgeFramesFromTask(AFrames: PCardinal); stdcall;
var
  i, j, line: Cardinal;
begin
  for j:= 0 to GetIndex(NumFrames) div 32 - 1 do
  begin
    if AFrames[j] <> $FFFFFFFF then
    begin
      for i:= 0 to 31 do
      begin
        line:= $1 shl i;
        if (AFrames[j] and line) <> 0 then
          ClearFrame(@Frames[0], (j*32 + i) * PAGE_SIZE);
      end;
    end;
  end;
end;

procedure SetTrack(Ind: Cardinal); stdcall;
var
  index,
  offset: Cardinal;
begin
  index := GetIndex(Ind);
  offset:= GetOffset(Ind);
  PageTableTracks[index]:= PageTableTracks[index] or (1 shl offset);
end;

function  GetTrack(Ind: Cardinal): Cardinal; stdcall;
var
  index,
  offset: Cardinal;
begin
  index := GetIndex(Ind);
  offset:= GetOffset(Ind);
  exit((PageTableTracks[index] and (1 shl offset)) shr offset);
end;

procedure ClearTrack(Ind: Cardinal); stdcall;
var
  index,
  offset: Cardinal;
begin
  index := GetIndex(Ind);
  offset:= GetOffset(Ind);
  PageTableTracks[index]:= PageTableTracks[index] and NOT (1 shl offset);
end;

function  FindFirstTrack: Cardinal; stdcall;
var
  i, j, line: Cardinal;
begin
  for j:= 0 to GetIndex(Length(PageTableTracks)) - 1 do
  begin
    if PageTableTracks[j] <> $FFFFFFFF then
    begin
      for i:= 0 to 31 do
      begin
        line:= $1 shl i;
        if (PageTableTracks[j] and line) = 0 then
          exit(j*32 + i);
      end;
    end;
  end;
  Console.WriteStr('Cannot allocate new Page.');
  INFINITE_LOOP;
end;

procedure DisablePageDir;
begin
  asm
      mov  eax,cr0
      and  eax,$7FFFFFFF     // Set the paging bit in CR0 to 0.
      mov  cr0,eax
  end;
end;

procedure EnablePageDir(APageDir: PPageDir);
begin
  CurrentPageDir_:= APageDir;
  asm
      mov  eax,APageDir
      mov  cr3,eax
      mov  eax,cr0
      or   eax,$80000000     // Set the paging bit in CR0 to 1.
      mov  cr0,eax
  end;
end;

procedure SwitchPageDir(APageDir: PPageDir);
begin
  CurrentPageDir_:= APageDir;
  asm
      mov  eax,APageDir
      mov  cr3,eax
  end;
end;

function  CreatePageTable(APageStruct: PPageStruct; AVirtualAddr: Cardinal; RWAble: TBit1): PPageTable; stdcall;
var
  Addr,
  i        : Cardinal;
  PageTable: PPageTable;
begin
  Spinlock.Lock(SLock);
  // If there's exist a table on the heap then we will free it
  if IsPaging and
    (APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr <> 0) then
  begin
    PageTable := PPageTable(APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr * PAGE_SIZE);
    Spinlock.Unlock(SLock);
    exit(PageTable);
    Addr:= APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr * PAGE_SIZE;
    if Addr >= KERNEL_SIZE then
      PMM.Free(Pointer(Addr));
  end;

  PageTable:= PMM.AllocAligned(SizeOf(TPageTable));
  FillChar(PageTable^, SizeOf(TPageTable), 0);

  APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].Present  := 1;
  APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].RWAble   := RWAble;
  APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].UserMode := 0;
  if IsPaging then
    Addr:= (Cardinal(PageTable) - KERNEL_HEAP_START + KERNEL_SIZE) div PAGE_SIZE
  else
    Addr:= Cardinal(PageTable) div PAGE_SIZE;
  APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr:= Addr;
  Spinlock.Unlock(SLock);
  exit(PageTable);
end;

procedure FillPageTable(PageTable: PPageTable; APhysicAddr: Cardinal; RWAble: TBit1); stdcall;
var
  i: Cardinal;
begin
  Spinlock.Lock(SLock);
  for i:= 0 to 1023 do
  begin
    // For now we treat everything as kernel space
    PageTable^.Entries[i].Present  := 1;
    PageTable^.Entries[i].RWAble   := RWAble;
    PageTable^.Entries[i].UserMode := 0;
    PageTable^.Entries[i].FrameAddr:= APhysicAddr div PAGE_SIZE;
    SetFrame(@Frames[0], APhysicAddr);
    Inc(APhysicAddr, PAGE_SIZE);
  end;
  Spinlock.Unlock(SLock);
end;

function AllocPageTable: PPageTable; stdcall;
var
  i: Integer;
begin
  i := FindFirstTrack;
  SetTrack(i);
  exit(@PageTables[i]);
end;

procedure FreePageTable(PageTable: PPageTable); stdcall;
var
  i: Integer;
begin
  for i := 0 to FIXED_PAGETABLE_SIZE-1 do
  begin
    if PageTable = @PageTables[i] then
    begin
      ClearTrack(i);
      break;
    end;
  end;
end;

function AllocPage(APageStruct: PPageStruct; AVirtualAddr: Cardinal; RWAble: TBit1): PPageTableEntry; stdcall;
var
  i: Integer;
  PageTable: PPageTable;
  Page: PPageTableEntry;
  Frame: Cardinal;
begin
  Spinlock.Lock(SLock);
  // We first look for a free 4KB memory block
  Frame := FindFirstFreeFrame(@Frames[0]);
  // Mark the frame as used
  SetFrame(@Frames[0], Frame * PAGE_SIZE);
  // Now we get the page table. If No table found, create it.
  if APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr <> 0 then
    PageTable := PPageTable(APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr * PAGE_SIZE)
  else
  begin
    // Allocate memory here may cause problem, cuz the one ask for it maybe the alloc itself
    // We use our big ass array for it instead
    PageTable:= AllocPageTable;
    FillChar(PageTable^, SizeOf(TPageTable), 0);
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].Present  := 1;
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].RWAble   := RWAble;
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].UserMode := 0;
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr:= Cardinal(PageTable) div PAGE_SIZE;
  end;
  // Now we look for our page table entry
  Page := @PageTable^.Entries[AVirtualAddr mod PAGE_MEMORY_BLOCK div PAGE_SIZE];
  Page^.Present  := 1;
  Page^.RWAble   := RWAble;
  Page^.UserMode := 0;
  Page^.FrameAddr:= Frame;
  Spinlock.Unlock(SLock);
  exit(Page);
end;

function AllocPage(APageStruct: PPageStruct; AVirtualAddr, APhysicAddr: Cardinal; RWAble: TBit1): PPageTableEntry; stdcall;
var
  i: Integer;
  PageTable: PPageTable;
  Page: PPageTableEntry;
begin
  Spinlock.Lock(SLock);
  // Now we get the page table. If No table found, create it.
  if APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr <> 0 then
    PageTable := PPageTable(APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr * PAGE_SIZE)
  else
  begin
    // Allocate memory here may cause problem, cuz the one ask for it maybe the alloc itself
    // We use our big ass array for it instead
    PageTable:= AllocPageTable;
    FillChar(PageTable^, SizeOf(TPageTable), 0);
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].Present  := 1;
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].RWAble   := RWAble;
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].UserMode := 0;
    APageStruct^.Directory.Entries[AVirtualAddr div PAGE_MEMORY_BLOCK].TableAddr:= Cardinal(PageTable) div PAGE_SIZE;
  end;
  // Now we look for our page table entry
  Page := @PageTable^.Entries[AVirtualAddr mod PAGE_MEMORY_BLOCK div PAGE_SIZE];
  Page^.Present  := 1;
  Page^.RWAble   := RWAble;
  Page^.UserMode := 0;
  Page^.FrameAddr:= APhysicAddr div PAGE_SIZE;
  Spinlock.Unlock(SLock);
  exit(Page);
end;

function  CreatePageDirectory: Pointer; stdcall;
var
  p: PPageStruct;
begin
  Spinlock.Lock(SLock);
  p:= PPageStruct(PMM.AllocAligned(SizeOf(TPageStruct)));
  FillChar(p^, SizeOf(TPageStruct), 0);
  if IsPaging then
  begin
    p^.PhysAddr:= Cardinal(@p^.Directory) - KERNEL_HEAP_START + KERNEL_SIZE;
  end
  else
    p^.PhysAddr:= Cardinal(@p^.Directory);
  Spinlock.Unlock(SLock);
  exit(p);
end;

procedure Init; stdcall;
var
  i,
  addr,
  KernelFrameCount: Cardinal;
  KernelFrames    : PCardinal;
  PageTable: PPageTable;
begin
  Console.WriteStr('Enabling Paging... ');
  SLock := Spinlock.Create;
  NumFrames := GlobalMB^.mem_upper * 1024;
  // Clear the frames
  FillChar(Frames[0], Length(Frames), 0);
  // Clear the PageTableTracker
  FillChar(PageTableTracks[0], Length(PageTableTracks), 0);
  // Alloc & Clear the PageTableTracker
  PageTables := PMM.AllocAligned(SizeOf(TPageTable) * FIXED_PAGETABLE_SIZE);
  FillChar(PageTables^, SizeOf(TPageTable) * FIXED_PAGETABLE_SIZE, 0);

  // Let's make a page directory.
  KernelPageStruct_:= VMM.CreatePageDirectory;
  KernelPageStruct_^.PhysAddr:= Cardinal(KernelPageStruct_);

  if GlobalMB^.mem_upper * 1024 < KERNEL_SIZE + MINIMAL_SIZE then
  begin
    Console.WriteStr('Not enough memory. Need at least ');
    Console.WriteDec(KERNEL_SIZE * 2 div 1024 div 1024);
    Console.WriteStr('MB RAM');
    INFINITE_LOOP;
  end;

  // Map the first 12MB physical memory to virtual memory (kernel).
  for i:= 0 to KERNEL_SIZE div PAGE_MEMORY_BLOCK - 1 do
  begin
    PageTable := VMM.CreatePageTable(KernelPageStruct_, i * PAGE_MEMORY_BLOCK, 0);
    VMM.FillPageTable(PageTable, i * PAGE_MEMORY_BLOCK, 0);
  end;

  // Map the physical video memory to virtual memory.
  addr:= VBEVideoModes[0].Info.LFB;
  while addr < (VBEVideoModes[0].Info.LFB + (1920*1080*32)) do
  begin
    PageTable := VMM.CreatePageTable(KernelPageStruct_, addr, 0);
    VMM.FillPageTable(PageTable, addr, 0);
    Inc(addr, PAGE_MEMORY_BLOCK);
  end;

  // Now we map all remaining RAM for heap.
  addr:= KERNEL_SIZE;
  MaxKernelHeapSize_:= 0;
  while ((addr div 1024) < GlobalMB^.mem_upper) and
       (KERNEL_HEAP_START + addr < KERNEL_HEAP_END) do
  // for i := 0 to 1024*4-1 do
  begin
    AllocPage(KernelPageStruct_, KERNEL_HEAP_START + addr - KERNEL_SIZE, 1);
    addr:= addr + PAGE_SIZE;
    Inc(MaxKernelHeapSize_, PAGE_SIZE);
  end;

  VMM.EnablePageDir(@KernelPageStruct_^.Directory);
  IsPaging:= True;

  Console.WriteStr(stOK);
end;

end.
