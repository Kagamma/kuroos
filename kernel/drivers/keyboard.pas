{
    File:
        keyboard.pas
    Description:
        Keyboard driver unit.
    License:
        General Public License (GPL)
}

unit keyboard;

{$I KOS.INC}

interface

uses
  console,
  idt;

type
  TKeyMap = array [0..127] of Char;
  PKeyBuffer = ^TKeyBuffer;
  TKeyBuffer = array [0..255] of Char;
  TKeyStatus = (ksCtrl, ksAlt, ksShift, ksCapsLock, ksNumLock, ksScrollLock);
  TKeyStatusSet = set of TKeyStatus;

procedure Callback(r: TRegisters); stdcall;
procedure ClearBuffer; stdcall;
procedure GetBuffer(p: PKeyBuffer); stdcall;
// Get keyboard's last input and mask as got.
function  GetLastKeyStroke: Byte; stdcall;
function  GetLastKeyReleased: Byte; stdcall;
function  GetKeyStatus: TKeyStatusSet; stdcall;
function  IsBufferFull: Boolean; stdcall;
procedure Init; stdcall;
function IsEvent: Boolean; stdcall;

implementation

uses
  vga;

const
  USKeyMap: TKeyMap = (
    #00, // 0
    #27, // 1 - Esc
    '1','2','3','4','5','6','7','8','9','0','-','=', // 13
    #08, // 14 - Backspace
    #09, // 15 - Tab
    'q','w','e','r','t','y','u','i','o','p','[',']', // 27
    #10, // 28 - Enter
    #00, // 29 - Ctrl
    'a','s','d','f','g','h','j','k','l',';', // 39
    '''', // 40 - '
    '`', // 41
    #00, // 42 - Left Shift
    '\','z','x','c','v','b','n','m',',','.','/', // 53
    #00, // 54 - Right Shift
    '*', // 55
    #00, // 56 - Alt
    ' ', // 57 - Space bar
    #0,  // 58 - Caps lock
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 59 - F1 up to 68 - F10
    #0, // 69 - Num lock}
    #0, // Scroll Lock
    #0, // Home key
    #0, // Up Arrow
    #0, // Page Up
    '-',
    #0, // Left Arrow
    #0,
    #0, // Right Arrow
    '+',
    #0, // 79 - End key
    #0, // Down Arrow
    #0, // Page Down
    #0, // Insert Key
    #0, // Delete Key
    #0,#0,#0, // 86
    #0, // F11 Key
    #0, // F12 Key
    #0, // All other keys are undefined
    #0, // 90
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 100
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 110
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 120
    #0,#0,#0,#0,#0,#0,#0 // 127
  );

  ShiftedUSKeyMap: TKeyMap = (
    #00, // 0
    #27, // 1 - Esc
    '!','@','#','$','%','^','&','*','(',')','_','+', // 13
    #08, // 14 - Backspace
    #09, // 15 - Tab
    'Q','W','E','R','T','Y','U','I','O','P','{','}', // 27
    #10, // 28 - Enter
    #00, // 29 - Ctrl
    'A','S','D','F','G','H','J','K','L',':', // 39
    '"', // 40 - '
    '~', // 41
    #00, // 42 - Left Shift
    '|','Z','X','C','V','B','N','M','<','>','?', // 53
    #00, // 54 - Right Shift
    '*', // 55 - Numpad *
    #00, // 56 - Alt
    ' ', // 57 - Space bar
    #0, // 58 - Caps lock
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 59 - F1 up to 68 - F10
    #0, // 69 - Num lock
    #0, // Scroll Lock
    // 71 - 83 are numpad keys
    #0, // Home key (7)
    #0, // Up Arrow (8)
    #0, // Page Up (9)
    '-',
    #0, // Left Arrow (4)
    #0, // (5)
    #0, // Right Arrow (6)
    '+',
    #0, // End key (1)
    #0, // Down Arrow (2)
    #0, // Page Down (3)
    #0, // Insert Key (0)
    #0, // Delete Key (.)
    // end of numpad keys
    #0,#0,#0, // 86
    #0, // F11 Key
    #0, // F12 Key
    // All other keys are undefined
    #0,#0, // 90
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 100
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 110
    #0,#0,#0,#0,#0,#0,#0,#0,#0,#0, // 120
    #0,#0,#0,#0,#0,#0,#0 // 127
  );

var
  _keyBuffer    : TKeyBuffer;
  _keyReleaseBuffer: TKeyBuffer;
  _keyBufferPtr : PChar;
  _keyReleaseBufferPtr: PChar;
  _keyStatus    : TKeyStatusSet = [];
  _keyBufferFull: Boolean = False;
  _HasKeyStroke : Boolean = False;
  _HasKeyRelease: Boolean = False;
  _IsEvent      : Boolean = false;

function IsEvent: Boolean; stdcall;
begin
  IsEvent := _IsEvent;
  _IsEvent := false;
end;

procedure Callback(r: TRegisters); stdcall;
var
  i,
  scanCode: Byte;
  c       : Char;
begin
  scanCode:= inb($60);
  if (scanCode and $80) = 0 then
  begin
    case scanCode of
      42, 54: // Left/Right shift is pressed
        _keyStatus:= _keyStatus + [ksShift];
      else
      begin
        if ksShift in _keyStatus then
          c:= ShiftedUSKeyMap[scanCode]
        else
          c:= USKeyMap[scanCode];
        case c of
          #8: // Backspace
            begin
	            if (Cardinal(_keyBufferPtr - @_keyBuffer[0]) <= 255) then
              begin
                _HasKeyStroke:= True;
                _keyBufferPtr^:= c;
                Inc(_keyBufferPtr);
              end
              else
              _keyBufferFull:= True;
                end;
              #10: // Enter
                begin
                  if (Cardinal(_keyBufferPtr - @_keyBuffer[0]) <= 255) then
                  begin
                    _HasKeyStroke:= True;
                    _keyBufferPtr^:= c;
                    Inc(_keyBufferPtr);
                  end
              else
              _keyBufferFull:= True;
                end
              else
                begin
                  if (Cardinal(_keyBufferPtr - @_keyBuffer[0]) <= 255) then
                  begin
                    _HasKeyStroke:= True;
                    _keyBufferPtr^:= c;
                    Inc(_keyBufferPtr);
                  end
              else
              _keyBufferFull:= True;
            end;
        end;
      end;
    end;
  end
  else
  begin
    scanCode:= scanCode and not $80;
    case scanCode of
      42, 54: // Left/Right shift is released
        _keyStatus:= _keyStatus - [ksShift];
      else
        begin
          if (Cardinal(_keyReleaseBufferPtr - @_keyReleaseBuffer[0]) <= 255) then
          begin
            c:= USKeyMap[scanCode];
            _HasKeyRelease:= True;
            _keyReleaseBufferPtr^:= c;
            Inc(_keyReleaseBufferPtr);
          end;
        end;
    end;
  end;
  _IsEvent := true;
end;

procedure ClearBuffer; stdcall;
begin
  IRQ_DISABLE;

  _keyBufferPtr:= @_keyBuffer[0];
  FillChar(_keyBuffer[0], 256, 0);
  _keyBufferFull:= False;

  _keyReleaseBufferPtr:= @_keyReleaseBuffer[0];
  FillChar(_keyReleaseBuffer[0], 256, 0);

  IRQ_ENABLE;
end;

procedure GetBuffer(p: PKeyBuffer); stdcall; [public, alias: 'k_Keyboard_GetBuffer'];
begin
  p^:= _keyBuffer;
end;

function  GetLastKeyStroke: Byte; stdcall;
begin
  if _keyBufferPtr <> @_keyBuffer[0] then
  begin
    if _HasKeyStroke then
    begin
      _HasKeyStroke:= False;
      exit(Byte((_keyBufferPtr-1)^));
    end;
  end;
  exit(0);
end;

function  GetLastKeyReleased: Byte; stdcall;
begin
  if _keyReleaseBufferPtr <> @_keyReleaseBuffer[0] then
  begin
    if _HasKeyRelease then
    begin
      _HasKeyRelease:= False;
      exit(Byte((_keyReleaseBufferPtr-1)^));
    end;
  end;
  exit(0);
end;

function  GetKeyStatus: TKeyStatusSet; stdcall;
begin
  exit(_keyStatus);
end;

function  IsBufferFull: Boolean; stdcall;
begin
  exit(_keyBufferFull);
end;

procedure Init; stdcall; [public, alias: 'k_Keyboard_Init'];
begin
  IRQ_DISABLE;

  Console.WriteStr('Installing PS/2 Keyboard driver (0x21)... ');
  inb($60);
  IDT.InstallHandler($21, @Keyboard.Callback);
  inb($60);
  outb($21, (inb($21) and $FD));
  inb($60);
  Keyboard.ClearBuffer;
  Console.WriteStr(stOK);

  IRQ_ENABLE;
end;

end.
