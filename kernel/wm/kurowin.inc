constructor TKuroBody.Init(const AParent: PKuroObject);
begin
  inherited;
  Tag := TAG_KUROWINDOW;
  Name := 'Window';
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

procedure TKuroButton.SetName(const AName: ShortString);
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
  Dispose(Body, Done);
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
  Body^.SetSize(AWidth, AHeight - 25);
  BtnClose^.X := AWidth - 26;
end;