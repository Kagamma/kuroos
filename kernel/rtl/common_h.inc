type
  TBit1  = 0..(1 shl 1)-1;
  TBit2  = 0..(1 shl 2)-1;
  TBit3  = 0..(1 shl 3)-1;
  TBit4  = 0..(1 shl 4)-1;
  TBit5  = 0..(1 shl 5)-1;
  TBit6  = 0..(1 shl 6)-1;
  TBit7  = 0..(1 shl 7)-1;
  TBit8  = 0..(1 shl 8)-1;
  TBit9  = 0..(1 shl 9)-1;
  TBit10 = 0..(1 shl 10)-1;
  TBit11 = 0..(1 shl 11)-1;
  TBit12 = 0..(1 shl 12)-1;
  TBit13 = 0..(1 shl 13)-1;
  TBit14 = 0..(1 shl 14)-1;
  TBit15 = 0..(1 shl 15)-1;
  TBit16 = 0..(1 shl 16)-1;
  TBit17 = 0..(1 shl 17)-1;
  TBit18 = 0..(1 shl 18)-1;
  TBit19 = 0..(1 shl 19)-1;
  TBit20 = 0..(1 shl 20)-1;
  TBit21 = 0..(1 shl 21)-1;
  TBit22 = 0..(1 shl 22)-1;
  TBit23 = 0..(1 shl 23)-1;
  TBit24 = 0..(1 shl 24)-1;
  TBit31 = 0..(1 shl 31)-1;

  TPoint = record
    X, Y: LongInt
  end;

  TRect = record
    Left, Top, Right, Bottom: LongInt;
  end;

  TProcEvent = procedure; stdcall;
  TCallbackEvent = procedure(Command, Long1, Long2: LongInt); stdcall;

  Handle = Pointer;

const
  BASE10_CHARACTERS: array[0..9] of Char =
    ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9');
  BASE16_CHARACTERS: array[0..15] of Char =
    ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
     'A', 'B', 'C', 'D', 'E', 'F');
  PAGE_SIZE   = 4096;

  stOK: PChar = 'OK' + #10#13;
  stFailed: PChar = 'Failed' + #10#13;

var
  __endKernel  : Cardinal; external name '__endKernel';
  PlacementAddr: Pointer = @__endKernel;
  IsPaging     : Boolean = False;
  IsGUI        : Boolean = False;

function  inb(APort: Word): Byte; stdcall;
function  inw(APort: Word): Word; stdcall;
function  inl(APort: Word): LongInt; stdcall;
procedure inb(APort: Word; var ABuf; ACount: Cardinal); stdcall;
procedure inw(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall;
procedure inl(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall;

// Set value to port

procedure outb(APort: Word; AValue: Byte); stdcall;
procedure outw(APort: Word; AValue: Word); stdcall;
procedure outl(APort: Word; AValue: LongInt); stdcall;
procedure outb(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall;
procedure outw(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall;
procedure outl(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall;
// x86 Memory handling
procedure Move(const source;var dest;count:SizeInt);
procedure FillChar(var x;count:SizeInt;value:byte); overload;
procedure FillChar(var ABuf; ACount: Cardinal; AValue: Char); overload;
procedure FillDWord(var x;count : SizeInt;value : dword);
// Misc.
function  BCDToBin(BCD: Byte): Byte;