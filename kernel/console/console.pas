{
    File:
        console.pas
    Description:
        N/A.
    License:
        General Public License (GPL)
}

unit console;

{$I KOS.INC}

interface

const
  TEXTMODE_BLANK : Byte = 32;

var
  TEXTMODE_MEMORY: PWord;

// Init console mode.
procedure Init; stdcall;
// Save current state.
procedure SaveState; stdcall;
// load saved state.
procedure LoadState; stdcall;
// Set cursor position
procedure SetCursorPos(const APosX, APosY: LongInt); stdcall;
// Set background color
procedure SetBgColor(const AColor: Byte); stdcall;
// Set foreground color
procedure SetFgColor(const AColor: Byte); stdcall;
// Get background color
function  GetBgColor: Byte; stdcall;
// Get foreground color
function  GetFgColor: Byte; stdcall;
// Put a char to the screen at position
procedure WriteCharAtPos(APosX, APosY: LongInt; const AChar: Char); stdcall;
// Write a string to the screen at position
procedure WriteAtPos(APosX, APosY: LongInt; const AString: PChar); stdcall;
// Fill the screen with #32
procedure ClearScreen; stdcall;
// Get cursor position
procedure GetCursorPos(const APosX, APosY: PLongInt); stdcall;
// Get cursor position X
function  GetCursorPosX: LongInt; stdcall;
// Get cursor position Y
function  GetCursorPosY: LongInt; stdcall;
// Scroll the screen by 1 line
procedure Scroll; stdcall;
// Put a char to the screen
procedure WriteChar(const AChar: Char); stdcall;
// Put an array of char to the screen
procedure WriteArrayChars(const APtr: Pointer; const ACount: Cardinal); stdcall;
// Write a string to the screen
procedure WriteStr(const AString: PChar); stdcall;
// Write a hex number to the screen
procedure WriteHex(const AHex, ASize: Cardinal); stdcall;
// Write a dec number to the screen (based on sysutils's convert code
procedure WriteDec(AValue: Cardinal); stdcall; overload;
// Write a dec number to the screen with a size
procedure WriteDec(const ADec, ASize: Cardinal); stdcall; overload;
// Write a hex number to the screen at position
procedure WriteHexAtPos(const APosX, APosY: LongInt; const AHex, ASize: Cardinal); stdcall;
// Write a dec number to the screen at position
procedure WriteDecAtPos(const APosX, APosY: LongInt; const ADec, ASize: Cardinal); stdcall;
// Write a string to Bochs's console
procedure Debug(const Str: PChar); stdcall;

// Buffered console - only use when memory manager is installed

implementation

uses
  schedule,
  spinlock,
  vga;

type
  TConsoleStateStruct = record
    TEXTMODE_MEMORY: PWord;
    CursorPosX     : LongInt;
    CursorPosY     : LongInt;
    ForegroundColor: Byte;
    BackgroundColor: Byte;
    Mode           : TVGAMode;
  end;

var
  savedScreenBuffer: array[0..80*50*2-1] of Byte;
  State_,
  SavedState_      : TConsoleStateStruct;

// Public

// Init console mode.
procedure Init; stdcall;
begin
  State_.TEXTMODE_MEMORY:= VGA_BANK_B8000;
  State_.CursorPosX     := 0;
  State_.CursorPosY     := 0;
  State_.ForegroundColor:= 7;
  State_.BackgroundColor:= 0;
  State_.Mode           := vga80x25x4;

  SavedState_:= State_;
  SavedState_.TEXTMODE_MEMORY:= PWord(@savedScreenBuffer[0]);

  TEXTMODE_MEMORY:= VGA_BANK_B8000;

  // Switch to 80x50 text mode.
  VGA.SetMode(State_.Mode);
end;

// Save current state.
procedure SaveState; stdcall;
begin
  SavedState_.CursorPosX     := State_.CursorPosX;
  SavedState_.CursorPosY     := State_.CursorPosY;
  SavedState_.ForegroundColor:= State_.ForegroundColor;
  SavedState_.BackgroundColor:= State_.BackgroundColor;
  SavedState_.Mode           := State_.Mode;
  Move(Pointer(TEXTMODE_MEMORY)^, Pointer(SavedState_.TEXTMODE_MEMORY)^, 8000);
end;

