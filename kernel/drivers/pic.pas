{
    File:
        pic.pas
    Description:
        PIC driver unit.
    License:
        General Public License (GPL)
}

unit pic;

{$I KOS.INC}

interface

uses
  console,
  idt;

// PIC callback, call at a frequent of 1ms/call
function  Callback(AStack: KernelCardinal): KernelCardinal; stdcall;
procedure Init(frequency: KernelCardinal); stdcall;
//
function  GetTickCount: KernelCardinal; stdcall;
// Reinstall the freq
procedure Freq(const ATime: KernelCardinal); stdcall;

implementation

uses
  spinlock,
  schedule;

var
  _tickCount       : KernelCardinal = 0;

function  Callback(AStack: KernelCardinal): KernelCardinal; stdcall;
begin
  Inc(_tickCount, 4);
  { We can perform task switching in here }
  if EnableTaskSwitching and not Spinlock.IsLocked(Schedule.SLock) then
    exit(Schedule.Run(AStack))
  else
    exit(AStack);
end;

function  CallbackCoop(AStack: KernelCardinal): KernelCardinal; stdcall;
begin
  { We can perform task switching in here }
  if EnableTaskSwitching and not Spinlock.IsLocked(Schedule.SLock) then
    exit(Schedule.Run(AStack))
  else
    exit(AStack);
end;

procedure Init(frequency: KernelCardinal); stdcall;
var
  divisor: KernelCardinal;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing PIC (0x20)... ');
  IDT.InstallPICHandler(@PIC.Callback);
  IDT.InstallCooperativeHandler($60, @PIC.CallbackCoop);

  divisor:= 1193180 div frequency;

  // Send the command byte.
  outb($43, $36);
  outb($40, divisor and $FF);
  outb($40, divisor shr 8);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

function  GetTickCount: KernelCardinal; stdcall;
begin
  exit(_tickCount);
end;

procedure Freq(const ATime: KernelCardinal); stdcall;
var
  divisor: KernelCardinal;
begin
  divisor:= 1193180 div ATime;

  // Send the command byte.
  outb($43, $36);
  outb($40, divisor and $FF);
  outb($40, divisor shr 8);
end;

end.
