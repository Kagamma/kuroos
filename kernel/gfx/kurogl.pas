{
    File:
        kurogl.pas
    Description:
        Graphics unit compatible with OpenGL 1.x
    License:
        General Public License (GPL)
}

unit KuroGL;

{$I KOS.INC}

interface

uses
  sysutils,
  console, bios,
  ide, fat, cdfs,
  kheap,
  vbe, vga, ImageLoader;

const
  GL_TEXTURE_2D = 0;
  GL_POINTS = 1;
  GL_LINES = 2;
  GL_TRIANGLES = 3;
  GL_QUADS = 4;
  GL_BGRA8 = 32; // Need verify the actual number
  GL_FLOAT = 5;
  GL_RASTER_BUFFER_SCREEN = 6;
  GL_RASTER_TEXTURE_BUFFER = 7;
  GL_COLOR_BUFFER_BIT = 1;
  GL_DEPTH_BUFFER_BIT = 2;
  GL_TEXTURE_WIDTH = 8;
  GL_TEXTURE_HEIGHT = 9;

type
  GLshort = SmallInt;
  GLushort = Word;
  GLint = LongInt;
  GLuint = Cardinal;
  GLfloat = Single;
  GLenum = Cardinal;

  PGLshort = ^GLshort;
  PGLushort = ^GLushort;
  PGLint = ^GLuint;
  PGLuint = ^GLuint;
  PGLfloat = ^GLfloat;

  PLGLInternalVertex = ^TLGLInternalVertex;
  TLGLInternalVertex = record
    V: Single;
    C: longword;
  end;

  TGLViewport = packed record
    X1, Y1, X2, Y2: GLint;
  end;

  PLGLContext = ^TLGLContext;
  TLGLContext = packed record
    Handle        : Pointer;
    ClearColor    : GLuint;
    CurrentTexture: GLuint;
    CurrentBuffer : GLuint;
    ScreenBuffer  : GLuint;
    Viewport      : TGLViewport;
    // vertex buffer for drawing
    VertexList    : PLGLInternalVertex;
  end;

  PGLTexture = ^TGLTexture;
  TGLTexture = packed record
    Width,
    Height,
    Depth    : GLuint;
    Format   : Word;
    Dimension: Word;
    Data     : Pointer;
  end;

procedure glGenContext(AHandle: Handle; APtr: PGLuint; AWidth, AHeight, ABpp: GLuint); stdcall;
procedure glDeleteContext(APtr: GLuint); stdcall;
procedure glSetContext(APtr: GLuint); stdcall;
// Viewport based on current Buffer
procedure glViewport(X, Y: GLint; Width, Height: GLuint); stdcall;

procedure glClearColor(AColor: GLuint); stdcall;
procedure glClear(Mask: GLuint) ; stdcall;

procedure glGenTexture(APtr: PGLuint); stdcall;
procedure glTexStorage2D(ATexType, Levels, InternalFormat, Width, Height: GLuint); stdcall;
procedure glDeleteTexture(APtr: PGLuint); stdcall;
procedure glBindTexture(ATexType: GLuint; APtr: GLuint); stdcall;
procedure glBindBuffer(APtr: GLuint); stdcall;
procedure glSwapBuffers; stdcall;

//
procedure glGetTexLevelParameteriv(const Target: GLenum; const Level: GLint; const PName: GLenum; const Params: PGLint);

// procedure glLoadTextureBMPFromHD(APath: ShortString); stdcall;
procedure glLoadTexture(Format: GLuint; APath: ShortString); stdcall;

// 2D routines (not compatible with OpenGL)
// Copy current texture to buffer
procedure glRasterBlit(X, Y: GLint); stdcall;
// Copy current texture to buffer, scaled
procedure glRasterBlitScale(X, Y, Width, Height: GLint); stdcall;
// Plot a pixel to buffer
procedure glRasterPixel(X, Y: GLint; Color: GLuint); stdcall;
// Draw a line to buffer
procedure glRasterLine(X1, Y1, X2, Y2: GLint; C: GLuint); stdcall;
// Draw a filled rectangle to the buffer
procedure glRasterFlatRect(X, Y: GLint; Width, Height: GLuint; Color: GLuint); stdcall;
// Draw a filled triangle
procedure glRasterFlatTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C: GLuint); stdcall;
// Draw a gouraud triangle
procedure glRasterGouraudTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; C1, C2, C3: GLuint); stdcall;
// Draw a texture triangle
procedure glRasterTextureTriangle(X1, Y1, X2, Y2, X3, Y3: GLint; TX1, TY1, TX2, TY2, TX3, TY3: Single); stdcall;
// Draw 8x16 text to texture
procedure glRasterText(X, Y: GLint; Color: GLuint; Text: ShortString); stdcall;