// load saved state.
procedure LoadState; stdcall;
begin
  State_.CursorPosX     := SavedState_.CursorPosX;
  State_.CursorPosY     := SavedState_.CursorPosY;
  State_.ForegroundColor:= SavedState_.ForegroundColor;
  State_.BackgroundColor:= SavedState_.BackgroundColor;
  State_.Mode           := SavedState_.Mode;

  VGA.SetMode(State_.Mode);
  Console.SetFgColor(State_.ForegroundColor);
  Console.SetBgColor(State_.BackgroundColor);
  Console.SetCursorPos(State_.CursorPosX, State_.CursorPosY);
  Move(Pointer(SavedState_.TEXTMODE_MEMORY)^, Pointer(TEXTMODE_MEMORY)^, 8000);
end;

// Fill the screen with #32
procedure ClearScreen; stdcall; [public, alias: 'k_Console_ClearScreen'];
var
  i         : Cardinal;
  attribute,
  oldFgColor,
  oldBgColor: Byte;
begin
  IRQ_DISABLE;
  attribute:= (State_.BackgroundColor shl 4) or (State_.ForegroundColor and $0F);
  for i:= 0 to (VGA.GetScreenWidth * VGA.GetScreenHeight)-1 do
    TEXTMODE_MEMORY[i]:= Word((attribute shl 8) or TEXTMODE_BLANK);

  oldBgColor:= Console.GetBgColor;
  oldFgColor:= Console.GetFgColor;
  Console.SetBgColor(1);
  Console.SetFgColor(15);
  for i:= 0 to VGA.GetScreenWidth-1 do
  begin
    //Console.WriteCharAtPos(i, 0, ' ');
    Console.WriteCharAtPos(i, VGA.GetScreenHeight-1, ' ');
  end;
  //Console.WriteAtPos(67, 0, '[ Kuro ]');
  Console.WriteAtPos(0, VGA.GetScreenHeight-1, '[ Kuro ]');
  Console.SetBgColor(oldBgColor);
  Console.SetFgColor(oldFgColor);

  Console.SetCursorPos(0, 0);
  IRQ_ENABLE;
end;

// Set cursor position
procedure SetCursorPos(const APosX, APosY: LongInt); stdcall; [public, alias: 'k_Console_Set_Console_cursorPos'];
var
  cursorLocation: Word;
begin
  IRQ_DISABLE;
  cursorLocation:= APosY * VGA.GetScreenWidth + APosX;
  VGA.SetCursorPos(cursorLocation);
  State_.CursorPosX:= APosX;
  State_.CursorPosY:= APosY;
  IRQ_ENABLE;
end;

// Get cursor position
procedure GetCursorPos(const APosX, APosY: PLongInt); stdcall; [public, alias: 'k_Console_Get_Console_cursorPos'];
begin
  APosX^:= State_.CursorPosX;
  APosY^:= State_.CursorPosY;
end;

// Get cursor position X
function  GetCursorPosX: LongInt; stdcall; [public, alias: 'k_Console_Get_state.CursorPosX'];
begin
  exit(State_.CursorPosX);
end;

// Get cursor position Y
function  GetCursorPosY: LongInt; stdcall; [public, alias: 'k_Console_Get_state.CursorPosY'];
begin
  exit(State_.CursorPosY);
end;

// Scroll the screen by 1 line
procedure Scroll; stdcall; [public, alias: 'k_Console_Scroll'];
var
  i        : Cardinal;
  attribute: Byte;
begin
  IRQ_DISABLE;
  if State_.CursorPosY >= VGA.GetScreenHeight-1 then
  begin
    // Copy below lines to upper lines
    attribute:= (State_.BackgroundColor shl 4) or (State_.ForegroundColor and $0F);
    for i:= 0 to (VGA.GetScreenWidth-1) * (VGA.GetScreenHeight-1) do
      TEXTMODE_MEMORY[i]:= TEXTMODE_MEMORY[i + VGA.GetScreenWidth];
    // Clear the last line
    for i:= (VGA.GetScreenHeight-2)*VGA.GetScreenWidth to (VGA.GetScreenHeight-1)*VGA.GetScreenWidth-1 do
      TEXTMODE_MEMORY[i]:= Word((attribute shl 8) or TEXTMODE_BLANK);
    State_.CursorPosY:= VGA.GetScreenHeight-2;
  end;
  IRQ_ENABLE;
end;

