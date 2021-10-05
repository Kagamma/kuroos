{
    File:
        kurowm.pas
    Description:
        Kuro Window Manager.
    License:
        General Public License (GPL)
}

unit KuroWM;

{$I KOS.INC}

interface

uses
  kurogl, objects, vga, vbe, console,
  mouse, keyboard, sysutils, int0x69;

const
  KM_NONE = $0;
  KM_KEYUP = $10;
  KM_KEYDOWN = $20;
  KM_MOUSEUP = $30;
  KM_MOUSEDOWN = $40;
  KM_MOUSESCROLL = $50;
  KM_MOUSEMOVE = $60;
  KM_PAINT = $70;
  KM_CLOSE = $80;

  TAG_KUROWM = $6900;
  TAG_KUROVIEW = $6910;
  TAG_KUROWINDOW = $6920;

type
  TMouseEvent = TMouseStruct;
  TKeyboardEvent = record
    KeyBuffer: TKeyBuffer;
    KeyPressed: Byte;
    KeyReleased: Byte;
    KeyStatus: TKeyStatusSet;
  end;

  PKuroEvent = ^TKuroEvent;
  TKuroEvent = record
    Mouse: TMouseEvent;
    MouseOld: TMouseEvent;
    Keyboard: TKeyboardEvent;
  end;

  PKuroMessage = ^TKuroMessage;
  TKuroMessage = packed record
    Command: LongWord;
    case Byte of
      0: (
        Payload: Int64;
      );
      1: (
        LoLong: LongInt;
        HiLong: LongInt;
      );
      2: (
        LoShort1: SmallInt;
        HiShort1: SmallInt;
        LoShort2: SmallInt;
        HiShort2: SmallInt;
      );
  end;

  PKuroWM = ^TKuroWM;
  PKuroView = ^TKuroView;

  PKuroObject = ^TKuroObject;
  TKuroObject = object(TList)
    PID: Cardinal;
    Pipe: Pointer;
    constructor Init;
    destructor Done; virtual;
  end;

  TKuroWM = object(TKuroObject)
    BackBuffer,
    CursorTexture,
    CursorBackTexture,
    WallpaperTexture: GLuint;
    GLContext: GLuint;
    E: TKuroEvent;
    FocusedView: PKuroView;
    IsCleared: Boolean;
    IsRenderUpdate: Boolean;
    IsMoved: Boolean;
    Width, Height: Cardinal;

    constructor Init;
    destructor Done; virtual;
    procedure ProcessMessages;
    procedure ClearScreen;
    procedure TextMode;
    procedure GraphicsMode;
    // Move focused view on top
    procedure ChangeFocus(AView: PKuroView);
  end;

  TCallbackFunc = procedure(const Sender: PKuroObject; const M: PKuroMessage);

  TKuroView = object(TKuroObject)
    X, Y: LongInt;
    Width, Height: Cardinal;
    Color: Cardinal;
    MouseX: LongInt;
    MouseY: LongInt;
    MouseXOld: LongInt;
    MouseYOld: LongInt;
    IsFocused: Boolean;
    IsMoveable: Boolean;
    IsMoveBlocked: Boolean;
    IsMouseDown: Boolean;
    IsRenderUpdate: Boolean;
    IsCanBeSelected: Boolean;
    IsClosed: Boolean;
    IsChildPriority: Boolean;
    BgColorSelected,
    BgColor,
    BorderColor: Cardinal;
    Parent: PKuroObject;
    Name: PChar;
    NameSize: LongWord;
    MessagesSent,
    MessagesReceived: array[0..63] of TKuroMessage;
    MessageSentCount,
    MessageReceivedCount: Integer;
    OnCallback: TCallbackFunc;

    constructor Init(const AParent: PKuroObject);
    destructor Done; virtual;
    procedure ProcessMessages(const M: PKuroMessage; const IsChild: Boolean); virtual;
    procedure Render; virtual;
    // Focus this object
    procedure Focus; virtual;
    // Blur this object and its children
    procedure Blur; virtual;
    // Destroy this object and its children
    procedure Close; virtual;
    function IsSelected(M: PKuroMessage): Boolean; virtual;
    // Transfer message to user's pipeline
    procedure Callback(const M: PKuroMessage); virtual;
    procedure TransferMessage(const M: PKuroMessage);
    procedure TransferMessageWithCallback(const M: PKuroMessage; const IsChild: Boolean);
    // Get message (call by user)
    function  SendMessage(var Command, Param1, Param2: LongInt): Boolean;
    // Receive message (sent from user)
    procedure ReceiveMessage(const Command, Param1, Param2: LongInt);
    procedure RenderUpdate;
    procedure SetPosition(const AX, AY: LongInt); virtual;
    procedure GetRealPosition(var AX, AY: LongInt); virtual;
    procedure SetSize(const AWidth, AHeight: Cardinal); virtual;
    procedure SetName(const AName: PChar); virtual;
  end;

  {$I kurowin_h.inc}

