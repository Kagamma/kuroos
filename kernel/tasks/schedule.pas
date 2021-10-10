{
    File:
        schedule.pas
    Description:
        Schedule and task switching.
    License:
        General Public License (GPL)
}

unit schedule;

{$I KOS.INC}
{$DEFINE GENERATE_STACK:= ;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= TaskIdPtr;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $10;   // SS
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= KernelCardinal(Task^.Stack); // ESP
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $202;  // EFLAGS
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $08;   // CS
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= KernelCardinal(Task^.Code);  // EIP

  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;

  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $10;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $10;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $10;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $10
}

{$DEFINE GENERATE_STACK_USER:= ;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= TaskIdPtr;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $23;   // SS
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= KernelCardinal(Task^.Stack); // ESP
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $202;  // EFLAGS
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $1B;   // CS
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= KernelCardinal(Task^.Code);  // EIP

  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= 0;

  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $23;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $23;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $23;
  Dec(Task^.Stack, 4); KernelCardinal(Task^.Stack^):= $23
}

interface

uses
  console,
  idt,
  vmm, kheap, objects,
  spinlock;

const
  TASK_ALIVE = 1;
  TASK_SLEEP = 2;
  TASK_DEAD = 0;

  TASK_PRIORITY_VLOW = 1;
  TASK_PRIORITY_LOW = 3;
  TASK_PRIORITY_NORMAL = 5;
  TASK_PRIORITY_HIGH = 10;
  TASK_PRIORITY_VHIGH = 15;
  TASK_PRIORITY_REALTIME = 100;
  PROCESS_STARTUP_CODE = $04000000;

type
  TaskProc = procedure(PID: PtrUInt); stdcall;

  PTaskStruct = ^TTaskStruct;
  TTaskStruct = packed record
    PID : PtrInt;
    PPID: PtrInt; // For thread only, this store task id
    //
    Name: String[32];
    //
    Spin : KernelCardinal;
    //
    State: KernelCardinal;
    // Kernel stack pointer (Unused at the moment)
    KernelStack: Pointer;
    KernelStackAddr: Pointer;
    //
    StackAddr: Pointer;
    // Stack pointer
    Stack: Pointer;
    //
    Heap: Pointer;
    // Task priority
    Priority: KernelCardinal;
    // Task's own paging
    Page: PPageStruct;
    Tracks: PPPageTable;
    TrackCount: KernelCardinal;
    // Code's pointer in kernel's address space.
    Code: TaskProc;
  end;

var
  Inbetween  : Boolean = True;
  TaskCurrent: PTaskStruct;
  TaskArray  : array[0..1999] of TTaskStruct;
  TaskCount  : Integer;
  TaskPtr    : Integer;
  SLock      : PSpinLock;
  EnableTaskSwitching: Boolean = False;

procedure Init; stdcall;
// We create a new process from buffer.
function  CreateProcessFromBuffer(const AName: KernelString; const ABuf: Pointer): PtrUInt; stdcall;
// Basically the same as task except this share the same address space with pid
function  CreateThread(ACode: TaskProc;
    AStackSize: KernelCardinal; const PPID: KernelCardinal): PtrUInt; stdcall;
// Basically the same as task except this share the same address space with pid
function  CreateKernelThread(const AName: KernelString; ACode: TaskProc;
    AStackSize: KernelCardinal): PtrUInt; stdcall;
// Find a task based on pid
function  FindProcess(const AID: PtrInt): PTaskStruct; stdcall; overload;
// Kill a task
function  KillProcess(const AID: PtrInt): Boolean; stdcall; overload;
// Kill a thread
function  KillThread(const AID: PtrInt): Boolean; stdcall; overload;
// Free a task
procedure FreeProcess(const ATask: PTaskStruct); stdcall;
//
function  Run(AStack: KernelCardinal): KernelCardinal; stdcall;
//
procedure NullThread(PID: PtrUInt); stdcall;
// Show all tasks
procedure Debug_PrintTasks; stdcall;

implementation

uses
  pic,
  sysutils,
  vbe,
  kex;

var
  DirPhys: PPageDir;
  TaskIdPtr: KernelCardinal = 1;

procedure Init; stdcall;
begin
  TaskCount:= 0;
  TaskPtr  := -1;
  SLock    := Spinlock.Create;
  Spinlock.Unlock(SLock);
  TaskCurrent:= nil;
end;

procedure IncreaseTaskCount; stdcall; public;
begin
  Inc(TaskCount);
  if TaskCount > High(TaskArray) then
  begin
    if IsGUI then
      VBE.ReturnToTextMode;
    IRQ_DISABLE;
    Console.WriteStr('Maximum number of tasks reached.');
    INFINITE_LOOP;
  end;