// Raster with "fast" will ignore viewport and alpha
procedure glRasterBlitFast(X, Y: GLint); stdcall;

function  RGB(R, G, B: Byte): Cardinal;
function  RGBA(R, G, B, A: Byte): Cardinal;

implementation

uses
  sysfonts, math, mouse;

var
  CurrentContext_: PLGLContext;

function  RGB(R, G, B: Byte): Cardinal; assembler;
asm
    mov ah,0FFh
    mov al,R
    shl eax,16
    mov ah,G
    mov al,B
end;

function  RGBA(R, G, B, A: Byte): Cardinal; assembler;
asm
    mov ah,0FFh
    mov ah,A
    mov al,R
    shl eax,16
    mov ah,G
    mov al,B
end;

function NoAlpha(const C: GLuint): Boolean; inline;
begin
  exit(Byte(C shr 24) = 0);
end;

function glLeft: GLint; inline;
begin
  if CurrentContext_^.Viewport.X1 > 0 then
    exit(CurrentContext_^.Viewport.X1)
  else
    exit(0);
end;

function glTop: GLint; inline;
begin
  if CurrentContext_^.Viewport.Y1 > 0 then
    exit(CurrentContext_^.Viewport.Y1)
  else
    exit(0);
end;

function glRight: GLint; inline;
var
  buf: PGLTexture;
begin
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  if CurrentContext_^.Viewport.X2 < buf^.Width then
    exit(CurrentContext_^.Viewport.X2)
  else
    exit(buf^.Width);
end;

function glBottom: GLint; inline;
var
  buf: PGLTexture;
begin
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  if CurrentContext_^.Viewport.Y2 < buf^.Height then
    exit(CurrentContext_^.Viewport.Y2)
  else
    exit(buf^.Height);
end;

procedure glRasterPixelNoViewport(X, Y: GLint; Color: GLuint); stdcall; inline;
var
  buf: PGLTexture;
begin
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  if (not NoAlpha(Color))
    and (X >= glLeft)
    and (X < glRight-1)
    and (Y >= glTop)
    and (Y < glBottom-1) then
    PGLuint(buf^.Data)[Y * buf^.Width + X] := Color;
end;

procedure glGenContext(AHandle: Handle; APtr: PGLuint; AWidth, AHeight, ABpp: GLuint); stdcall;
var
  size   : Cardinal;
  context: PLGLContext;
  screen : PGLTexture;
begin
  if AHandle = nil then
  begin
    case IsGUI of
      False:
        begin
          Writeln('Initializing default KuroGL context... OK');
          Writeln;
          VBE.SetMode(AWidth, AHeight, ABpp);
          Mouse.SetBoundary(0, 0, AWidth, AHeight);
        end;
    end;
  end;
  size:= AWidth * AHeight * 32;
  context:= KHeap.Alloc(SizeOf(TLGLContext));
  context^.Handle:= AHandle;
  context^.ClearColor:= $0;

  APtr^:= GLuint(context);

  screen := PGLTexture(KHeap.Alloc(SizeOf(TGLTexture)));
  screen^.Width := AWidth;
  screen^.Height := AHeight;
  screen^.Format := GL_BGRA8;
  screen^.Depth := 2;
  screen^.Data := Pointer(VBE_VIRTUAL_LFB);//Pointer(VBE.GetCurrentMode^.Info.LFB);
  context^.ScreenBuffer := GLuint(screen);
  context^.Viewport.X1 := 0;
  context^.Viewport.Y1 := 0;
  context^.Viewport.X2 := AWidth;
  context^.Viewport.Y2 := AHeight;
end;

