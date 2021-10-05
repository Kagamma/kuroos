unit ImageLoader;

interface

uses
  sysutils,
  console, bios,
  ide, fat, cdfs,
  kheap;

type
  TBMPHeader = packed record
    ID              : array[0..1] of Byte;
    BMPFileSize     : LongInt;
    Reserved        : LongInt;
    HeaderSize      : LongInt;
    InfoSize        : LongInt;
    Width,
    Height          : LongInt;
    biPlanes,
    Bits            : Word;
    biCompression,
    biSizeImage,
    biXPelsPerMeter,
    biYPelsPerMeter,
    biClrUsed,
    biClrImportant  : LongInt;
  end;

function Load(const APath: String; var ABuffer: Pointer; var AWidth, AHeight: Cardinal): Boolean;

implementation

uses
  kurogl;

function Load(const APath: String; var ABuffer: Pointer; var AWidth, AHeight: Cardinal): Boolean;
var
  p     : Pointer;
  buf   : PByte;
  bmpRec: TBMPHeader;
  i     : Cardinal = 0;
  x,
  y     : Word;
  tex   : PGLTexture;
begin
  p := CDFSObj^.Loader(IDE.FindDrive(True), APath);
  if Assigned(p) then
  begin
    Move(p^, bmpRec, SizeOf(bmpRec));
    AWidth  := bmpRec.Width;
    AHeight := bmpRec.Height;
    ABuffer := KHeap.Alloc((bmpRec.Width * bmpRec.Height) shl 2);
    buf := p + SizeOf(bmpRec);
    case bmpRec.Bits of
      24:
        begin
          for y:= AHeight-1 downto 0 do
          begin
            for x:= 0 to AWidth-1 do
            begin
              Cardinal((ABuffer + (((y * AWidth + x) shl 2)))^):=
                  RGBA(buf[i+2], buf[i+1], buf[i], $FF);
              Inc(i, 3);
            end;
            for x:= 1 to (AWidth mod 4) do
              Inc(i);
          end;
        end;
      32:
        begin
          for y:= AHeight-1 downto 0 do
          begin
            for x:= 0 to AWidth-1 do
            begin
              Cardinal((ABuffer + (((y * AWidth + x) shl 2)))^):=
                  RGBA(buf[i+2], buf[i+1], buf[i], buf[i+3]);
              Inc(i, 4);
            end;
            for x:= 1 to (AWidth mod 4) do
              Inc(i);
          end;
        end;
    end;
    KHeap.Free(p);
    exit(true);
  end;
  exit(false);
end;

end.