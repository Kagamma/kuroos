procedure ScanLine(X1, X2, Y: GLint; C1, C2: GLuint); overload;
var
  buf: PGLTexture;
  i: Integer;
  t: Single;
  C: GLuint;
begin
  if (Y >= glTop) and (Y < glBottom) then
  begin
    buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
    for i := X1 to X2 do
    begin
      t := (i - X1) / (X2 - X1);
      C := RGBA(
        Byte(Floor(Lerp(Byte(C1 shr 16), Byte(C2 shr 16), t))),
        Byte(Floor(Lerp(Byte(C1 shr 8), Byte(C2 shr 8), t))),
        Byte(Floor(Lerp(Byte(C1), Byte(C2), t))),
        $FF
      );
      glRasterPixelNoViewport(i, Y, C);
    end;
  end;
end;

procedure DrawBottomGouraudTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C1, C2, C3: GLuint);
var
  W1, W2, W3,
  CurX1, CurX2,
  InvSlope1,
  InvSlope2: Single;
  BC1, BC2: GLuint;
  CX1, CX2: GLint;
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

    Barycentric(CX1, i, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    ColorWeight(C1, C2, C3, W1, W2, W3, BC1);
    Barycentric(CX2, i, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    ColorWeight(C1, C2, C3, W1, W2, W3, BC2);

    ScanLine(CX1, CX2, i, BC1, BC2);
    CurX1 := CurX1 + InvSlope1;
    CurX2 := CurX2 + InvSlope2;
  end;
end;

procedure DrawTopGouraudTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C1, C2, C3: GLuint);
var
  W1, W2, W3,
  CurX1, CurX2,
  InvSlope1,
  InvSlope2: Single;
  BC1, BC2: GLuint;
  CX1, CX2: GLint;
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

    Barycentric(CX1, i, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    ColorWeight(C1, C2, C3, W1, W2, W3, BC1);
    Barycentric(CX2, i, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    ColorWeight(C1, C2, C3, W1, W2, W3, BC2);

    ScanLine(CX1, CX2, i, BC1, BC2);
    CurX1 := CurX1 - InvSlope1;
    CurX2 := CurX2 - InvSlope2;
  end;
end;

procedure glRasterGouraudTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C1, C2, C3: GLuint); stdcall;
var
  W1, W2, W3: Single;
  X4, Y4: GLint;
  C4: GLuint;
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
    Swap(C1, C2);
  end;
  if Y3 < Y1 then
  begin
    Swap(X1, X3);
    Swap(Y1, Y3);
    Swap(C1, C3);
  end;
  if Y3 < Y2 then
  begin
    Swap(X2, X3);
    Swap(Y2, Y3);
    Swap(C2, C3);
  end;
  if Y2 = Y3 then
    DrawBottomGouraudTriangle(X1, Y1, X2, Y2, X3, Y3, C1, C2, C3)
  else if Y1 = Y2 then
    DrawTopGouraudTriangle(X1, Y1, X2, Y2, X3, Y3, C1, C2, C3)
  else
  begin
    X4 := Round(X1 + ((Y2 - Y1) / (Y3 - Y1)) * (X3 - X1));
    Y4 := Y2;
    Barycentric(X4, Y4, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    ColorWeight(C1, C2, C3, W1, W2, W3, C4);
    DrawBottomGouraudTriangle(X1, Y1, X2, Y2, X4, Y4, C1, C2, C4);
    DrawTopGouraudTriangle(X2, Y2, X4, Y4, X3, Y3, C2, C4, C3);
  end;
end;