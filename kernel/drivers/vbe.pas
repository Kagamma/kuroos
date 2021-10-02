{
    File:
        vbe.pas
    Description:
        VESA driver unit.
    License:
        General Public License (GPL)
}

unit vbe;

{$I KOS.INC}

interface

uses
  sysutils,
  console, bios;

type
  PVBEInfoStruct = ^TVBEInfoStruct;
  TVBEInfoStruct = packed record
    Signature   : array[0..3] of Byte;
    Version     : Word;
    OEMStringPtr: array[0..1] of Word;
    Capabilities: array[0..3] of Byte;
    VideoModePtr: array[0..1] of Word;
    TotalMemory : Word;
  end;

  PVBEModeInfoStruct = ^TVBEModeInfoStruct;
  TVBEModeInfoStruct = packed record
    Attributes : Word;
    WinA, WinB : Byte;
    Granularity: Word;
    WinSize    : Word;
    SegA, SegB : Word;
    _pad1      : Cardinal;
    Pitch      : Word;
    XRes, YRes : Word;

    Wchar, Ychar, Planes, BPP, Banks,
    MemoryModel, BankSize, ImagePages,
    _pad2,
    RedMask, RedPosition,
    GreenMask, GreenPosition,
    BlueMask, BluePosition,
    _pad3, _pad4,
    DirectColorAttributes: Byte;

    LFB         : Cardinal;
    _pad5       : Cardinal;
    _pad6       : word;
  end;

  PVBEVideoModeStruct = ^TVBEVideoModeStruct;
  TVBEVideoModeStruct = packed record
    Mode: Word;
    Info: TVBEModeInfoStruct;
  end;

var
  VBEVideoModeCount: Byte = 0;
  VBEVideoModes: array[0..63] of TVBEVideoModeStruct;

procedure Init; stdcall;
function  SetMode(const Width, Height, Bpp: Cardinal): Boolean; stdcall;
function  GetCurrentMode: PVBEVideoModeStruct; stdcall;
procedure ReturnToTextMode; stdcall;
procedure ReturnToGraphicsMode; stdcall;

implementation

uses
  vga;

var
  CurrentVBEVideoMode_: PVBEVideoModeStruct;

procedure Init; stdcall;
var
  r: TX86Registers;
  i: Cardinal;
  p: Pointer;
  vbeInfoStruct : PVBEInfoStruct;
  vbeModeInfoStruct: PVBEModeInfoStruct;
  modes         : Pointer;