function GetKuroWMInstance: PKuroWM;

implementation

uses
  math, cdfs, schedule, ide, kheap;

var
  Kuro: PKuroWM = nil;

function GetKuroWMInstance: PKuroWM;
begin
  exit(Kuro);
end;

constructor TKuroObject.Init;
begin
  inherited;
  PID := TaskCurrent^.PID;
end;

destructor TKuroObject.Done;
var
  i: Integer;
begin
  // Free all childs
  for i := 0 to Count-1 do
    Dispose(PKuroObject(Items[i]), Done);
  inherited;
end;

constructor TKuroWM.Init;
var
  W, H: GLint;
  WallpaperTextureScaled: GLuint;
begin
  inherited;

  Keyboard.ClearBuffer;
  Int0x69.Init;

  Width := 800;
  Height := 600;
  glGenContext(nil, @GLContext, Width, Height, 32);
  glSetContext(GLContext);

  glClearColor($FF000040);

  glGenTexture(@BackBuffer);
  glBindTexture(GL_TEXTURE_2D, BackBuffer);
  glTexStorage2D(GL_TEXTURE_2D, 1, GL_BGRA8, Width, Height);
  glBindBuffer(BackBuffer);

  glGenTexture(@WallpaperTexture);
  glBindTexture(GL_TEXTURE_2D, WallpaperTexture);
  glLoadTexture(GL_BGRA8, 'noire.bmp');

  glBindTexture(GL_TEXTURE_2D, Self.WallpaperTexture);
  glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, @W);
  glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, @H);
  if (W <> Width) or (H <> Height) then
  begin
    // Scale up/down wallpaper in case it doesn't fit the screen
    glGenTexture(@WallpaperTextureScaled);
    glBindTexture(GL_TEXTURE_2D, WallpaperTextureScaled);
    glTexStorage2D(GL_TEXTURE_2D, 1, GL_BGRA8, Width, Height);
    glBindBuffer(WallpaperTextureScaled);
    glBindTexture(GL_TEXTURE_2D, Self.WallpaperTexture);
    glRasterBlitScale(0, 0, Width, Height);
    glDeleteTexture(Self.WallpaperTexture);
    Self.WallpaperTexture := WallpaperTextureScaled;
    glBindBuffer(BackBuffer);
  end;

  glGenTexture(@CursorTexture);
  glBindTexture(GL_TEXTURE_2D, CursorTexture);
  glLoadTexture(GL_BGRA8, 'cursor.bmp');

  Self.CursorBackTexture := 0;

  FocusedView := nil;
  IsRenderUpdate := true;
  IsMoved := false;
  Kuro := @Self;
  Tag := TAG_KUROWM;
end;

destructor TKuroWM.Done;
begin
  glDeleteTexture(WallpaperTexture);
  glDeleteTexture(CursorTexture);
  glDeleteTexture(BackBuffer);
  glDeleteContext(GLContext);

  Console.SetBgColor(0);
  Console.SetFgColor(7);
  Writeln('Back to Text Mode!');
  inherited;
end;

procedure TKuroWM.TextMode;
begin
  IsGUI := False; // ProcessMessages will set text mode
end;

procedure TKuroWM.GraphicsMode;
begin
  VBE.ReturnToGraphicsMode;
  Mouse.SetBoundary(0, 0, Width, Height);
  ProcessMessages;
end;

var
  ii: Cardinal = 0;

procedure TKuroWM.ProcessMessages;
var
  i, j: Integer;
  V: PKuroView;
  Messages: array[0..31] of TKuroMessage;
  M: PKuroMessage;
  MCount: Integer;
  CW, CH: GLint;
  W: ShortInt;
  IsKeyEvent, IsMouseEvent: Boolean;
  p: Pointer;