// Put a char to the screen
procedure WriteChar(const AChar: Char); stdcall; [public, alias: 'k_Console_WriteChar'];
var
  attribute     : Byte;
  cursorLocation: Word;
begin
  // backspace
  if (AChar = #8) and (State_.CursorPosX > 0) then
    Dec(State_.CursorPosX)
  else
  // tab (TODO:)
  if AChar = #9 then
    State_.CursorPosX:= State_.CursorPosX + 4-(State_.CursorPosX mod 4)
  else
  // return
  if AChar = #10 then
    State_.CursorPosX:= 0
  else
  // newline
  if AChar = #13 then
    Inc(State_.CursorPosY)
  else
  //if (AChar >= ' ') or (AChar in [#1..#6]) then
  begin
    cursorLocation:= State_.CursorPosY * VGA.GetScreenWidth + State_.CursorPosX;
    attribute:= (State_.BackgroundColor shl 4) or (State_.ForegroundColor and $0F);
    TEXTMODE_MEMORY[cursorLocation]:= Word((attribute shl 8) or Byte(AChar));
    Inc(State_.CursorPosX);
  end;

  if State_.CursorPosX >= VGA.GetScreenWidth then
  begin
    State_.CursorPosX:= 0;
    Inc(State_.CursorPosY);
  end;
  Console.Scroll;
  Console.SetCursorPos(State_.CursorPosX, State_.CursorPosY);
end;

// Put an array of char to the screen
procedure WriteArrayChars(const APtr: Pointer; const ACount: Cardinal); stdcall;
var
  i: Cardinal;
begin
  for i:= 0 to ACount-1 do
    Console.WriteChar(Char((APtr + i)^));
end;

// Write a string to the screen
procedure WriteStr(const AString: PChar); stdcall; [public, alias: 'k_Console_Write'];
var
  i: Cardinal;
begin
  i:= 0;
  while AString[i] <> #0 do
  begin
    Console.WriteChar(AString[i]);
    Inc(i);
  end;
end;

// Write a hex number to the screen
procedure WriteHex(const AHex, ASize: Cardinal); stdcall; [public, alias: 'k_Console_WriteHex'];
var
  buf  : array[0..8] of Char;
  str  : PChar;
  digit: Cardinal;
begin
  for digit:= 0 to 7 do
    buf[digit]:= #0;
  str  := @buf[8];
  str^ := #0;
  digit:= AHex;
  if (digit = 0) and (ASize = 0) then
    str^ := '0'
  else
    repeat
      Dec(str);
      str^ := Char(BASE16_CHARACTERS[digit mod 16]);
      digit:= digit div 16;
    until digit = 0;
  str:= @buf[0];
  if ASize = 0 then
  begin
    while str^ = #0 do
      Inc(str);
  end
  else
  begin
    while str^ = #0 do
    begin
      str^:= '0';
      Inc(str);
    end;
    str:= @buf[8] - ASize;
  end;
  Console.WriteStr(str);
end;

procedure WriteDec(AValue: Cardinal); stdcall; [public, alias: 'k_Console_WriteDec2'];
var
  buf : array[0..11] of Char;
  p, i: LongInt;
begin
  if AValue = 0 then
    Console.WriteChar('0')
  else
  begin
    p:= High(buf);
    buf[p]:= #0;
    while AValue > 0 do
    begin
      Dec(p);
      buf[p]:= BASE10_CHARACTERS[AValue mod 10];
      AValue:= AValue div 10;
    end;
    for i:= p to High(buf) do
      Console.WriteChar(buf[i]);
  end;
end;

// Write a dec number to the screen
procedure WriteDec(const ADec, ASize: Cardinal); stdcall; [public, alias: 'k_Console_WriteDec'];
var
  buf  : array[0..12] of Char;
  str  : PChar;
  digit: Cardinal;
begin
  for digit:= 0 to 11 do
    buf[digit]:= #0;
  str  := @buf[12];
  str^ := #0;
  digit:= ADec;
  if (digit = 0) and (ASize = 0) then
    str^ := '0'
  else
    repeat
      Dec(str);
      str^ := Char(BASE10_CHARACTERS[digit mod 10]);
      digit:= digit div 10;
    until digit = 0;
  str:= @buf[0];
  if ASize = 0 then
  begin
    while str^ = #0 do
      Inc(str);
  end
  else
  begin
    while str^ = #0 do
    begin
      str^:= '0';
      Inc(str);
    end;
    str:= @buf[12] - ASize;
  end;
  Console.WriteStr(str);
end;

// Put a char to the screen at position
procedure WriteCharAtPos(APosX, APosY: LongInt; const AChar: Char); stdcall; [public, alias: 'k_Console_WriteCharAtPos'];
var
  attribute     : Byte;
  cursorLocation: Word;
begin
  // backspace
  if (AChar = #8) and (APosX > 0) then
    Dec(APosX)
  else
  // tab (TODO:)
  if AChar = #9 then
    APosX:= APosX+1
  else
  // return
  if AChar = #10 then
    APosX:= 0
  else
  // newline
  if AChar = #13 then
    Inc(APosY)
  else
  if AChar >= ' ' then
  begin
    cursorLocation:= APosY * VGA.GetScreenWidth + APosX;
    attribute:= (State_.BackgroundColor shl 4) or (State_.ForegroundColor and $0F);
    TEXTMODE_MEMORY[cursorLocation]:= Word((attribute shl 8) or Byte(AChar));
    Inc(APosX);
  end;
end;

// Write a string to the screen at position
procedure WriteAtPos(APosX, APosY: LongInt; const AString: PChar); stdcall; [public, alias: 'k_Console_WriteAtPos'];
var
  i: Cardinal;
begin
  i:= 0;
  while AString[i] <> #0 do
  begin
    Console.WriteCharAtPos(APosX, APosY, AString[i]);
    Inc(i);
    Inc(APosX);
  end;
end;

// Write a hex number to the screen at position
procedure WriteHexAtPos(const APosX, APosY: LongInt; const AHex, ASize: Cardinal); stdcall; [public, alias: 'k_Console_WriteHexAtPos'];
var
  buf  : array[0..8] of Char;
  str  : PChar;
  digit: Cardinal;
begin
  for digit:= 0 to 7 do
    buf[digit]:= #0;
  str  := @buf[8];
  str^ := #0;
  digit:= AHex;
  repeat
    Dec(str);
    str^ := Char(BASE16_CHARACTERS[digit mod 16]);
    digit:= digit div 16;
  until digit = 0;
  str:= @buf[0];
  if ASize = 0 then
  begin
    while str^ = #0 do
      Inc(str);
  end
  else
  begin
    while str^ = #0 do
    begin
      str^:= '0';
      Inc(str);
    end;
    str:= @buf[8] - ASize;
  end;
  Console.WriteAtPos(APosX, APosY, str);
end;

// Write a dec number to the screen at position
procedure WriteDecAtPos(const APosX, APosY: LongInt; const ADec, ASize: Cardinal); stdcall; [public, alias: 'k_Console_WriteDecAtPos'];
var
  buf  : array[0..12] of Char;
  str  : PChar;
  digit: Cardinal;
begin
  for digit:= 0 to 11 do
    buf[digit]:= #0;
  str  := @buf[12];
  str^ := #0;
  digit:= ADec;
  repeat
    Dec(str);
    str^ := Char(BASE10_CHARACTERS[digit mod 10]);
    digit:= digit div 10;
  until digit = 0;
  str:= @buf[0];
  if ASize = 0 then
  begin
    while str^ = #0 do
      Inc(str);
  end
  else
  begin
    while str^ = #0 do
    begin
      str^:= '0';
      Inc(str);
    end;
    str:= @buf[12] - ASize;
  end;
  Console.WriteAtPos(APosX, APosY, str);
end;

// Set background color
procedure SetBgColor(const AColor: Byte); stdcall; [public, alias: 'k_Console_SetBgColor'];
begin
  State_.BackgroundColor:= AColor;
end;

// Set foreground color
procedure SetFgColor(const AColor: Byte); stdcall; [public, alias: 'k_Console_SetFgColor'];
begin
  State_.ForegroundColor:= AColor;
end;

// Get background color
function  GetBgColor: Byte; stdcall; [public, alias: 'k_Console_GetBgColor'];
begin
  exit(State_.BackgroundColor);
end;

// Get foreground color
function  GetFgColor: Byte; stdcall; [public, alias: 'k_Console_GetFgColor'];
begin
  exit(State_.ForegroundColor);
end;

procedure Debug(const Str: PChar); stdcall;
var
  i: Cardinal;
begin
  i := 0;
  while Str[i] <> #0 do
  begin
    outb($E9, Byte(Str[i]));
    Inc(i);
  end;
end;

end.