begin
  Console.WriteStr('Detecting VBE controller... ');

  FillChar(r, SizeOf(TX86Registers), 0);
  FillChar(VBEVideoModes[0], Length(VBEVideoModes) * SizeOf(TVBEVideoModeStruct), 0);
  r.ax:= $4F00;
  r.es:= $1000; // Store results in address $10000
  r.di:= $0000;
  BIOS.Int(r, $10);

  if r.ax <> $4F then
  begin
    Console.WriteStr(stFailed);
    INFINITE_LOOP;
  end;

  Console.WriteStr(stOk);

  vbeInfoStruct:= Pointer($10000);

  Console.WriteStr('VBE controller information:'#10#13);
  Console.WriteStr(' - Signature: ');
  Console.WriteArrayChars(@vbeInfoStruct^.Signature, 4);
  Console.WriteStr(#10#13);
  Console.WriteStr(' - OEM      : ');
  Console.WriteStr(PChar(vbeInfoStruct^.OEMStringPtr[1] * 16 + vbeInfoStruct^.OEMStringPtr[0]));
  Console.WriteStr(#10#13);
  Console.WriteStr(' - Version  : ');
  Console.WriteDec(Byte(vbeInfoStruct^.Version shr 8), 0);
  Console.WriteStr('.');
  Console.WriteDec(Byte(vbeInfoStruct^.Version), 0);
  Console.WriteStr(#10#13);

  if vbeInfoStruct^.Version < $0200 then
  begin
    Console.WriteStr('Unsupported version. Require VBE 2.0 or above.'#10#13);
    INFINITE_LOOP;
  end;

  vbeModeInfoStruct:= Pointer($11000);
  modes            := Pointer(vbeInfoStruct^.VideoModePtr[1] * 16 + vbeInfoStruct^.VideoModePtr[0]);

  Console.WriteStr('List of suitable video modes:'#10#13);
  while Word(modes^) <> $FFFF do
  begin
    FillChar(r, SizeOf(TX86Registers), 0);
    r.ax:= $4F01;
    r.cx:= Word(modes^);
    r.es:= $1000;
    r.di:= $1000;
    BIOS.Int(r, $10);
    Inc(modes, 2);

    if r.ax <> $4F then
      continue;
    if ((vbeModeInfoStruct^.Attributes and $90) <> $90) then
      continue;
    if (vbeModeInfoStruct^.MemoryModel <> 4) and
       (vbeModeInfoStruct^.MemoryModel <> 6) then
      continue;
    if (vbeModeInfoStruct^.BPP = 32) then
    begin
      Console.WriteStr(' - Mode: 0x');
      Console.WriteHex(Word((modes-2)^), 4);
      Console.WriteStr('; Resolution: ');
      Console.WriteDec(vbeModeInfoStruct^.XRes, 0);
	    Console.WriteStr('x');
      Console.WriteDec(vbeModeInfoStruct^.YRes, 0);
	    Console.WriteStr('x');
      Console.WriteDec(vbeModeInfoStruct^.BPP, 0);
      Console.WriteStr('bpp; LFB: 0x');
      Console.WriteHex(vbeModeInfoStruct^.LFB, 8);

      Inc(VBEVideoModeCount);
      VBEVideoModes[VBEVideoModeCount - 1].Mode:= Word((modes-2)^);
      VBEVideoModes[VBEVideoModeCount - 1].Info:= vbeModeInfoStruct^;

      Console.WriteStr(#10#13);
    end;
  end;
  Console.WriteStr(#10#13);
end;

function  SetMode(const Width, Height, Bpp: Cardinal): Boolean; stdcall;
var
  r: TX86Registers;
  i: Byte;
begin
  if (Width = 80) and
     (Height = 25) and
     (Bpp = 4) then
  begin
    VBE.ReturnToTextMode;
    exit(True);
  end;
  for i:= 0 to VBEVideoModeCount-1 do
  begin
    if (VBEVideoModes[i].Info.XRes = Width) and
       (VBEVideoModes[i].Info.YRes = Height) and
       (VBEVideoModes[i].Info.BPP = Bpp) then
    begin
      Console.SaveState;
      FillChar(r, SizeOf(TX86Registers), 0);
      r.ax:= $4F02;
      r.bx:= VBEVideoModes[i].Mode or $4000;
      BIOS.Int(r, $10);

      CurrentVBEVideoMode_:= @VBEVideoModes[i];
      IsGUI:= True;
      exit(True);
    end;
  end;
  exit(False);
end;

function  GetCurrentMode: PVBEVideoModeStruct; stdcall;
begin
  exit(CurrentVBEVideoMode_);
end;

procedure ReturnToTextMode; stdcall;
var
  r: TX86Registers;
begin
  if not IsGUI then exit;
  FillChar(r, SizeOf(TX86Registers), 0);
  r.ax:= $4F02;
  r.bx:= 3;
  BIOS.Int(r, $10);
  VGA.SetMode(vga80x25x4);
  Console.LoadState;
  IsGUI:= False;
end;

procedure ReturnToGraphicsMode; stdcall;
var
  r: TX86Registers;
begin
  if IsGUI then exit;
  Console.SaveState;
  FillChar(r, SizeOf(TX86Registers), 0);
  r.ax:= $4F02;
  r.bx:= CurrentVBEVideoMode_^.Mode or $4000;
  BIOS.Int(r, $10);
  IsGUI:= True;
end;

end.