procedure glDeleteContext(APtr: GLuint); stdcall;
begin
  if PLGLContext(APtr)^.Handle = nil then
  begin
    VBE.SetMode(80, 25, 4);
    Mouse.SetBoundary(0, 0, VGA.GetScreenWidth, VGA.GetScreenHeight);
  end;
  KHeap_Free(PGLuint(PLGLContext(APtr)^.ScreenBuffer));
  KHeap.Free(PLGLContext(APtr));
end;

procedure glSetContext(APtr: GLuint); stdcall;
begin
  CurrentContext_:= PLGLContext(APtr);
end;

procedure glViewport(X, Y: GLint; Width, Height: GLuint); stdcall;
var
  buf: PGLTexture;
begin
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  CurrentContext_^.Viewport.X1 := X;
  CurrentContext_^.Viewport.Y1 := Y;
  CurrentContext_^.Viewport.X2 := X + Width;
  CurrentContext_^.Viewport.Y2 := Y + Height;
end;

procedure glClearColor(AColor: GLuint); stdcall;
begin
  CurrentContext_^.ClearColor:= AColor;
end;

procedure glClear(Mask: GLuint); stdcall;
var
  buf: PGLTexture;
begin
  if Mask and GL_COLOR_BUFFER_BIT > 0 then
  begin
    buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
    FillDWord(buf^.Data^, buf^.Width * buf^.Height, CurrentContext_^.ClearColor);
  end;
end;

procedure glGenTexture(APtr: PGLuint); stdcall;
var
  tex: PGLTexture;
begin
  tex:= KHeap.Alloc(SizeOf(TGLTexture));
  tex^.Data:= nil;
  APtr^:= GLuint(tex);
end;

procedure glTexStorage2D(ATexType, Levels, InternalFormat, Width, Height: GLuint); stdcall;
var
  tex: PGLTexture;
begin
  // We ignore ATexType, InternalFormat and Levels for now
  tex:= PGLTexture(CurrentContext_^.CurrentTexture);
  tex^.Width := Width;
  tex^.Height := Height;
  tex^.Dimension := 2;
  tex^.Format := InternalFormat;
  tex^.Data := KHeap.Alloc((Width * Height) shl 2);
end;

procedure glDeleteTexture(APtr: PGLuint); stdcall;
var
  tex: PGLTexture;
begin
  tex:= PGLTexture(APtr^);
  if tex^.Data <> nil then
    KHeap.Free(tex^.Data);
  KHeap.Free(tex);
  APtr^ := 0;
end;

procedure glBindTexture(ATexType: GLuint; APtr: GLuint); stdcall;
begin
  CurrentContext_^.CurrentTexture:= APtr;
end;

procedure glBindBuffer(APtr: GLuint); stdcall;
begin
  CurrentContext_^.CurrentBuffer:= APtr;
end;

// procedure glLoadTextureBMPFromHD(APath: ShortString); stdcall;
// var
//   f     : TFile;
//   buf   : PByte;
//   bmpRec: TBMPHeader;
//   i     : Cardinal = 0;
//   x,
//   y     : Word;
//   tex   : PGLTexture;
// begin
//   if NOT FAT.FileOpen(APath, @f) then
//   begin
//     FAT.FileClose(@f);
//     exit;
//   end;
//   tex:= PGLTexture(CurrentContext_^.CurrentTexture);
//   FAT.FileRead(@f, @bmpRec, SizeOf(bmpRec));
//   if bmpRec.Bits = 24 then
//   begin
//     tex^.Width    := bmpRec.Width;
//     tex^.Height   := bmpRec.Height;
//     tex^.Format      := 32;
//     tex^.Dimension:= 2;
//     tex^.Data     := KHeap.Alloc((bmpRec.Width * bmpRec.Height) shl 2);

//     buf:= KHeap.Alloc(bmpRec.BMPFileSize);
//     FAT.FileSeek(@f, bmpRec.HeaderSize);
//     FAT.FileRead(@f, buf, bmpRec.BMPFileSize - bmpRec.HeaderSize);
//     for y:= bmpRec.Height-1 downto 0 do
//     begin
//       for x:= 0 to bmpRec.Width-1 do
//       begin
//         Cardinal((tex^.Data + (((y * bmpRec.Width + x) shl 2)))^):=
//  	    RGBA(buf[i+2], buf[i+1], buf[i+0], $FF);
//         Inc(i, 3);
//       end;
//       for x:= 1 to (bmpRec.Width mod 4) do
//         Inc(i);
//     end;
//     KHeap.Free(buf);
//   end;
//   FAT.FileClose(@f);
// end;