begin
  while IsGUI do
  begin
    IRQ_DISABLE;
    IsCleared := false;
    IsKeyEvent := Keyboard.IsEvent;
    IsMouseEvent := Mouse.IsEvent;
    if IsKeyEvent or IsMouseEvent or IsRenderUpdate then
    begin
      MCount := 0;

      FillChar(Messages[0], Length(Messages) * SizeOf(TKuroMessage), 0);

      // glBindTexture(GL_TEXTURE_2D, WallpaperTexture);
      // glRasterBlitFast(0, 0);

      Mouse.GetState(@E.Mouse);
      Keyboard.GetBuffer(@E.Keyboard.KeyBuffer);
      E.Keyboard.KeyStatus := Keyboard.GetKeyStatus;
      E.Keyboard.KeyPressed := Keyboard.GetLastKeyStroke;
      E.Keyboard.KeyReleased := Keyboard.GetLastKeyReleased;

      // Trick to force the manager to check message
      // We need a better way to check child's incoming messages from user
      Inc(MCount);
      M := @Messages[MCount - 1];
      M^.Command := KM_NONE;

      if IsKeyEvent then
      begin
        W := E.Keyboard.KeyPressed;
        if W <> 0 then
        begin
          Inc(MCount);
          M := @Messages[MCount - 1];
          M^.Command := KM_KEYDOWN;
          M^.LoShort1 := W;
          IsRenderUpdate := true;
        end;
        W := E.Keyboard.KeyReleased;
        if W <> 0 then
        begin
          Inc(MCount);
          M := @Messages[MCount - 1];
          M^.Command := KM_KEYUP;
          M^.LoShort1 := W;
          IsRenderUpdate := true;
        end;
      end;

      if IsMouseEvent then
      begin
        if E.Mouse.IsMouseDown then
        begin
          Inc(MCount);
          M := @Messages[MCount - 1];
          M^.Command := KM_MOUSEDOWN;
          M^.LoShort1 := E.Mouse.MouseButton;
          M^.LoShort2 := E.Mouse.X;
          M^.HiShort2 := E.Mouse.Y;
          IsRenderUpdate := true;
        end;
        if E.Mouse.IsMouseUp then
        begin
          Inc(MCount);
          M := @Messages[MCount - 1];
          M^.Command := KM_MOUSEUP;
          M^.LoShort1 := E.Mouse.MouseButton;
          M^.LoShort2 := E.Mouse.X;
          M^.HiShort2 := E.Mouse.Y;
          IsRenderUpdate := true;
        end;
        if E.Mouse.IsMouseMove then
        begin
          Inc(MCount);
          M := @Messages[MCount - 1];
          M^.Command := KM_MOUSEMOVE;
          M^.LoShort1 := E.Mouse.MouseButton;
          M^.LoShort2 := E.Mouse.X;
          M^.HiShort2 := E.Mouse.Y;
         // IsRenderUpdate := true;
        end;
      end;

      // Paint should come last
      Inc(MCount);
      M := @Messages[MCount - 1];
      M^.Command := KM_PAINT;

      for j := 0 to MCount - 1 do
      begin
        for i := Count-1 downto 0 do
        begin
          V := Items[i];
          M := @Messages[j];
          V^.IsMoveBlocked := false;
          V^.ProcessMessages(M, true);
          if V^.IsRenderUpdate then
            IsRenderUpdate := true;
          // Look for task, if it's not available, clean up window
          if V^.IsClosed or (FindProcess(V^.PID) = nil) then
          begin
            Delete(i);
            Dispose(V, Done);
          end;
        end;
      end;

      if Self.CursorBackTexture <> 0 then
      begin
        // Restore surface under mouse cursor
        glBindTexture(GL_TEXTURE_2D, Self.CursorBackTexture);
        glRasterBlitFast(Self.E.MouseOld.X, Self.E.MouseOld.Y);
      end;
      // Redraw views
      if IsRenderUpdate then
      begin
        ClearScreen;
        for i := 0 to Count-1 do
        begin
          V := Items[i];
          V^.Render;
        end;
      end;
      glViewport(0, 0, Self.Width, Self.Height);
      // First time we handle kurowm
      if Self.CursorBackTexture = 0 then
      begin
        glBindTexture(GL_TEXTURE_2D, Self.CursorTexture);
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, @CW);
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, @CH);
        // Generate back buffer for cursor
        glGenTexture(@Self.CursorBackTexture);
        glBindTexture(GL_TEXTURE_2D, Self.CursorBackTexture);
        glTexStorage2D(GL_TEXTURE_2D, 1, GL_BGRA8, CW, CH);
        // Backup the area behind cursor
        glBindBuffer(Self.CursorBackTexture);
        glBindTexture(GL_TEXTURE_2D, Self.BackBuffer);
        glRasterBlitFast(-Self.E.Mouse.X, -Self.E.Mouse.Y);
        // Draw cursor first time
        glBindBuffer(Self.BackBuffer);
        glBindTexture(GL_TEXTURE_2D, Self.CursorTexture);
        glRasterBlit(Self.E.Mouse.X, Self.E.Mouse.Y);
      end else
      begin
        // Save new surface under mouse cursor
        glBindBuffer(Self.CursorBackTexture);
        glBindTexture(GL_TEXTURE_2D, Self.BackBuffer);
        glRasterBlitFast(-Self.E.Mouse.X, -Self.E.Mouse.Y);
        // Draw mouse
        glBindBuffer(Self.BackBuffer);
        glBindTexture(GL_TEXTURE_2D, Self.CursorTexture);
        glRasterBlit(Self.E.Mouse.X, Self.E.Mouse.Y);
      end;
      if IsRenderUpdate or IsMouseEvent then
      begin
        glSwapBuffers;
        IsRenderUpdate := false;
        Self.E.MouseOld.X := Self.E.Mouse.X;
        Self.E.MouseOld.Y := Self.E.Mouse.Y;
      end;
      Keyboard.ClearBuffer;
    end;
    IRQ_ENABLE;
    CPU_HALT;
  end;
  VBE.ReturnToTextMode;
  Mouse.SetBoundary(0, 0, VGA.GetScreenWidth, VGA.GetScreenHeight);
  Writeln('Back to Text Mode!');
