{
    File:
        int0x69.pas
    Description:
        Syscalls for KuroWM
    Usage:
        EAX = 0: Create new Window
            ESI: KuroStruct's address
            <-
            EAX: Window handler
        EAX = 1: Create new Button
            ESI: KuroStruct's address
            <-
            EAX: Window handler
        EAX = 2: Create new Image
            ESI: KuroStruct's address
            ECX: Image path
            <-
            EAX: Window handler
        EAX = 100: Repaint
            ESI: KuroStruct's address
        EAX = 101: Update name
            ESI: KuroStruct's address
            ECX: New name
        EAX = 102: Update position
            ESI: KuroStruct's address
            ECX: X
            EDX: Y
        EAX = 200: Close handle
            ESI: KuroStruct's address
        EAX = 300: Polling for message
            ESI: KuroView's address
            <-
            EAX: 1 if has message
            EBX: command
            ECX: param1
            EDX: param2
        EAX = 301: Send message
            ESI: KuroView's address
            EBX: Command
            ECX: param1
            EDX: param2

        TODO:
            Each view type should have 0x100 reserve cases
    License:
        General Public License (GPL)
}

unit int0x69;

{$I KOS.INC}

interface

uses
  console,
  idt;

type
  PKuroStruct = ^TKuroStruct;
  TKuroStruct = packed record
    Name: PChar;
    Parent: Pointer;
    X, Y: LongInt;
    Width,
    Height: Cardinal;
    AttrFlag: Cardinal;
  end;

procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;
procedure InitBlank; stdcall;

implementation

uses
  schedule,
  vmm, kheap,
  kurowm;

// Private

var
  FuncTable: array[0..999] of TIDTHandle;
  TaskBackup: PTaskStruct;

// Public

procedure CallbackBlank(r: TRegisters); stdcall;
begin
  Schedule.KillProcess(TaskCurrent^.PID);
  Writeln('Kuro Window Manager is not initialized!');
end;

function GetView(const View: PKuroView): PKuroView;
begin
  if View^.Tag = TAG_KUROWINDOW then
  begin
    exit(PKuroWindow(View^.Parent));
  end
  else
    exit(View);
end;

procedure FTCreateWindow(r: TRegisters); stdcall; public;
var
  K: TKuroStruct;
  Parent: PKuroObject;
  W: PKuroWindow;
  S: PChar;
begin
  K := PKuroStruct(r.esi)^;
  if K.Name <> nil then
    S := K.Name
  else
    S := ' ';
  if K.Parent <> nil then
    Parent := K.Parent
  else
    Parent := GetKuroWMInstance;
  New(W, Init(Parent));
  with W^ do
  begin
    SetPosition(K.X, K.Y);
    SetSize(K.Width, K.Height);
    IsMoveable := Boolean(K.AttrFlag and 1 <> 0);
    PID := TaskBackup^.PID;
    Body^.SetName(S);
    Focus;
  end;
  IRQEAXHave := 1;
  IRQEAXValue := Cardinal(W^.Body);
end;

procedure FTCreateButton(r: TRegisters); stdcall; public;
var
  K: TKuroStruct;
  Parent: PKuroObject;
  B: PKuroButton;
  S: PChar;
begin
  K := PKuroStruct(r.esi)^;
  if K.Name <> nil then
    S := K.Name
  else
    S := ' ';
  if K.Parent <> nil then
    Parent := K.Parent
  else
    Parent := GetKuroWMInstance;
  New(B, Init(Parent));
  with B^ do
  begin
    SetPosition(K.X, K.Y);
    SetSize(K.Width, K.Height);
    IsMoveable := Boolean(K.AttrFlag and 1 <> 0);
    PID := TaskBackup^.PID;
    SetName(S);
  end;
  IRQEAXHave := 1;
  IRQEAXValue := Cardinal(B);
end;