procedure glLoadTexture(Format: GLuint; APath: ShortString); stdcall;
var
  tex: PGLTexture;
begin
  tex:= PGLTexture(CurrentContext_^.CurrentTexture);
  if ImageLoader.Load(APath, tex^.Data, tex^.Width, tex^.Height) then
  begin
    tex^.Format := Format;
    tex^.Dimension := 2;
  end;
end;

procedure glGetTexLevelParameteriv(const Target: GLenum; const Level: GLint; const PName: GLenum; const Params: PGLint);
begin
  case Target of
    GL_TEXTURE_2D:
     begin
       case PName of
         GL_TEXTURE_WIDTH:
          Params^ := PGLTexture(CurrentContext_^.CurrentTexture)^.Width;
         GL_TEXTURE_HEIGHT:
          Params^ := PGLTexture(CurrentContext_^.CurrentTexture)^.Height;
       end
     end;
  end;
end;

procedure glRasterBlit(X, Y: GLint); stdcall;
var
  tex,
  buf: PGLTexture;
  startx, starty,
  cx, cy: Integer;
  i, j,
  ClampX, ClampY,
  C: GLuint;
  X2, Y2: Integer;
  Src, Dst: Pointer;
begin
  X := X + CurrentContext_^.Viewport.X1;
  Y := Y + CurrentContext_^.Viewport.Y1;
  tex:= PGLTexture(CurrentContext_^.CurrentTexture);
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  X2 := X + tex^.Width;
  Y2 := Y + tex^.Height;
  if (X >= glRight) or (Y >= glBottom) or (X2 < glLeft) or (Y2 < glTop) then
    exit;

  ClampX := Clamp(X, glLeft, glRight);
  ClampY := Clamp(Y, glTop, glBottom);

  startx := Max(Round(Lerp(0, tex^.Width, (ClampX - X) / (X2 - X))), 0);
  starty := Max(Round(Lerp(0, tex^.Height, (ClampY - Y) / (Y2 - Y))), 0);

  X := ClampX;
  X2 := Clamp(X2, glLeft, glRight);
  Y := ClampY;
  Y2 := Clamp(Y2, glTop, glBottom);

  cy := starty;
  for j := Y to Y2-1 do
  begin
    Src := tex^.Data + ((cy*tex^.Width + startx) shl 2);
    Dst := buf^.Data + ((j*buf^.Width + X) shl 2);
    for i := X to X2-1 do
    begin
      C := PGLuint(Src)^;
      if not NoAlpha(C) then
        PGLuint(Dst)^ := C;
      Inc(Src, 4);
      Inc(Dst, 4);
    end;
    Inc(cy);
  end;
end;

procedure glRasterBlitScale(X, Y, Width, Height: GLint); stdcall;
var
  tex,
  buf: PGLTexture;
  startx, starty,
  sx, sy,
  cx, cy: Single;
  i, j,
  ClampX, ClampY,
  C: GLuint;
  X2, Y2: Integer;
  Dst: Pointer;
begin
  X := X + CurrentContext_^.Viewport.X1;
  Y := Y + CurrentContext_^.Viewport.Y1;
  X2 := X + Width;
  Y2 := Y + Height;
  if (X >= glRight) or (Y >= glBottom) or (X2 < glLeft) or (Y2 < glTop) then
    exit;
  tex:= PGLTexture(CurrentContext_^.CurrentTexture);
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);

  ClampX := Clamp(X, glLeft, glRight);
  ClampY := Clamp(Y, glTop, glBottom);

  startx := Lerp(0, tex^.Width, (ClampX - X) / (X2 - X));
  starty := Lerp(0, tex^.Height, (ClampY - Y) / (Y2 - Y));
  sx := Lerp(0, tex^.Width, 1 / (X2 - X));
  sy := Lerp(0, tex^.Height, 1 / (Y2 - Y));

  X := ClampX;
  X2 := Clamp(X2-1, glLeft, glRight-1);
  Y := ClampY;
  Y2 := Clamp(Y2-1, glTop, glBottom-1);

  cy := starty;
  for j := Y to Y2 do
  begin
    cx := startx;
    Dst := buf^.Data + ((j*buf^.Width + X) shl 2);
    for i := X to X2 do
    begin
      C := PGLuint(tex^.Data)[Round(cy) * tex^.Width + Round(cx)];
      if not NoAlpha(C) then
        PGLuint(Dst)^ := C;
      Inc(Dst, 4);
      cx := cx + sx;
    end;
    cy := cy + sy;
  end;
