{
    File:
        int0x61.pas
    Description:
        Syscalls for process/thread handling, memory allocation, timer
    Usage:
        EAX = 0: Create new thread
            ECX: Thread's heap size.
            ESI: Thread's address.
            <-
            EAX: Thread ID
        EAX = 1: Kill thread
            ECX: Thread ID.
        EAX = 2: Create new task
            <-
            EAX: Task ID
        EAX = 3: Kill task
            ECX: Task ID.
        EAX = 4: GetSize
            ESI: Pointer
            <-
            EAX: Size
        EAX = 5: Alloc (aligned)
            ECX: Size
            <-
            EAX: Pointer
        EAX = 6: Free
            ESI: Pointer
        EAX = 7: GetTime
            <-
            EAX: 8 bytes of hh << mm << ss
            ECX: 16 bytes of year << 8 bytes of month << day
    License:
        General Public License (GPL)
}

unit int0x61;

{$I KOS.INC}

interface

uses
  console,
  idt;

procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;

implementation

uses
  rtc, kheap, vmm,
  schedule;

// Private

var
  FuncTable: array[0..7] of TIDTHandle;

// Public

procedure FTNewThread(r: TRegisters); stdcall; public;
begin
  IRQEAXHave:= 1;
  IRQEAXValue:= Schedule.CreateThread(TaskProc(r.esi), r.ecx, TaskCurrent^.PID);
end;

procedure FTKillThread(r: TRegisters); stdcall; public;
begin
  Schedule.KillThread(r.ecx);
end;

procedure FTNewTask(r: TRegisters); stdcall; public;
begin
  // TODO
end;

procedure FTKillTask(r: TRegisters); stdcall; public;
begin
  Schedule.KillProcess(r.ecx);
end;

procedure FTGetSize(r: TRegisters); stdcall; public;
begin
  IRQEAXHave:= 1;
  IRQEAXValue := KHeap.GetSize(Pointer(r.esi));
end;

procedure FTAlloc(r: TRegisters); stdcall; public;
begin
  IRQEAXHave:= 1;
  IRQEAXValue := Cardinal(KHeap.AllocAligned(r.ecx));
end;

procedure FTFree(r: TRegisters); stdcall; public;
begin
  KHeap.Free(Pointer(r.esi));
end;

procedure FTGetTime(r: TRegisters); stdcall; public;
begin
  IRQEAXHave:= 1;
  IRQECXHave:= 1;
  IRQEAXValue:= (Cardinal(GlobalTime.Hour) shl 16) or (Word(GlobalTime.Minute) shl 8) or GlobalTime.Second;
  IRQECXValue:= (Cardinal(GlobalTime.Year) shl 16) or (Word(GlobalTime.Month) shl 8) or GlobalTime.DayOfMonth;
end;

procedure Callback(r: TRegisters); stdcall;
begin
  FuncTable[r.eax](r);
end;

procedure Init; stdcall;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing Task Syscalls (0x61)... ');
  IDT.InstallHandler($61, @Int0x61.Callback);
  FuncTable[0] := @FTNewThread;
  FuncTable[1] := @FTKillThread;
  FuncTable[3] := @FTKillTask;
  FuncTable[4] := @FTGetSize;
  FuncTable[5] := @FTAlloc;
  FuncTable[6] := @FTFree;
  FuncTable[7] := @FTGetTime;
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
