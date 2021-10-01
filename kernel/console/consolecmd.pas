{
    File:
        consolecmd.pas
    Description:
        KOS's command line interface.
    License:
        General Public License (GPL)

    ref:
        http://alumnus.caltech.edu/~pje/iso9660.html
        http://www.cdroller.com/htm/readdata.html
}

unit consolecmd;

{$I KOS.INC}

interface

// Command thread
procedure CmdThread(PID: PtrUInt); stdcall;
// List all directory
procedure Dir; stdcall;
// Test KuroWM
procedure StartKuroWM; stdcall;

implementation

uses
  sysutils,
  console, keyboard, rtc,
  kheap,
  schedule,
  ide, cdfs,
  vga, vbe, kurogl, math, mouse,
  objects, kurowm;

var
  WM: TKuroWM;

procedure CmdThread(PID: PtrUInt); stdcall;
var
  Cmd: KernelString;
  Tmp: String[32];
  i,
  LID: Integer;
  C  : Char;
  NullPID: Integer = 3;
  p  : Pointer = nil;
  List: TList;
begin
  // List.Init;
  // List.Add(Pointer(2));
  // List.Add(Pointer(31));
  // List.Add(Pointer(9));
  // List.Add(Pointer(7));
  // List.Delete(1);
  // List.Delete(2);
  // for i := 0 to List.Count-1 do
  // begin
  //   Writeln(LongInt(List.Items[i]));
  // end;
  // List.Done;
  Writeln;
  Writeln('Type ''help'' to see list of commands.');
  Writeln('Type any .KEX file name to execute.');
  Writeln;
  while True do
  begin
    FillChar(Cmd[0], 256, 0);
    Write('>');
    while True do
    begin
      C:= Char(Keyboard.GetLastKeyStroke);
      case C of
        #32..#127:
          begin
            Write(C);
            Cmd:= Cmd + C;
          end;
        #10:
          begin
            Keyboard.ClearBuffer;
            Writeln;
            break;
          end;
      end;
    end;
    if Length(Cmd) = 0 then
      continue;
    Cmd:= LowerCase(Cmd);
    if Cmd = 'help' then
    begin
      Writeln(' - help       : Show this help');
      Writeln(' - dir        : List all files on CD''s root directory');
      Writeln(' - kill [pid] : Delete a process by pid');
      Writeln(' - mem        : Print all memory blocks');
      Writeln(' - ps         : Print all tasks');
      Writeln(' - wm         : Kuro Window Manager');
    end
    else
    if Cmd = 'wm' then
    begin
      StartKuroWM;
    end
    else
    if Cmd = 'ps' then
    begin
      Debug_PrintTasks;
    end
    else
    if Cmd = 'mem' then
    begin
      Debug_PrintMemoryBlocks;
    end
    else
    if Cmd = 'dir' then
    begin
      Dir;
    end
    else
    if Pos('kill ', Cmd) = 1 then
    begin
      Tmp[0]:= #0;
      for i:= 0 to 255 do
      begin
        C:= Cmd[i + 6];
        if C in ['0'..'9'] then
        begin
          Tmp[i+1]:= C;
          Tmp[0]:= Char(i + 1);
        end
        else
          break;
      end;
      if Length(Tmp) > 0 then
      begin
        // We kill the task
        LID:= StrToInt(Tmp);
        Write('Trying to kill process #', LID, '... ');
        if LID = 1 then
        begin
          Writeln('Nice try, but you cannot kill me!');
        end
        else
        begin
          if KillProcess(LID) then
            Writeln('Ok!')
          else
            Writeln('Failed!');
        end;
      end;
    end
    else
    begin
      p:= CDFSObj^.Loader(IDE.FindDrive(True), Cmd);
      if p <> nil then
      begin
        // Create a new process
        Schedule.CreateProcessFromBuffer(Cmd, p);
        KHeap.Free(p);
      end
      else
      begin
        Writeln('Unknown command: ', Cmd);
      end;
    end;
  end;
end;

procedure PointRotate(X, Y, AX, AY, Angle: Single; var RX, RY: LongInt);
var
  S, C,
  XNew, YNew: Single;