end;

procedure glRasterPixel(X, Y: GLint; Color: GLuint); stdcall;
var
  buf: PGLTexture;
begin
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  X := X + CurrentContext_^.Viewport.X1;
  Y := Y + CurrentContext_^.Viewport.Y1;
  if (not NoAlpha(Color))
    and (X >= glLeft)
    and (X < glRight-1)
    and (Y >= glTop)
    and (Y < glBottom-1) then
    PGLuint(buf^.Data)[Y * buf^.Width + X] := Color;
end;

procedure glRasterLine(X1, Y1, X2, Y2: GLint; C: GLuint); stdcall;
var
  X, Y, DX, DY, EInc, ENoInc, E: Integer;
begin
  X1 := X1 + CurrentContext_^.Viewport.X1;
  Y1 := Y1 + CurrentContext_^.Viewport.Y1;
  X2 := X2 + CurrentContext_^.Viewport.X1;
  Y2 := Y2 + CurrentContext_^.Viewport.Y1;
  if X2<X1 then
    Swap(X1, X2);
  if Y2<Y1 then
    Swap(Y1, Y2);
  // TODO: Optimization for horzline and vertline
  Y := Y1;
  DX := X2-X1;
  DY := Y2-Y1;
  ENoInc:= DY+DY;
  E:= ENoInc-DX;
  EInc:= E-DX;
  for X:= X1 to X2 do
  begin
    glRasterPixelNoViewport(X, Y, C);
    if E<0 then
      Inc(E, ENoInc)
    else
    begin
      Inc(Y);
      Inc(E, EInc);
    end;
  end;
end;

procedure glRasterFlatRect(X, Y: GLint; Width, Height: GLuint; Color: GLuint); stdcall;
var
  buf: PGLTexture;
  Range,
  X2, Y2,
  j: Integer;
  Data: Pointer;
begin
  X := X + CurrentContext_^.Viewport.X1;
  Y := Y + CurrentContext_^.Viewport.Y1;
  X2 := X + Width;
  Y2 := Y + Height;
  if (NoAlpha(Color)) or (X >= glRight) or (Y >= glBottom) or (X2 < glLeft) or (Y2 < glTop) then
    exit;
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);

  X := Clamp(X, glLeft, glRight);
  X2 := Clamp(X2-1, glLeft, glRight-1);
  Y := Clamp(Y, glTop, glBottom);
  Y2 := Clamp(Y2-1, glTop, glBottom-1);
  Range := Max(X2-X, 0);
  Data := buf^.Data + ((Y*buf^.Width + X) shl 2);

  for j:= Y to Y2 do
  begin
    FillDWord(Data^, Range, Color);
    Data := Data + buf^.Width shl 2;
  end;
end;

procedure Barycentric(const X, Y, X1, Y1, X2, Y2, X3, Y3: GLint; var W1, W2, W3: GLfloat); inline;
var
  t: LongInt;
begin
  t := (Y2-Y3)*(X1-X3)+(X3-X2)*(Y1-Y3);
  W1 := ((Y2-Y3)*(X-X3)+(X3-X2)*(Y-Y3)) / t;
  W2 := ((Y3-Y1)*(X-X3)+(X1-X3)*(Y-Y3)) / t;
  W3 := 1 - W1 - W2;
end;

function ColorPartWeight(const C1, C2, C3: Byte; const W1, W2, W3: GLfloat): Byte; inline;
var
  RC1, RC2, RC3, RC: GLfloat;
begin
  RC1 := C1 / 255;
  RC2 := C2 / 255;
  RC3 := C3 / 255;
  RC := (RC1*W1 + RC2*W2 + RC3*W3);
  exit(Clamp(Round(RC * 255), 0, 255));
end;

