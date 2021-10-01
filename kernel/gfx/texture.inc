procedure ScanLine(X1, X2, Y: GLint; TX1, TY1, TX2, TY2: GLfloat); overload;
var
  tex,
  buf: PGLTexture;
  i: Integer;
  t, TX, TY: GLfloat;
  C: GLuint;
  CTX, CTY: GLint;
begin
  if (Y >= glTop) and (Y < glBottom) then
  begin
    buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
    tex:= PGLTexture(CurrentContext_^.CurrentTexture);
    for i := X1 to X2 do
    begin
      t := (i - X1) / (X2 - X1);
      TX := Lerp(TX1, TX2, t);
      TY := Lerp(TY1, TY2, t);
      CTX := Clamp(Round(TX * tex^.Width), 0, tex^.Width);
      CTY := Clamp(Round(TY * tex^.Height), 0, tex^.Height);
      C := PGLuint(tex^.Data)[tex^.Width * CTY + CTX];
      glRasterPixelNoViewport(i, Y, C);
    end;
  end;
end;

procedure DrawBottomTextureTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; TX1, TY1, TX2, TY2, TX3, TY3: GLfloat);
var
  W1, W2, W3,
  CurX1, CurX2,
  InvSlope1,
  InvSlope2: Single;
  CTX1, CTY1, CTX2, CTY2: GLfloat;
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
    CTX1 := CoordWeight(TX1, TX2, TX3, W1, W2, W3);
    CTY1 := CoordWeight(TY1, TY2, TY3, W1, W2, W3);
    Barycentric(CX2, i, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    CTX2 := CoordWeight(TX1, TX2, TX3, W1, W2, W3);
    CTY2 := CoordWeight(TY1, TY2, TY3, W1, W2, W3);

    ScanLine(CX1, CX2, i, CTX1, CTY1, CTX2, CTY2);
    CurX1 := CurX1 + InvSlope1;
    CurX2 := CurX2 + InvSlope2;
  end;
end;

procedure DrawTopTextureTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; TX1, TY1, TX2, TY2, TX3, TY3: GLfloat);
var
  W1, W2, W3,
  CurX1, CurX2,
  InvSlope1,
  InvSlope2: Single;
  CTX1, CTY1, CTX2, CTY2: GLfloat;
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
    CTX1 := CoordWeight(TX1, TX2, TX3, W1, W2, W3);
    CTY1 := CoordWeight(TY1, TY2, TY3, W1, W2, W3);
    Barycentric(CX2, i, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    CTX2 := CoordWeight(TX1, TX2, TX3, W1, W2, W3);
    CTY2 := CoordWeight(TY1, TY2, TY3, W1, W2, W3);

    ScanLine(CX1, CX2, i, CTX1, CTY1, CTX2, CTY2);
    CurX1 := CurX1 - InvSlope1;
    CurX2 := CurX2 - InvSlope2;
  end;
end;

procedure glRasterTextureTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; TX1, TY1, TX2, TY2, TX3, TY3: GLfloat); stdcall;
var
  W1, W2, W3: Single;
  X4, Y4: GLint;
  TX4, TY4: GLfloat;
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
    Swap(TX1, TX2);
    Swap(TY1, TY2);
  end;
  if Y3 < Y1 then
  begin
    Swap(X1, X3);
    Swap(Y1, Y3);
    Swap(TX1, TX3);
    Swap(TY1, TY3);
  end;
  if Y3 < Y2 then
  begin
    Swap(X2, X3);
    Swap(Y2, Y3);
    Swap(TX2, TX3);
    Swap(TY2, TY3);
  end;
  if Y2 = Y3 then
    DrawBottomTextureTriangle(X1, Y1, X2, Y2, X3, Y3, TX1, TY1, TX2, TY2, TX3, TY3)
  else if Y1 = Y2 then
    DrawTopTextureTriangle(X1, Y1, X2, Y2, X3, Y3, TX1, TY1, TX2, TY2, TX3, TY3)
  else
  begin
    X4 := Round(X1 + ((Y2 - Y1) / (Y3 - Y1)) * (X3 - X1));
    Y4 := Y2;
    Barycentric(X4, Y4, X1, Y1, X2, Y2, X3, Y3, W1, W2, W3);
    TX4 := CoordWeight(TX1, TX2, TX3, W1, W2, W3);
    TY4 := CoordWeight(TY1, TY2, TY3, W1, W2, W3);
    DrawBottomTextureTriangle(X1, Y1, X2, Y2, X4, Y4, TX1, TY1, TX2, TY2, TX4, TY4);
    DrawTopTextureTriangle(X2, Y2, X4, Y4, X3, Y3, TX2, TY2, TX4, TY4, TX3, TY3);
  end;
end;