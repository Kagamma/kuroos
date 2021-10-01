procedure ScanLine(X1, X2, Y: GLint; C: GLuint); overload;
var
  buf: PGLTexture;
  i: Integer;
begin
  if (Y >= glTop) and (Y < glBottom) then
  begin
    buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
    FillDWord(Pointer(buf^.Data + ((Y*buf^.Width + X1) shl 2))^, X2 - X1, C);
  end;
end;

procedure DrawBottomFlatTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C: GLuint);
var
  CurX1, CurX2,
  InvSlope1,
  InvSlope2: Single;
  CX1, CX2: Integer;
  i: Integer;
begin
  InvSlope1 := (X2 - X1) / (Y2 - Y1);
  InvSlope2 := (X3 - X1) / (Y3 - Y1);

  CurX1 := X1;
  CurX2 := X1;

  for i := Y1 to Y2 do
  begin
    CX1 := Round(CurX1);
    CX2 := Round(CurX2);

    if CX1 > CX2 then
      Swap(CX1, CX2);

    CX1 := Clamp(CX1, glLeft, glRight);
    CX2 := Clamp(CX2, glLeft, glRight);
    ScanLine(CX1, CX2, i, C);
    CurX1 := CurX1 + InvSlope1;
    CurX2 := CurX2 + InvSlope2;
  end;
end;

procedure DrawTopFlatTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C: GLuint);
var
  CurX1, CurX2,
  InvSlope1,
  InvSlope2: Single;
  CX1, CX2: Integer;
  i: Integer;
begin
  InvSlope1 := (X3 - X1) / (Y3 - Y1);
  InvSlope2 := (X3 - X2) / (Y3 - Y2);

  CurX1 := X3;
  CurX2 := X3;

  for i := Y3 downto Y1 do
  begin
    CX1 := Round(CurX1);
    CX2 := Round(CurX2);

    if CX1 > CX2 then
      Swap(CX1, CX2);

    CX1 := Clamp(CX1, glLeft, glRight);
    CX2 := Clamp(CX2, glLeft, glRight);
    ScanLine(CX1, CX2, i, C);
    CurX1 := CurX1 - InvSlope1;
    CurX2 := CurX2 - InvSlope2;
  end;
end;

procedure glRasterFlatTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C: GLuint); stdcall;
var
  X4, Y4: GLint;
begin
  X1 := X1 + CurrentContext_^.Viewport.X1;
  Y1 := Y1 + CurrentContext_^.Viewport.Y1;
  X2 := X2 + CurrentContext_^.Viewport.X1;
  Y2 := Y2 + CurrentContext_^.Viewport.Y1;
  X3 := X3 + CurrentContext_^.Viewport.X1;
  Y3 := Y3 + CurrentContext_^.Viewport.Y1;
  if Y2 < Y1 then
  begin
    Swap(X1, X2);
    Swap(Y1, Y2);
  end;
  if Y3 < Y1 then
  begin
    Swap(X1, X3);
    Swap(Y1, Y3);
  end;
  if Y3 < Y2 then
  begin
    Swap(X2, X3);
    Swap(Y2, Y3);
  end;
  if Y2 = Y3 then
    DrawBottomFlatTriangle(X1, Y1, X2, Y2, X3, Y3, C)
  else if Y1 = Y2 then
    DrawTopFlatTriangle(X1, Y1, X2, Y2, X3, Y3, C)
  else
  begin
    X4 := Round(X1 + ((Y2 - Y1) / (Y3 - Y1)) * (X3 - X1));
    Y4 := Y2;
    DrawBottomFlatTriangle(X1, Y1, X2, Y2, X4, Y4, C);
    DrawTopFlatTriangle(X2, Y2, X4, Y4, X3, Y3, C);
  end;
end;