procedure ColorWeight(const C1, C2, C3: GLuint; const W1, W2, W3: GLfloat; var C: GLuint); inline;
begin
  C := RGBA(
    ColorPartWeight(Byte(C1 shr 16), Byte(C2 shr 16), Byte(C3 shr 16), W1, W2, W3),
    ColorPartWeight(Byte(C1 shr 8), Byte(C2 shr 8), Byte(C3 shr 8), W1, W2, W3),
    ColorPartWeight(Byte(C1), Byte(C2), Byte(C3), W1, W2, W3),
    $FF
  );
end;

function CoordWeight(const C1, C2, C3: GLfloat; const W1, W2, W3: GLfloat): GLfloat; inline;
begin
  exit(C1*W1 + C2*W2 + C3*W3);
end;

{$I flat.inc}
{$I gouraud.inc}
{$I texture.inc}

procedure glRasterText(X, Y: GLint; Color: GLuint; Text: ShortString); stdcall;
var
  i, j, k: Byte;
begin
  for i := 0 to Length(Text)-1 do
    for j := 0 to 15 do
      for k := 0 to 7 do
      begin
        if ((VGA_FNT8x16_DATA[Byte(Text[I+1])*16+J] shl K) and 128) <> 0 then
          glRasterPixel(X+K+I*8, Y+J, Color);
      end;
end;

procedure glRasterBlitFast(X, Y: GLint); stdcall;
var
  preLeft  : Word = 0;
  preTop   : Word = 0;
  i, j     : LongInt;
  ctxData  : Pointer;
  ctxWidth : Word;
  ctxHeight: Word;
  texData  : Pointer;
  left,
  top,
  right,
  bottom   : Word;
  buf,
  tex     : PGLTexture;
begin
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  tex:= PGLTexture(CurrentContext_^.CurrentTexture);
  case tex^.Format of
    GL_BGRA8:
      begin
        ctxData  := buf^.Data;
        ctxWidth := buf^.Width;
        ctxHeight:= buf^.Height;
        texData  := tex^.Data;

        if X < 0 then
        begin
          left:= 0;
          preLeft:= -X;
        end
        else
          left:= X;

        if Y < 0 then
        begin
          top:= 0;
          preTop:= -Y;
        end
        else
          top:= Y;

        Inc(texData, (preTop * tex^.Width + preLeft) shl 2);

        right := X + tex^.Width;
        bottom:= Y + tex^.Height;
        if right > ctxWidth then
        begin
          Inc(preLeft, right-ctxWidth);
          right:= ctxWidth;
        end;
        if bottom > ctxHeight then
          bottom:= ctxHeight;

        if (left >= right) and
          (top  >= bottom) then
          exit;

        preLeft:= preLeft shl 2;
        i:= right-left;
        for j:= top to bottom-1 do
        begin
          // for i:= left to right-1 do
          // begin
          //   Cardinal((ctxData + (j*ctxWidth + i) * 4)^) := Cardinal(texData^);
          //   Inc(texData, 4);
          // end;
          // Inc(texData, preLeft);
          Move(texData^, Pointer(ctxData + ((j*buf^.Width + left) shl 2))^, i shl 2);
          Inc(texData, preLeft + (i shl 2));
        end;
    end;
  end;
end;

procedure glSwapBuffers; stdcall;
var
  scr,
  buf: PGLTexture;
begin
  scr:= PGLTexture(CurrentContext_^.ScreenBuffer);
  buf:= PGLTexture(CurrentContext_^.CurrentBuffer);
  // TODO: We should honor alpha value
  Move(buf^.Data^, scr^.Data^, (buf^.Width * buf^.Height) shl 2);
  asm
      mov   dx,03DAh         // dl = VGA misc register #1
    @l1:
      in    al,dx            // al = value from VGA misc register #1
      test  al,8             // Is the "retrace not in progress" bit set?
      jnz   @l1              // yes, wait until the retrace isn't in progress

    @l2:
      in    al,dx            // al = value from VGA misc register #1
      test  al,8             // Is the "retrace not in progress" bit set?
      jnz   @l2
  end ['eax', 'edx'];
end;

procedure glBegin(const AMode: GLuint); stdcall;
begin

end;

procedure glEnd; stdcall;
begin

end;

procedure glVertex2i(const X, Y: integer); stdcall;
begin

end;

procedure glColor4b(const R, G, B, A: byte); stdcall;
begin

end;

end.