end;

procedure TKuroWM.ChangeFocus(AView: PKuroView);
var
  i: Integer;
begin
  // We move the focused view to the top
  i := IndexOf(AView);
  if (i >= 0) and (i < Count-1) then
  begin
    Delete(i);
    Add(AView);
  end;
end;

procedure TKuroWM.ClearScreen;
begin
  if not IsCleared then
  begin
    if WallpaperTexture <> 0 then
    begin
      glBindTexture(GL_TEXTURE_2D, WallpaperTexture);
      glRasterBlitFast(0, 0);
    end
    else
      glClear(GL_COLOR_BUFFER_BIT);
    IsCleared := true;
  end;
end;

constructor TKuroView.Init(const AParent: PKuroObject);
begin
  inherited Init;
  IsFocused := false;
  IsRenderUpdate := true;
  Kuro^.IsRenderUpdate := true;
  IsMoveable := false;
  IsClosed := false;
  IsMouseDown := false;
  IsChildPriority := false;
  IsCanBeSelected := true;
  Parent := AParent;
  AParent^.Add(@Self);
  Tag := TAG_KUROVIEW;
  BgColor := $FF401000;
  BgColorSelected := $FF806000;
  BorderColor := $FF000000;
  Self.Name := nil;
  Self.NameSize := 0;
  Self.SetName('View');
  FillChar(MessagesSent[0], SizeOf(TKuroMessage) * Length(MessagesSent), 0);
  FillChar(MessagesReceived[0], SizeOf(TKuroMessage) * Length(MessagesReceived), 0);
  MessageSentCount := 0;
  MessageReceivedCount := 0;
  OnCallback := nil;
end;

destructor TKuroView.Done;
begin
  if Self.Name <> nil then
    FreeMem(Self.Name);
  inherited;
end;

procedure TKuroView.Render;
var
  i: Integer;
  V: PKuroView;
  PX, PY: LongInt;
begin
  // TODO: We should guard against unecesarry draw
  GetRealPosition(PX, PY);
  glViewport(PX, PY, Width, Height);
  if not IsFocused then
  begin
    glRasterFlatRect(0, 0, Width, Height, BgColor);
  end
  else
  begin
    glRasterFlatRect(0, 0, Width, Height, BgColorSelected);
  end;
  glRasterFlatRect(0, 0, Width, 2, BorderColor);
  glRasterFlatRect(Width-3, 0, 3, Height, BorderColor);
  glRasterFlatRect(0, Height-2, Width, 2, BorderColor);
  glRasterFlatRect(0, 0, 3, Height, BorderColor);
  IsRenderUpdate := false;
  // Process child
  for i := Count-1 downto 0 do
  begin
    V := Items[i];
    V^.Render;
  end;
end;

// Check against other View to see if this one is the one selected
function TKuroView.IsSelected(M: PKuroMessage): Boolean;
var
  i: Integer;
  V: PKuroView;
  XX, YY,
  VX, VY,
  X1, Y1, X2, Y2: Integer;
