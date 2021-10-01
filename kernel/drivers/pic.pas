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
function  Callback(AStack: Cardinal): Cardinal; stdcall;
procedure Init(frequency: Cardinal); stdcall;
//
function  GetTickCount: Cardinal; stdcall;
// Reinstall the freq
procedure Freq(const ATime: Cardinal); stdcall;

implementation

uses
  spinlock,
  schedule;

var
  _tickCount       : Cardinal = 0;

function  Callback(AStack: Cardinal): Cardinal; stdcall;
begin
  Inc(_tickCount);
  { We can perform task switching in here }
  if EnableTaskSwitching and not Spinlock.IsLocked(Schedule.SLock) then
    exit(Schedule.Run(AStack))
  else
    exit(AStack);
end;

procedure Init(frequency: Cardinal); stdcall;
var
  divisor: Cardinal;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing PIC (0x20)... ');
  IDT.InstallPICHandler(@PIC.Callback);

  divisor:= 1193180 div frequency;

  // Send the command byte.
  outb($43, $36);
  outb($40, divisor and $FF);
  outb($40, divisor shr 8);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

function  GetTickCount: Cardinal; stdcall;
begin
  exit(_tickCount);
end;

procedure Freq(const ATime: Cardinal); stdcall;
var
  divisor: Cardinal;
begin
  divisor:= 1193180 div ATime;

  // Send the command byte.
  outb($43, $36);
  outb($40, divisor and $FF);
  outb($40, divisor shr 8);
end;

end.
