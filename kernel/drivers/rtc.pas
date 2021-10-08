{
    File:
        rtc.pas
    Description:
        RTC driver unit.
    License:
        General Public License (GPL)
}

unit rtc;

{$I KOS.INC}

interface

uses
  console,
  idt;

type
  TDateTime = record
    Second, Minute, Hour, DayOfWeek, DayOfMonth, Month, Year: Byte;
  end;

var
  GlobalTime: TDateTime;
  IsBCD     : Boolean;

function  ReadRegister(AReg: Byte): Byte; stdcall;
procedure WriteRegister(AReg, AValue: Byte); stdcall;
function  GetTime: TDateTime; stdcall;
procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;
//
function  GetTickCount: Cardinal; stdcall;

// Show timer thread
procedure DisplayTimerThread(PID: PtrUInt); stdcall;

implementation

uses
  vga, pic;

var
  _tickCount: Cardinal = 0;

// ----- helper functions -----

function  ReadRegister(AReg: Byte): Byte; stdcall; inline;
begin
  outb($70, AReg);
  exit(inb($71));
end;

procedure WriteRegister(AReg, AValue: Byte); stdcall; inline;
begin
  outb($70, AReg);
  outb($71, AValue);
end;

// ----- RTC -----

function  GetTickCount: Cardinal; stdcall;
begin
  exit(_tickCount);
end;

function  GetTime: TDateTime; stdcall; [public, alias: 'k_RTC_GetTime'];
begin
  exit(GlobalTime);
end;

procedure Callback(r: TRegisters); stdcall;
begin
  begin
    if (RTC.ReadRegister($0C) and $40) <> 0 then
      with GlobalTime do
        if IsBCD then
        begin
          Second:= BCDToBin(RTC.ReadRegister($00));
          Minute:= BCDToBin(RTC.ReadRegister($02));
          Hour  := BCDToBin(RTC.ReadRegister($04));
          Month := BCDToBin(RTC.ReadRegister($08));
          Year  := BCDToBin(RTC.ReadRegister($09));
          DayOfWeek := BCDToBin(RTC.ReadRegister($06));
          DayOfMonth:= BCDToBin(RTC.ReadRegister($07));
        end else
        begin
          Second:= RTC.ReadRegister($00);
          Minute:= RTC.ReadRegister($02);
          Hour  := RTC.ReadRegister($04);
          Month := RTC.ReadRegister($08);
          Year  := RTC.ReadRegister($09);
          DayOfWeek := RTC.ReadRegister($06);
          DayOfMonth:= RTC.ReadRegister($07);
        end;
  end;
  Inc(_tickCount);
end;

procedure Init; stdcall;
var
  status: Byte;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing RTC (0x28)... ');
  IDT.InstallHandler($28, @RTC.Callback);

  RTC.WriteRegister($0A, RTC.ReadRegister($0A) or $0F);
  status:= RTC.ReadRegister($0B);
  status:= status or $02;                 // 24 Hour clock
  status:= status and $10;                // No update ended interrupts
  status:= status and not $20;            // No alarm interrupts
  status:= status or $40;                 // Enable periodic interrupt
  IsBCD := Boolean(not (status and $04)); // Check if data type is BCD
  RTC.WriteRegister($0B, status);
  // Change freq
  // RTC.WriteRegister($8A, (RTC.ReadRegister($71) and $F0) or 6);

  // Wait for interrupt
  RTC.ReadRegister($0C);
  Console.WriteStr(stOk);

  IRQ_ENABLE;
end;

procedure DisplayTimerThread(PID: PtrUInt); stdcall;
var
  ScrHeight: Word;
  OldBgColor,
  OldFgColor: Byte;
  DateTime  : TDateTime;
begin
  // Grab from PIC
  while True do
  begin
    IRQ_DISABLE;
    OldBgColor:= Console.GetBgColor;
    OldFgColor:= Console.GetFgColor;
    Console.SetBgColor(1);
    Console.SetFgColor(15);
    DateTime:= RTC.GetTime;

    if DateTime.Hour > 80 then
      DateTime.Hour:= DateTime.Hour - 80 + 12;

    case IsGUI of
      False:
        begin
          ScrHeight:= VGA.GetScreenHeight-1;
          Console.WriteAtPos(63, ScrHeight, 'Time: ');
          Console.WriteDecAtPos(69, ScrHeight, DateTime.Hour, 2);
          Console.WriteAtPos(71, ScrHeight, ':');
          Console.WriteDecAtPos(72, ScrHeight, DateTime.Minute, 2);
          Console.WriteAtPos(74, ScrHeight, ':');
          Console.WriteDecAtPos(75, ScrHeight, DateTime.Second, 2);
          Console.SetBgColor(OldBgColor);
          Console.SetFgColor(OldFgColor);
        end;
    end;
    IRQ_ENABLE;
    PROCESS_WAIT;
  end;
end;

end.
