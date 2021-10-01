{
    File:
        vga.pas
    Description:
        VGA driver unit.
    License:
        General Public License (GPL)
}

unit vga;

{$I KOS.INC}

interface

const
  VGA_MISCREAD_REG  = $3C2;
  VGA_MISCWRITE_REG = $3C2;
  VGA_SEQ_REG  = $3C4;
  VGA_GFX_REG  = $3CE;
  VGA_CRT_REG  = $3D4;

  VGA_SEQ_INDEX_RESET    = $00;
  VGA_SEQ_INDEX_CLOCK    = $01;
  VGA_SEQ_INDEX_MAPMASK  = $02;
  VGA_SEQ_INDEX_CHARMAP  = $03;
  VGA_SEQ_INDEX_MEMMODE  = $04;

  VGA_GFX_INDEX_RESET    = $00;
  VGA_GFX_INDEX_ENABLE   = $01;
  VGA_GFX_INDEX_COLORCMP = $02;
  VGA_GFX_INDEX_ROTATE   = $03;
  VGA_GFX_INDEX_READMAP  = $04;
  VGA_GFX_INDEX_MODE     = $05;
  VGA_GFX_INDEX_MISC     = $06;
  VGA_GFX_INDEX_CNOCARE  = $07;
  VGA_GFX_INDEX_BITMASK  = $08;

  VGA_CRT_INDEX_SCANLINE = $09;
  VGA_CRT_INDEX_RETRACESTART = $0A;

  VGA_BANK_B0000: PWord = PWord($B0000);
  VGA_BANK_B8000: PWord = PWord($B8000);
  VGA_BANK_A0000: PWord = PWord($A0000);

type
  TVGAMode = (vga80x25x4, vga80x50x4);

function  ReadRegister(const AReg: Word; const AIndex: Byte): Byte; stdcall;
procedure WriteRegister(const AReg: Word; const AIndex, AValue: Byte); stdcall;

procedure SetMode(const AMode: TVGAMode); stdcall;
procedure SetFont(const ABuf: PByte; const AGlyph: Byte); stdcall;

procedure SetCursorPos(const ALinearAddr: Word); stdcall;

// Get screen width
function  GetScreenWidth: Word; stdcall;
// Get screen height
function  GetScreenHeight: Word; stdcall;

implementation

uses
  sysfonts;

var
  _screenWidth : Word;
  _screenHeight: Word;

// Public

function  ReadRegister(const AReg: Word; const AIndex: Byte): Byte; stdcall; inline;
begin
  outb(AReg, AIndex);
  exit(inb(AReg + $01));
end;

procedure WriteRegister(const AReg: Word; const AIndex, AValue: Byte); stdcall; inline;
begin
  outb(AReg, AIndex);
  outb(AReg + $01, AValue);
end;

procedure SetMode(const AMode: TVGAMode); stdcall; [public, alias: 'VGA.SetMode'];
begin
  case AMode of
    vga80x25x4:
      begin
	      _screenWidth := 80;
        _screenHeight:= 25;
        VGA.WriteRegister(VGA_CRT_REG, VGA_CRT_INDEX_SCANLINE, $0F);
        VGA.WriteRegister(VGA_CRT_REG, VGA_CRT_INDEX_RETRACESTART, $0E);
        VGA.SetFont(@VGA_FNT8x16_DATA, 16);
      end;
    vga80x50x4:
      begin
	      _screenWidth := 80;
        _screenHeight:= 50;
        VGA.WriteRegister(VGA_CRT_REG, VGA_CRT_INDEX_SCANLINE, $07);
        VGA.WriteRegister(VGA_CRT_REG, VGA_CRT_INDEX_RETRACESTART, $07);
        VGA.SetFont(@VGA_FNT8x8_DATA, 8);
      end;
  end;
  VGA.WriteRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_CLOCK, $00);
end;

procedure SetFont(const ABuf: PByte; const AGlyph: Byte); stdcall; [public, alias: 'VGA.SetFont'];
var
  seq2, seq4,
  gfx5, gfx6: Byte;
  i, j      : Cardinal;
  mem       : PByte;
begin
  // Backup default registers.
  seq2:= VGA.ReadRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_MAPMASK);
  seq4:= VGA.ReadRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_MEMMODE);
  gfx5:= VGA.ReadRegister(VGA_GFX_REG, VGA_GFX_INDEX_MODE);
  gfx6:= VGA.ReadRegister(VGA_GFX_REG, VGA_GFX_INDEX_MISC);

  VGA.WriteRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_CHARMAP, $00);
  VGA.WriteRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_MAPMASK, $04);
  VGA.WriteRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_MEMMODE, $06);
  VGA.WriteRegister(VGA_GFX_REG, VGA_GFX_INDEX_MODE, $00);
  VGA.WriteRegister(VGA_GFX_REG, VGA_GFX_INDEX_MISC, $0C);

  mem:= PByte(VGA_BANK_B8000);

  for j:= 0 to 255 do
  begin
    for i:= 0 to AGlyph-1 do
    begin
      mem[i]:= ABuf[AGlyph * j + i];
    end;
    Inc(mem, 32);
  end;

  // Restore default registers.
  VGA.WriteRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_MAPMASK, seq2);
  VGA.WriteRegister(VGA_SEQ_REG, VGA_SEQ_INDEX_MEMMODE, seq4);
  VGA.WriteRegister(VGA_GFX_REG, VGA_GFX_INDEX_MODE, gfx5);
  VGA.WriteRegister(VGA_GFX_REG, VGA_GFX_INDEX_MISC, gfx6);
end;

procedure SetCursorPos(const ALinearAddr: Word); stdcall; [public, alias: 'VGA.SetCursorPos'];
begin
  VGA.WriteRegister(VGA_CRT_REG, 14, Byte(ALinearAddr shr 8));
  VGA.WriteRegister(VGA_CRT_REG, 15, Byte(ALinearAddr));
end;

// Get screen width
function  GetScreenWidth: Word; stdcall; inline;
begin
  exit(_screenWidth);
end;

// Get screen height
function  GetScreenHeight: Word; stdcall; inline;
begin
  exit(_screenHeight);
end;

end.
