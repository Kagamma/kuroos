constructor TKuroBody.Init(const AParent: PKuroObject);
begin
  inherited;
  Tag := TAG_KUROWINDOW;
  Self.SetName('Window');
end;

procedure TKuroButton.SetSize(const AWidth, AHeight: Cardinal);
var
  Len: LongInt;
begin
  inherited;
  Len := Length(Name) * 8 div 2;
  TextX := AWidth div 2 - Len;
  TextY := AHeight div 2 - 8;
end;

procedure TKuroButton.SetName(const AName: PChar);
var
  Len: LongInt;
begin
  inherited;
  SetSize(Width, Height);
end;

procedure TKuroButton.Render;
var
  PX, PY: LongInt;
begin
  if IsMouseDown then
  begin
    BgColor := $FF404040;
    BgColorSelected := $FF404040;
  end
  else
  begin
    BgColor := $FF808080;
    BgColorSelected := $FF808080;
  end;
  inherited;
  GetRealPosition(PX, PY);
  glViewport(PX, PY, Width, Height);
  glRasterText(TextX, TextY, $FF000000, Name);
end;

procedure TKuroCloseButton.Callback(const M: PKuroMessage);
var
  CM: TKuroMessage;
  i: Integer;
begin
  if (M^.Command = KM_MOUSEUP) and (Boolean(M^.LoShort1 and $01)) and IsFocused then
  begin
    CM.Command := KM_CLOSE;
    PKuroWindow(Parent)^.Body^.TransferMessage(@CM);
  end;
  inherited;
end;

procedure TKuroCloseButton.Render;
var
  PX, PY: LongInt;
begin
  if IsMouseDown then
  begin
    BgColor := $FF404040;
    BgColorSelected := $FF404040;
  end
  else
  begin
    BgColor := $FF808080;
    BgColorSelected := $FF808080;
  end;
  inherited;
  GetRealPosition(PX, PY);
  glViewport(PX, PY, Width, Height);
  glRasterText(7, Y, $FF000000, 'x');
end;

constructor TKuroWindow.Init(const AParent: PKuroObject);
begin
  inherited;
  New(Body, Init(@Self));
  New(BtnClose, Init(@Self));

  Body^.BgColor := $FF808080;
  Body^.BgColorSelected := $FFA0A0A0;
  Body^.X := 0;
  Body^.Y := 25;

  BtnClose^.BgColor := $FF808080;
  BtnClose^.BgColorSelected := $FF808080;
  BtnClose^.Y := 3;
  BtnClose^.Width := 21;
  BtnClose^.Height := 21;
end;

destructor TKuroWindow.Done;
begin
  inherited;
end;

procedure TKuroWindow.Callback(const M: PKuroMessage);
begin
  Body^.PID := PID;
  if IsFocused then
    Body^.IsFocused := true;
  inherited;
end;

procedure TKuroWindow.Render;
var
  PX, PY: LongInt;
begin
  inherited;
  GetRealPosition(PX, PY);
  glViewport(PX, PY, Width, Height);
  glRasterText(10, 6, $FFFFFFFF, Body^.Name);
end;

procedure TKuroWindow.SetPosition(const AX, AY: LongInt);
begin
  inherited;
end;

procedure TKuroWindow.SetSize(const AWidth, AHeight: Cardinal);
begin
  inherited;
  Self.Height := AHeight + 25;
  Body^.SetSize(AWidth, AHeight);
  BtnClose^.X := AWidth - 26;
end;

constructor TKuroImage.Init(const AParent: PKuroObject);
begin
  inherited;
  Self.Buffer := 0;
end;

destructor TKuroImage.Done;
begin
  if Self.Buffer <> 0 then
  begin
    glDeleteTexture(@Self.Buffer);
  end;
  inherited;
end;

procedure TKuroImage.Render;
var
  PX, PY: LongInt;
begin
  if Self.Buffer <> 0 then
  begin
    glBindTexture(GL_TEXTURE_2D, Self.Buffer);
    GetRealPosition(PX, PY);
    glViewport(PX, PY, Width, Height);
    glRasterBlit(0, 0);
  end;
  Self.IsRenderUpdate := False;
end;

procedure TKuroImage.SetImage(const AName: PChar);
begin
  Self.ReceiveMessage(KM_IMAGE_LOAD, LongWord(AName), 0);
end;

procedure TKuroImage.ProcessMessages(const M: PKuroMessage; const IsChild: Boolean);
var
  i: Integer;
  V: PKuroView;
  FileName: PChar;
begin
  // Process parent's message
  case M^.Command of
    KM_IMAGE_LOAD:
      begin;
        FileName := PChar(M^.LoLong);
        if Self.Buffer <> 0 then
        begin
          glDeleteTexture(@Self.Buffer);
        end;
        glGenTexture(@Self.Buffer);
        glBindTexture(GL_TEXTURE_2D, Self.Buffer);
        IRQ_ENABLE;
        glLoadTexture(GL_BGRA8, FileName);
        IRQ_DISABLE;
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, @Self.Width);
        glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, @Self.Height);
        Self.RenderUpdate;
        Free(FileName);
      end;
  end;
  inherited;
end;