end;

function  CreateProcessFromBuffer(const AName: KernelString; const ABuf: Pointer): PtrUInt; stdcall;
var
  Task: PTaskStruct;
  i: KernelCardinal;
  CodeSize: KernelCardinal;
  PageTable: PPageTable;
begin
  if (PKEXHeader(ABuf)^.ID[0] <> 'K') or
     (PKEXHeader(ABuf)^.ID[1] <> '3') or
     (PKEXHeader(ABuf)^.ID[2] <> '2') then
  begin
    Writeln('This is not a Kuro executable file.');
    exit(0);
  end;
  Spinlock.Lock(Schedule.SLock);
  //
  IRQ_DISABLE;
  //
  IncreaseTaskCount;
  //
  if TaskCurrent <> nil then
    TaskCurrent:= @TaskArray[TaskPtr];
  //
  Task:= @TaskArray[TaskCount-1];
  Task^.Name:= AName;
  Task^.PID:= TaskIdPtr;
  Task^.PPID:= 0;
  Task^.Spin:= 0;
  //
  Task^.Priority:= TASK_PRIORITY_VLOW;
  // Set this task as alive
  Task^.State:= TASK_ALIVE;
  // Allocate RAM for kernel stack
 // Task^.KernelStackAddr := KHeap.Alloc(1024);
 // Task^.KernelStack:= Task^.KernelStackAddr + 1020;
 // KHeap.SetOwner(Task^.KernelStackAddr, Task^.PID);
  // Allocate RAM for stack
  Task^.StackAddr:= KHeap.Alloc(PKEXHeader(ABuf)^.StackSize);
  Task^.Stack:= Task^.StackAddr + (PKEXHeader(ABuf)^.StackSize);
  KHeap.SetOwner(Task^.StackAddr, Task^.PID);
  // Allocate RAM for the task
  CodeSize:= KHeap.CalcAlign(SizeOf(ABuf), PAGE_SIZE);
  Pointer(Task^.Code):= KHeap.AllocAligned(CodeSize);
  KHeap.SetOwner(Task^.Code, Task^.PID);
  // Copy code from buffer to our task's code
  Move(ABuf^, Pointer(Task^.Code)^, KHeap.GetSize(ABuf));
  // Create new page directory for this task
  Task^.Page:= CreatePageDirectory;
  KHeap.SetOwner(Task^.Page, Task^.PID);
  // Clone kernel page directory for this task
  Move(KernelPageStruct_^.Directory, Task^.Page^.Directory, SizeOf(TPageDir));
  Task^.TrackCount := 0;
  Task^.Tracks := KHeap.Alloc(256 * SizeOf(PPageTable));
  FillChar(Task^.Tracks[0], 256 * SizeOf(PPageTable), 0);
  // Set virtual memory for task code
  // TODO: We somehow skip a 4KB physics memory block if the kernel heap doesnt enough memory to allocate
  for i := 0 to GetSize(ABuf) div PAGE_SIZE do
  begin
    AllocPage(Task^.Page,
      PROCESS_STARTUP_CODE + i*PAGE_SIZE,
      KernelCardinal(Task^.Code) - KERNEL_HEAP_START + KERNEL_SIZE + i*PAGE_SIZE, 1,
      Task^.Tracks, Task^.TrackCount);
  end;
  Pointer(Task^.Code):= Pointer(Task^.Code) + (PKEXHeader(ABuf)^.EntryPoint - PROCESS_STARTUP_CODE);
  // Generate default stack
  GENERATE_STACK;
  //
  CreateProcessFromBuffer:= TaskIdPtr;
  Inc(TaskIdPtr);
  TaskCurrent:= @TaskArray[TaskPtr];
  //
  Spinlock.Unlock(Schedule.SLock);
  IRQ_ENABLE;
end;

function  CreateThread(ACode: TaskProc;
    AStackSize: KernelCardinal; const PPID: KernelCardinal): PtrUInt; stdcall;
var
  Task: PTaskStruct;
  TaskParent: PTaskStruct;
  pp: Pointer;
