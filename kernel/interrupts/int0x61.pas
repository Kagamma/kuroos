{
    File:
        int0x61.pas
    Description:
        Syscalls for process/thread handling, memory allocation, timer
    Usage:
        AH = 0: Thread
            AL = 1: Create new thread
                ECX: Thread's heap size.
                ESI: Thread's address.
                <-
                EAX: Thread ID
            AL = 2: Kill thread
                ECX: Thread ID.
            AL = 0: Create new task
                <-
                EAX: Task ID
            AL = 4: Kill task
                ECX: Task ID.
        AH = 1: Memory
        AH = 2: Timer
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
  schedule;

// Private

// Public

procedure Callback(r: TRegisters); stdcall;
var
  r_ah,
  r_al: Byte;
begin
  r_ah:= (r.eax and $FF00) shr 8;
  r_al:= (r.eax and $FF);
  case r_ah of
    0:
      case r_al of
        1: // Create new thread
          begin
            IRQEAXHave:= 1;
            IRQEAXValue:= Schedule.CreateThread(TaskProc(r.esi), r.ecx, TaskCurrent^.PID);
          end;
        2: // Kill thread
          begin
            Schedule.KillThread(r.ecx);
          end;
        4: // Kill task
          begin
            Schedule.KillProcess(r.ecx);
          end;
      end;
  end;
end;

procedure Init; stdcall;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing Task Syscalls (0x61)... ');
  IDT.InstallHandler($61, @Int0x61.Callback);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