procedure FTCreateImage(r: TRegisters); stdcall; public;
var
  K: TKuroStruct;
  Parent: PKuroObject;
  Image: PKuroImage;
  S, S2: PChar;
  Size: LongInt;
begin
  K := PKuroStruct(r.esi)^;
  if K.Name <> nil then
    S := K.Name
  else
    S := ' ';
  if K.Parent <> nil then
    Parent := K.Parent
  else
    Parent := GetKuroWMInstance;
  if r.ecx <> 0 then
  begin
    size := Length(PChar(r.ecx)) + 1;
    S2 := Alloc(size);
    Move(PChar(r.ecx)[0], S2[0], size);
  end else
    S2 := nil;
  New(Image, Init(Parent));
  with Image^ do
  begin
    SetPosition(K.X, K.Y);
    SetSize(K.Width, K.Height);
    SetImage(S2);
    IsMoveable := Boolean(K.AttrFlag and 1 <> 0);
    PID := TaskBackup^.PID;
    SetName(S);
  end;
  IRQEAXHave := 1;
  IRQEAXValue := Cardinal(Image);
end;

procedure FTRepaint(r: TRegisters); stdcall; public;
var
  V: PKuroView;
begin
  V := PKuroView(r.esi);
  V^.RenderUpdate;
end;

procedure FTSetName(r: TRegisters); stdcall; public;
var
  V: PKuroView;
  S: PChar;
begin
  V := PKuroView(r.esi);
  if r.ecx <> 0 then
    S := PChar(r.ecx)
  else
    S := ' ';
  V^.SetName(S);
  V^.RenderUpdate;
end;

procedure FTSetPosition(r: TRegisters); stdcall; public;
var
  V: PKuroView;
begin
  V := PKuroView(r.esi);
  V^.SetPosition(r.ecx, r.edx);
  V^.RenderUpdate;
end;

procedure FTCloseHandle(r: TRegisters); stdcall; public;
var
  V: PKuroView;
begin
  V := PKuroView(r.esi);
  V := GetView(V);
  V^.Close;
end;

procedure FTPollingMessage(r: TRegisters); stdcall; public;
var
  V: PKuroView;
begin
  IRQEAXHave := 1;
  V := PKuroView(r.esi);
  if V^.SendMessage(LongInt(IRQEBXValue), LongInt(IRQECXValue), LongInt(IRQEDXValue)) then
  begin
    IRQEAXValue := 1;
    IRQEBXHave := 1;
    IRQECXHave := 1;
    IRQEDXHave := 1;
  end
  else
  begin
    IRQEAXValue := 0;
  end;
end;

procedure FTReceiveMessage(r: TRegisters); stdcall; public;
var
  V: PKuroView;
begin
  V := PKuroView(r.esi);
  V^.ReceiveMessage(r.ebx, r.ecx, r.edx);
end;

procedure Callback(r: TRegisters); stdcall; public;
begin
  // We switch current task back to Kuro task. Kuro Window Objects should be
  // managed by Kuro
  TaskBackup := TaskCurrent;
  TaskCurrent := FindProcess(1);
  FuncTable[r.eax](r);
  TaskCurrent := TaskBackup;
end;

procedure Init; stdcall;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing KuroWM Syscalls (0x69)... ');
  IDT.InstallHandler($69, @Int0x69.Callback);
  FuncTable[0] := @FTCreateWindow;
  FuncTable[1] := @FTCreateButton;
  FuncTable[2] := @FTCreateImage;
  FuncTable[100] := @FTRepaint;
  FuncTable[101] := @FTSetName;
  FuncTable[102] := @FTSetPosition;
  FuncTable[200] := @FTCloseHandle;
  FuncTable[300] := @FTPollingMessage;
  FuncTable[301] := @FTReceiveMessage;
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

procedure InitBlank; stdcall;
begin
  IRQ_DISABLE;

  IDT.InstallHandler($69, @Int0x69.CallbackBlank);

  IRQ_ENABLE;
end;

end.