begin
  Spinlock.Lock(Schedule.SLock);
  //
  IRQ_DISABLE;
  //
  IncreaseTaskCount;
  //
  if TaskCurrent <> nil then
    TaskCurrent:= @TaskArray[TaskPtr];
  //
  Task:= @TaskArray[TaskCount-1];

  Task^.Name:= '<Thread of PID ' + IntToStr(PPID);
  Task^.Name:= Task^.Name + '>';
  Task^.PID:= TaskIdPtr;
  Task^.PPID:= PPID;
  Task^.Spin:= 0;
  //
  Task^.Priority:= TASK_PRIORITY_VLOW;
  //
  Task^.Code:= ACode;
  // Allocate RAM for stack
  // TODO: Currently this is broken. As the process wont be able to see the stack
  // if it was allocated at higher than 4MB of kernel heap
  if AStackSize < 1024 then AStackSize:= 1024;
  if AStackSize > 1024*1024 then AStackSize:= 1024*1024;
  Task^.StackAddr:= KHeap.Alloc(AStackSize);
  Task^.Stack:= Task^.StackAddr + AStackSize;
  KHeap.SetOwner(Task^.StackAddr, Task^.PID);
  // Set this task as alive
  Task^.State:= TASK_ALIVE;

  // We need to find the process that this thread belongs to.
  TaskParent:= FindProcess(PPID);
  if TaskParent <> nil then
  begin
    Task^.Page:= TaskParent^.Page;
  end
  else
  begin
    // TODO:
    Writeln('Schedule.CreateThread: Invalid process!');
    INFINITE_LOOP;
  end;
  // Generate default stack
  GENERATE_STACK;
  //
  CreateThread:= TaskIdPtr;
  Inc(TaskIdPtr);
  //
  Spinlock.Unlock(Schedule.SLock);
  IRQ_ENABLE;
end;

function  CreateKernelThread(const AName: KernelString; ACode: TaskProc;
    AStackSize: KernelCardinal): PtrUInt; stdcall;
var
  Task: PTaskStruct;
  TaskParent: PTaskStruct;
  pp: Pointer;
begin
  Spinlock.Lock(Schedule.SLock);
  //
  IRQ_DISABLE;
  //
  IncreaseTaskCount;
  if TaskCurrent <> nil then
    TaskCurrent:= @TaskArray[TaskPtr];
  //
  Task:= @TaskArray[TaskCount-1];

  Task^.Name:= AName;
  Task^.PID:= TaskIdPtr;
  Task^.PPID:= 0;
  Task^.Spin:= 0;
  //
  Task^.Priority:= TASK_PRIORITY_VLOW;
  //
  Task^.Code:= ACode;
  // Allocate at least 1KB RAM for stack
  if AStackSize < 1024 then AStackSize:= 1024;
  Task^.StackAddr:= KHeap.Alloc(AStackSize);
  Task^.Stack:= Task^.StackAddr + AStackSize;
  KHeap.SetOwner(Task^.StackAddr, Task^.PID);
  // Set this task as alive
  Task^.State:= TASK_ALIVE;
  // Use the same address page with kernel
  Task^.Page:= VMM.KernelPageStruct_;
  // Generate default stack
  GENERATE_STACK;
  //
  CreateKernelThread:= TaskIdPtr;
  Inc(TaskIdPtr);
  //
  Spinlock.Unlock(Schedule.SLock);
  IRQ_ENABLE;
end;

function  FindProcess(const AID: PtrInt): PTaskStruct; stdcall;
var
  i: Integer;
begin
  FindProcess:= nil;
  for i:= 0 to TaskCount-1 do
    if TaskArray[i].PID = AID then
      FindProcess:= @TaskArray[i];
end;

procedure MarkAllThreadsAsDead(const AID: PtrInt); stdcall;
var
  i: Integer;
begin
  for i:= 0 to TaskCount-1 do
    if TaskArray[i].PPID = AID then
      TaskArray[i].State:= TASK_DEAD;
end;

function  KillProcess(const AID: PtrInt): Boolean; stdcall;
var
  Thread,
  Task: PTaskStruct;
  i: KernelCardinal;
begin
  IRQ_DISABLE;
  Task:= FindProcess(AID);
  if (Task <> nil) and (Task^.PPID = 0) then
  begin
    Task^.State:= TASK_DEAD;
    // We need to mark all thread of this task as dead as well
    MarkAllThreadsAsDead(AID);
    KillProcess:= True;
  end
  else
    KillProcess:= False;
  IRQ_ENABLE;
end;

function  KillThread(const AID: PtrInt): Boolean; stdcall;
var
  Thread,
  Task: PTaskStruct;
  i: KernelCardinal;
begin
  IRQ_DISABLE;
  Task:= FindProcess(AID);
  if (Task <> nil) and (Task^.PPID <> 0) then
  begin
    Task^.State:= TASK_DEAD;
    KillThread:= True;
  end
  else
    KillThread:= False;
  IRQ_ENABLE;
end;

procedure FreeProcess(const ATask: PTaskStruct); stdcall;
var
  I: Byte;