begin
  if Parent^.Tag <> TAG_KUROWM then
  begin
    if not PKuroView(Parent)^.IsFocused then
      exit(false);
  end;
  GetRealPosition(X1, Y1);
  XX := M^.LoShort2;
  YY := M^.HiShort2;
  X2 := X1 + Width;
  Y2 := Y1 + Height;
  for i := Parent^.Count - 1 downto 0 do
  begin
    V := Parent^.Items[i];
    if V = @Self then
    begin
      exit(IsCanBeSelected and InRect(XX, YY, X1, Y1, X2, Y2));
    end
    else
    begin
      V^.GetRealPosition(VX, VY);
      if V^.IsCanBeSelected and InRect(XX, YY, VX, VY, VX + V^.Width, VY + V^.Height) then
      begin
        exit(false);
      end
    end;
  end;
end;

procedure TKuroView.Callback(const M: PKuroMessage);
begin
  if OnCallback <> nil then
    OnCallback(@Self, M);
end;

procedure TKuroView.ProcessMessages(const M: PKuroMessage; const IsChild: Boolean);
var
  i: Integer;
  V: PKuroView;
  IsMouseLeft: Boolean;
begin
  // Process parent's message
  case M^.Command of
    KM_MOUSEDOWN:
      begin;
        if IsSelected(M) then
        begin
          Focus;
          MouseX := M^.LoShort2;
          MouseY := M^.HiShort2;
          IsMouseLeft := Boolean(M^.LoShort1 and $01);
          if (not IsMouseDown) and (IsMouseLeft) then
          begin
            MouseXOld := M^.LoShort2;
            MouseYOld := M^.HiShort2;
            if (not Kuro^.IsMoved) and (not IsMoveBlocked) then
              IsMouseDown := true;
          end;
          // BLock parent's moveable ability
          if (Parent^.Tag <> TAG_KUROWM) and not Kuro^.IsMoved then
          begin
            PKuroView(Parent)^.IsMouseDown := false;
            PKuroView(Parent)^.IsMoveBlocked := true;
          end;
        end;
        if IsSelected(M) and (not Kuro^.IsMoved) then
        begin
          TransferMessageWithCallback(M, IsChild);
        end;
      end;
    KM_MOUSEUP:
      begin;
        if not IsSelected(M) then
        begin
          Blur;
        end;
        IsMouseDown := false;
        Kuro^.IsMoved := false;
        TransferMessageWithCallback(M, IsChild);
      end;
    KM_MOUSEMOVE:
      begin;
        if IsSelected(M) then
        begin
          MouseX := M^.LoShort2;
          MouseY := M^.HiShort2;
          TransferMessageWithCallback(M, IsChild);
        end;
        // Move the view and it's child around
        if IsMouseDown and IsMoveable then
        begin
          Kuro^.IsMoved := true;
          X := X + M^.LoShort2 - MouseXOld;
          Y := Y + M^.HiShort2 - MouseYOld;
          MouseXOld := M^.LoShort2;
          MouseYOld := M^.HiShort2;
        //  IsRenderUpdate := true;
        end;
      end;
    KM_KEYDOWN:
      begin
        if (IsFocused) and (not IsChildPriority) then
        begin
          TransferMessageWithCallback(M, IsChild);
        end;
      end;
    KM_KEYUP:
      begin
        if (IsFocused) and (not IsChildPriority) then
        begin
          TransferMessageWithCallback(M, IsChild);
        end;
      end;
  end;
  Callback(M);
  if IsChild then
  begin
    for i := Count-1 downto 0 do
    begin
      V := Items[i];
      V^.IsMoveBlocked := false;
      V^.ProcessMessages(M, IsChild);
      if V^.IsClosed then
      begin
        Delete(i);
        Dispose(V, Done);
      end;
    end;
  end;
  // Process incoming messages from user
  if IsChild then
  begin
    if MessageReceivedCount > 0 then
    begin
      while MessageReceivedCount > 0 do
      begin
        ProcessMessages(@MessagesReceived[0], false);
        Dec(MessageReceivedCount);
        //
        if MessageReceivedCount > 0 then
          Move(MessagesReceived[1], MessagesReceived[0], MessageReceivedCount * SizeOf(TKuroMessage));
      end;
    end;
  end;
end;

