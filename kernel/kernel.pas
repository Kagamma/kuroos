{
    File:
        kernel.pas
    Description:
        N/A.
    License:
        General Public License (GPL)
}

unit kernel;

{$I KOS.INC}

interface

uses
  mboot, real,
  sysutils, math,
  console, bios,
  gdt, idt, isr_irq,
  int0x03, int0x0e, int0x61, int0x69, int0x71,
  pmm, vmm, kheap,
  pic, rtc, mouse, keyboard, vga, vbe, ide,
  fat, cdfs, filesystem,
  schedule, mutex, spinlock,
  consolecmd, trace,
  objects, strings,
  kurogl, kurowm;

implementation

procedure k_Main(mbInfo: PMB_Info; LoaderMagic: Cardinal; KernelStack: Cardinal); stdcall;
    [public, alias: 'k_main'];
var
  pc    : PChar;
  i     : Cardinal;
  p     : Pointer;
  f     : TFile;
  Task  : PTaskStruct;
  s, s2 : AnsiString;
begin
  asm
    xchg bx,bx
  end;
  Math.InitFPU;
  // Setup function pointers to use by system unit
  Spinlock_Lock:= @Spinlock.Lock;
  Spinlock_Unlock:= @Spinlock.Unlock;
  Console_WriteChar:= @Console.WriteChar;
  Console_WriteStr:= @Console.WriteStr;
  KHeap_Alloc:= @KHeap.Alloc;
  KHeap_ReAlloc:= @KHeap.ReAlloc;
  KHeap_Free:= @KHeap.Free;

  // First we need to setup GDT and IDT
  GDT.Init;
  IDT.Init;

  //
  BIOS.Init;

  //
  GlobalMB:= mbInfo;
  PlacementAddr:= PlacementAddr + PAGE_SIZE;

  //
  Console.Init;
  Console.ClearScreen;

  //
  Int0x03.Init; // Hardware breakpoint
  Int0x0e.Init; // Fault
  Int0x61.Init;
  Int0x69.InitBlank;
  Int0x71.Init; // Text mode handling

  //
  PIC.Init(300);
  RTC.Init;

  //
  Keyboard.Init;
  Mouse.Init;

  VBE.Init;

  PMM.Init;
  VMM.Init;

  KHeap.Init;

  Writeln('Total memory: ', mbInfo^.mem_upper * 1024, ' bytes');
  Writeln(
      'Memory available: ',
      Cardinal(mbInfo^.mem_upper * 1024 - Cardinal(PlacementAddr)),
      ' bytes');
  Writeln(
      'Kernel size: ',
      Cardinal(Cardinal(PlacementAddr) - $100000),
      ' bytes');
  Writeln(
      'Kernel physical memory: ',
      Cardinal(KERNEL_SIZE - Cardinal(PlacementAddr)),
      ' bytes');

  IDE.Init;
  //IDE.Test;
  FAT.Init;
  // Just want to test if the good old Object works...
  CDFSObj:= New(PCDFSObject, Init);
  Trace.Init;
  // KHeap.Test;

  //CDFSObj^.Test;
  // We init multi-tasking in here
  Schedule.Init;
  // Create default tasks
  Schedule.CreateKernelThread('Kuro', @CmdThread, 16384);
  Schedule.CreateKernelThread('Clock Viewer', @DisplayTimerThread, 1024);

  // Modify task priority
  TaskArray[0].Priority:= TASK_PRIORITY_VHIGH;
  TaskArray[1].Priority:= TASK_PRIORITY_VLOW;
  // Enable multi-tasking
  Schedule.EnableTaskSwitching:= True;

  //
  //Debug_PrintMemoryBlocks;

  Keyboard.ClearBuffer;

  INFINITE_LOOP;
end;

end.