begin
  // Free task's all memory
  if ATask^.PPID = 0 then
    for I := 0 to ATask^.TrackCount - 1 do
      FreePageTable(ATask^.Tracks[I]);
  FreeMem(ATask^.Tracks);
  FreeAllMemory(ATask^.PID);
end;

function  Run(AStack: KernelCardinal): KernelCardinal; stdcall;
var
  i: Integer;
  TaskCur: PTaskStruct;
  Code: Cardinal;
label
  Start;
begin
  //
  TaskCur := TaskCurrent;
  TaskCurrent := nil;
  Inbetween:= True;
  if TaskCount > 0 then
  begin
    // Switch page directory to kernel
    VMM.SwitchPageDir(@KernelPageStruct_^.Directory);
    // Save current stack register to older task
    if (TaskPtr >= 0) then
    begin
      TaskCur^.Stack:= Pointer(AStack);
    Start:
      {if TaskCurrent^.PriorityCount >= TaskCurrent^.Priority then
      begin
        TaskCurrent^.PriorityCount:= 0;
        Inc(TaskPtr);
        if TaskPtr > TaskCount-1 then
          TaskPtr:= 0;
      end
      else
        Inc(TaskCurrent^.PriorityCount); }

      // Install PIC freq based on priority
      Inc(TaskPtr);
      if TaskPtr > TaskCount-1 then
        TaskPtr:= 0;
      PIC.Freq(60 * TaskCur^.Priority);
      //
    end
    else
      Inc(TaskPtr);
    //
    TaskCur:= @TaskArray[TaskPtr];
    // Check to see if this task's mark as removed. If yes, we perform task remove.
    if TaskCur^.State = TASK_DEAD then
    begin
      FreeProcess(TaskCur);
      // Move all tasks to the left
      for i:= TaskPtr to TaskCount-2 do
      begin
        TaskArray[i]:= TaskArray[i+1];
      end;
      //
      Dec(TaskCount);
      // Reallocate task array
     // TaskArray:= KHeap.ReAlloc(TaskArray, SizeOf(TTaskStruct) * TaskCount);
      // Misc
      TaskCur:= @TaskArray[0];
      TaskPtr:= 0;
      //
      goto Start;
    end;
    Inc(TaskCur^.Spin);
    // Calculate real address of task
    DirPhys:= Pointer(TaskCur^.Page^.PhysAddr);
    // Switch page directory
    if DirPhys <> VMM.CurrentPageDir_ then
    begin
      VMM.SwitchPageDir(DirPhys);
    end;
    //
    Run:= KernelCardinal(TaskCur^.Stack);
  end
  else
    Run:= AStack;
  Inbetween:= False;
  TaskCurrent := TaskCur;
end;

procedure NullThread(PID: PtrUInt); stdcall;
var
  Task: PTaskStruct = nil;
begin
  Task:= FindProcess(PID);
  if Task <> nil then
    Task^.Priority:= TASK_PRIORITY_VLOW;
  while True do;
end;

procedure Debug_PrintTasks; stdcall;
var
  i: Integer;
  Task: PTaskStruct;
begin     //0    //6                       //32        //44    // 52     // 62
  Console.SetFgColor(14);
  Writeln('PID   Name                      Loop        Priority  Mem.Usage(bytes)');
  Console.SetFgColor(7);
  Writeln('----------------------------------------------------------------------');
  for i:= 0 to TaskCount-1 do
  begin
    Task:= @TaskArray[i];
    Console.WriteDec(Task^.PID);
    Console.SetCursorPos(6, Console.GetCursorPosY);
    Write(Task^.Name);
    Console.SetCursorPos(32, Console.GetCursorPosY);
    Console.WriteDec(Task^.Spin);
    {Console.SetCursorPos(44, Console.GetCursorPosY);
    case Task^.State of
      TASK_ALIVE: Write('Alive');
      TASK_SLEEP: Write('Sleep');
    end;}
    Console.SetCursorPos(44, Console.GetCursorPosY);
    case Task^.Priority of
      TASK_PRIORITY_VLOW: Write('V.Low');
      TASK_PRIORITY_LOW: Write('Low');
      TASK_PRIORITY_NORMAL: Write('Normal');
      TASK_PRIORITY_HIGH: Write('High');
      TASK_PRIORITY_VHIGH: Write('V.High');
    end;
    Console.SetCursorPos(54, Console.GetCursorPosY);
    Console.WriteDec(Debug_PrintProcessMemoryUsage(Task^.PID));
    Console.WriteStr(#10#13);
  end;
end;

end.