procedure TKuroView.Focus;
begin
  if Kuro^.IsMoved then
    exit;
  // If this was the child, do not blur the parent
  if (Kuro^.FocusedView <> nil) and (PKuroObject(Kuro^.FocusedView) <> Parent) then
  begin
    Kuro^.FocusedView^.Blur;
  end
  else
  begin
    PKuroView(Kuro^.FocusedView)^.IsChildPriority := true;
  end;
  Kuro^.FocusedView := @Self;
  IsFocused := true;
  IsRenderUpdate := true;
  Kuro^.ChangeFocus(@Self);
end;

procedure TKuroView.Blur;
var
  i: Integer;
begin
  IsFocused := false;
  IsChildPriority := false;
  IsRenderUpdate := true;
  if Kuro^.FocusedView = @Self then
    Kuro^.FocusedView := nil;
  for i := 0 to Count-1 do
    PKuroView(Items[i])^.Blur;
end;

procedure TKuroView.Close;
begin
  Blur;
  IsClosed := true;
  Kuro^.IsRenderUpdate := true;
end;

procedure TKuroView.TransferMessage(const M: PKuroMessage);
var
  CM: PKuroMessage;
begin
  if (PID <> 0) and (IsFocused) and (not IsChildPriority) then
  begin
    if MessageSentCount < Length(MessagesSent)-1 then
    begin
      CM := @MessagesSent[MessageSentCount];
      CM^.Command := M^.Command;
      CM^.LoLong  := M^.LoLong;
      CM^.HiLong  := M^.HiLong;
      Inc(MessageSentCount);
    end;
  end;
end;

procedure TKuroView.TransferMessageWithCallback(const M: PKuroMessage; const IsChild: Boolean);
var
  CM: PKuroMessage;
begin
  if not IsChild then
    exit;
  if (PID <> 0) and (IsFocused) and (not IsChildPriority) then
  begin
    if MessageSentCount < Length(MessagesSent)-1 then
    begin
      CM := @MessagesSent[MessageSentCount];
      CM^ := M^;
      Inc(MessageSentCount);
    end;
  end;
end;

function  TKuroView.SendMessage(var Command, Param1, Param2: LongInt): Boolean;
begin
  if MessageSentCount > 0 then
  begin
    Command := MessagesSent[0].Command;
    Param1 := MessagesSent[0].LoLong;
    Param2 := MessagesSent[0].HiLong;
    Dec(MessageSentCount);
    //
    if MessageSentCount > 0 then
      Move(MessagesSent[1], MessagesSent[0], MessageSentCount * SizeOf(TKuroMessage));
    SendMessage := true;
  end
  else
    SendMessage := false;
end;

procedure TKuroView.ReceiveMessage(const Command, Param1, Param2: LongInt);
var
  CM: PKuroMessage;
begin
  if (PID <> 0) and (IsFocused) then
  begin
    if MessageReceivedCount < Length(MessagesReceived)-1 then
    begin
      CM := @MessagesReceived[MessageReceivedCount];
      CM^.Command := Command;
      CM^.LoLong  := Param1;
      CM^.HiLong  := Param2;
      Inc(MessageReceivedCount);
    end;
  end;
end;

procedure TKuroView.RenderUpdate;
begin
  IsRenderUpdate := true;
  Kuro^.IsRenderUpdate := true;
end;

procedure TKuroView.SetPosition(const AX, AY: LongInt);
begin
  X := AX;
  Y := AY;
end;

procedure TKuroView.SetSize(const AWidth, AHeight: Cardinal);
begin
  Width := AWidth;
  Height := AHeight;
end;

procedure TKuroView.GetRealPosition(var AX, AY: LongInt);
begin
  if Parent^.Tag <> TAG_KUROWM then
  begin
    PKuroView(Parent)^.GetRealPosition(AX, AY);
    AX := X + AX;
    AY := Y + AY;
  end
  else
  begin
    AX := X;
    AY := Y;
  end;
end;

procedure TKuroView.SetName(const AName: PChar);
var
  Len: Integer;
begin
  if AName = nil then
  begin
    if Self.Name <> nil then
    begin
      FreeMem(Self.Name);
      Self.NameSize := 0;
      Self.Name := nil;
    end;
  end else
  begin
    Len := Length(AName) + 1;
    if Self.Name <> nil then
    begin
      // Only reallocate memory if old size is smaller than new size
      if Self.NameSize < Len then
      begin
        FreeMem(Self.Name);
        GetMem(Self.Name, Len);
        Self.NameSize := Len;
      end;
    end else
      GetMem(Self.Name, Len);
    Move(AName[0], Self.Name[0], Len);
  end;
end;

{$I kurowin.inc}

end.