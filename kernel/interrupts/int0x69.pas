{
    File:
        int0x69.pas
    Description:
        Syscalls for KuroWM
    Usage:
        AH = 0: // Create
            AL = 1: Create new Window
                ESI: KuroStruct's address
                <-
                EAX: Window handler
            AL = 2: Create new Button
                ESI: KuroStruct's address
                <-
                EAX: Window handler
        AH = 1: // Update
            AL = 1: Update name
                ESI: KuroStruct's address
                ECX: New name
        AH = 3: // Delete
            AL = 1: Delete
                ESI: KuroStruct's address
        AH = 4: // Messege
            AL = 1: Polling for message
                ESI: KuroView's address
                <-
                EAX: 1 if has message
                EBX: command
                ECX: param1
                EDX: param2
            AL = 2: Send message
                ESI: KuroView's address
                EBX: Command
                ECX: param1
                EDX: param2
        AH = 5: // Drawing

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
    IsMoveable: Cardinal;
  end;

procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;

implementation

uses
  schedule,
  vmm,
  kurowm;

// Private

// Public

procedure Callback(r: TRegisters); stdcall;

  function GetView(const View: PKuroView): PKuroView;
  begin
    if View^.Tag = TAG_KUROWINDOW then
    begin
      exit(PKuroWindow(View^.Parent));
    end
    else
      exit(View);
  end;

var
  r_ah,
  r_al: Byte;
  Parent: PKuroObject;
  TaskBackup: PTaskStruct;
  B: PKuroButton;
  W: PKuroWindow;
  V: PKuroView;
  K: TKuroStruct;
  S: ShortString;
  i, j: LongInt;

begin
  r_ah:= (r.eax and $FF00) shr 8;
  r_al:= (r.eax and $FF);
  // We switch current task back to Kuro task. Kuro Window Objects should be
  // managed by Kuro
  TaskBackup := TaskCurrent;
  TaskCurrent := FindProcess(1);
  case r_ah of
    0:
      case r_al of
        1: // Create window
          begin
            K := PKuroStruct(r.esi)^;
            if K.Name <> nil then
              S := K.Name
            else
              S := '';
            if K.Parent <> nil then
              Parent := K.Parent
            else
              Parent := GetKuroWMInstance;
            New(W, Init(Parent));
            with W^ do
            begin
              SetPosition(K.X, K.Y);
              SetSize(K.Width, K.Height);
              IsMoveable := Boolean(K.IsMoveable);
              PID := TaskCurrent^.PID;
              Body^.SetName(S);
              Focus;
            end;
            IRQEAXHave := 1;
            IRQEAXValue := Cardinal(W^.Body);
          end;
        2: // Create button
          begin
            K := PKuroStruct(r.esi)^;
            if K.Name <> nil then
              S := K.Name
            else
              S := '';
            if K.Parent <> nil then
              Parent := K.Parent
            else
              Parent := GetKuroWMInstance;
            New(B, Init(Parent));
            with B^ do
            begin
              SetPosition(K.X, K.Y);
              SetSize(K.Width, K.Height);
              IsMoveable := Boolean(K.IsMoveable);
              PID := TaskCurrent^.PID;
              SetName(S);
            end;
            IRQEAXHave := 1;
            IRQEAXValue := Cardinal(B);
          end;
      end;
    2:
      case r_al of
        1:
          begin
            V := PKuroView(r.esi);
            if r.ecx <> 0 then
              S := PChar(r.ecx)
            else
              S := '';
            V^.SetName(S);
            V^.RenderUpdate;
          end;
      end;
    3:
      case r_al of
        1:
          begin
            V := PKuroView(r.esi);
            V := GetView(V);
            V^.Close;
          end;
      end;
    4:
      case r_al of
        1:
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
        2:
          begin
            V := PKuroView(r.esi);
            V^.ReceiveMessage(r.ebx, r.ecx, r.edx);
          end;
      end;
  end;
  TaskCurrent := TaskBackup;
end;

procedure Init; stdcall;
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing KuroWM Syscalls (0x69)... ');
  IDT.InstallHandler($69, @Int0x69.Callback);
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