begin
  X := X-AX;
  Y := Y-AY;
  S := Sin(Angle);
  C := Cos(Angle);

  XNew := X * C - Y * S;
  YNew := X * S + Y * C;

  RX := Round(XNew+AX);
  RY := Round(YNew+AY);
end;

procedure BtnRunWin(const Sender: PKuroObject; const M: PKuroMessage);
var
  CM: TKuroMessage;
  i: Integer;
  p: Pointer;
begin
  if (M^.Command = KM_MOUSEUP) and (Boolean(M^.LoShort1 and $01)) and PKuroButton(Sender)^.IsFocused then
  begin
    IRQ_ENABLE;
    p:= CDFSObj^.Loader(IDE.FindDrive(True), 'win.kex');
    IRQ_DISABLE;
    if p <> nil then
    begin
      // Create a new process
      Schedule.CreateProcessFromBuffer('win.kex', p);
      FreeMem(p);
    end;
  end;
end;

procedure BtnCloseWm(const Sender: PKuroObject; const M: PKuroMessage);
begin
  if (M^.Command = KM_MOUSEUP) and (Boolean(M^.LoShort1 and $01)) and PKuroButton(Sender)^.IsFocused then
  begin
    WM.TextMode;
  end;
end;

procedure StartKuroWM; stdcall;
var
  i: Integer;
  Taskbar: PKuroView;
  Win2: PKuroWindow;
  Btn: PKuroButton;
  PWM: PKuroWM;
begin
  Keyboard.ClearBuffer;

  PWM := GetKuroWMInstance;
  if PWM <> nil then
  begin
    PWM^.GraphicsMode;
    exit;
  end;

  WM.Init;

  // New(Win2, Init(@KuroWM));
  // Win2^.SetPosition(150, 200);
  // Win2^.SetSize(200, 150);
  // Win2^.IsMoveable := true;

  New(Taskbar, Init(@WM));
  Taskbar^.X := 0;
  Taskbar^.Y := 570;
  Taskbar^.Width := WM.Width;
  Taskbar^.Height := 30;
  Taskbar^.IsMoveable := false;
  Taskbar^.Focus;
  Taskbar^.BgColor := $FF404040;
  Taskbar^.BgColorSelected := Taskbar^.BgColor;

  New(Btn, Init(Taskbar));
  Btn^.Name := 'Close WM';
  Btn^.SetPosition(15, 2);
  Btn^.SetSize(160, 24);
  Btn^.OnCallback := @BtnCloseWm;

  New(Btn, Init(Taskbar));
  Btn^.Name := 'Run win.kex';
  Btn^.SetPosition(200, 2);
  Btn^.SetSize(160, 24);
  Btn^.OnCallback := @BtnRunWin;

  // New(Win3, Init(Win2));
  // Win3^.X := 0;
  // Win3^.Y := 30;
  // Win3^.Width := 200;
  // Win3^.Height := 120;
  // Win3^.IsMoveable := false;
  // Win3^.BgColor := $FF808080;
  // Win3^.BgColorSelected := $FFA0A0A0;

  WM.ProcessMessages;
end;

procedure   Dir; stdcall;
var
  Buf: Pointer;
  DirRec: PCDFSDirectory;
  DriveInfoSt: PDriveInfoStruct = nil;
  i, j: Cardinal;
begin
  // Find CDROM drive
  DriveInfoSt:= IDE.FindDrive(True);
  // Try to read data from CD
  if DriveInfoSt <> nil then
  begin
    Buf:= KHeap.Alloc(ATAPI_SECTOR_SIZE);

    // Parse the data for files and dirs
    CDFSObj^.ScanForDirectories(DriveInfoSt, nil);
    // Show all folder and files
    for i:= 0 to CDFSObj^.DirectoryCount-1 do
    begin
      DirRec:= @CDFSObj^.DirectoryArray[i].Dir;
      Write(DirRec^.FileIndentStr);
      if (DirRec^.FileFlag and 2) = 2 then
      begin
        Console.SetCursorPos(30, Console.GetCursorPosY);
        Writeln('<DIR>');
      end
      else
      begin
        Console.SetCursorPos(30, Console.GetCursorPosY);
        Writeln(DirRec^.DataLen[0], ' bytes');
      end
    end;
  end;
end;

end.

