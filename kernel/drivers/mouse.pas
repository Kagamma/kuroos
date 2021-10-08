{
    File:
        mouse.pas
    Description:
        PS/2 mouse driver unit.
    License:
        General Public License (GPL)
}

// Ref: http://wiki.osdev.org/Mouse_Input

unit mouse;

{$I KOS.INC}

interface

uses
  console,
  idt;

type
  PMouseStruct = ^TMouseStruct;
  TMouseStruct = record
    IsMouseMove: Boolean;
    IsMouseDown: Boolean;
    IsMouseUp  : Boolean;
    MouseButton: Byte;
    X, Y  : Integer;
    Left,
    Right,
    Middle: Boolean;
  end;

procedure WriteRegister(const AValue: Byte); stdcall;
function  ReadRegister: Byte; stdcall;
procedure Callback(r: TRegisters); stdcall;
procedure Init; stdcall;
procedure SetResolution(const R: Byte); stdcall;
procedure SetBoundary(const Left, Top, Right, Bottom: Word); stdcall;
procedure GetState(const p: PMouseStruct); stdcall;
function IsEvent: Boolean; stdcall;

implementation

uses
  vga;

// Private

var
  _mouseCycle   : Byte;
  _mousePacket  : array[0..2] of ShortInt;
  _storedAttrib : Byte = $17 xor $77; // Store the current position's attribute.
  _mouseState   : TMouseStruct;
  _mouseBoundary: TRect;
  _IsEvent      : Boolean = False;

function IsEvent: Boolean; stdcall;
begin
  IsEvent := _IsEvent;
  _IsEvent := False;
end;

function  Wait(const AType: Byte): Boolean; stdcall;
var
  timeOut: Cardinal = $1000;
begin
  case AType of
    0:
      begin
        while TimeOut > 0 do
        begin
          if (inb($64) and 1) = 1 then
            exit(True);
          Dec(TimeOut);
        end;
      end;
    else
      begin
        while TimeOut > 0 do
          begin
            if (inb($64) and 2) = 0 then
              exit(True);
            Dec(TimeOut);
          end;
      end;
  end;
  exit(False);
end;

procedure WriteRegister(const AValue: Byte); stdcall; inline;
begin
  Mouse.Wait(1);
  // Tell the mouse we are sending a command.
  outb($64, $D4);
  Mouse.Wait(1);
  // Write what we need to port $60.
  outb($60, AValue);
end;

function  ReadRegister: Byte; stdcall; inline;
begin
  Mouse.Wait(0);
  exit(inb($60));
end;

// Public

procedure Callback(r: TRegisters); stdcall;
var
  attrib         : Byte;
  oldPosX,
  oldPosY,
  oldLocation,
  currentLocation: Cardinal;
begin
  case _mouseCycle of
    0:
      begin
	      _mousePacket[0]:= inb($60);
	      Inc(_mouseCycle);
      end;
    1:
      begin
	      _mousePacket[1]:= inb($60);
	      Inc(_mouseCycle);
      end;
    2:
      begin
        _mousePacket[2]:= inb($60);

        oldPosX:= _mouseState.X;
        oldPosY:= _mouseState.Y;

        if _mouseState.IsMouseUp then
          _mouseState.IsMouseUp := False;
        if (_mousePacket[1] <> 0) or (_mousePacket[2] <> 0) then
          _mouseState.IsMouseMove := True
        else
          _mouseState.IsMouseMove := False;

        _mouseState.Left  := Boolean(_mousePacket[0] and $01);
        _mouseState.Right := Boolean(_mousePacket[0] and $02);
        _mouseState.Middle:= Boolean(_mousePacket[0] and $04);

        if (not _mouseState.Left) and (not _mouseState.Right) and (not _mouseState.Middle) and _mouseState.IsMouseDown then
        begin
          _mouseState.IsMouseUp := True;
           _mouseState.IsMouseDown := False;
        end;
        if _mouseState.Left or _mouseState.Right or _mouseState.Middle then
        begin
          _mouseState.IsMouseDown := True;
          _mouseState.IsMouseUp := False;
          _mouseState.MouseButton := _mousePacket[0];
        end;

        // Get current mouse state.
        Inc(_mouseState.X, _mousePacket[1]);
        Dec(_mouseState.Y, _mousePacket[2]);

        if _mouseState.X >= _mouseBoundary.Right then
          _mouseState.X:= _mouseBoundary.Right-1;
        if _mouseState.X < _mouseBoundary.Left then
          _mouseState.X:= _mouseBoundary.Left;
        if _mouseState.Y >= _mouseBoundary.Bottom then
          _mouseState.Y:= _mouseBoundary.Bottom-1;
        if _mouseState.Y < _mouseBoundary.Top then
          _mouseState.Y:= _mouseBoundary.Top;

        if not IsGUI then
        begin
          currentLocation:= _mouseState.Y * VGA.GetScreenWidth + _mouseState.X;
          attrib:= Byte(TEXTMODE_MEMORY[currentLocation] shr 8);
          if attrib <> _storedAttrib then
          begin
            if (oldPosX <> _mouseState.X) or (oldPosY <> _mouseState.Y) then
            begin
              oldLocation:= oldPosY * VGA.GetScreenWidth + oldPosX;
              TEXTMODE_MEMORY[oldLocation]:= ((_storedAttrib xor $77) shl 8) or Byte(TEXTMODE_MEMORY[oldLocation]);
            end;
            _storedAttrib:= attrib xor $77;
            TEXTMODE_MEMORY[currentLocation]:= (_storedAttrib shl 8) or Byte(TEXTMODE_MEMORY[currentLocation]);
          end;
        end;
        _mouseCycle:= 0;
        _IsEvent := True;
      end;
  end;
end;

procedure Init; stdcall; [public, alias: 'k_Mouse_Init'];
var
  status: Byte;
begin
  IRQ_DISABLE;

  Write('Installing PS/2 Mouse driver (0x2C)... ');

  // Enable mouse device.
  Mouse.Wait(1);
  outb($64, $A8);

  // Enable interrupt.
  Mouse.Wait(1);
  outb($64, $20);
  Mouse.Wait(0);
  status:= inb($60) or 2;
  Mouse.Wait(1);
  outb($64, $60);
  Mouse.Wait(1);
  outb($60, status);

  // Tell the mouse to use default settings.
  Mouse.WriteRegister($F6);
  Mouse.ReadRegister;

  // Enable the mouse.
  Mouse.WriteRegister($F4);
  Mouse.ReadRegister;

  // Set mouse speed.
  //Mouse.SetResolution(0);

  _mouseState.X:= 0;
  _mouseState.Y:= 0;
  _mouseState.Left:= False;
  _mouseState.Right:= False;
  _mouseState.Middle:= False;
  _mouseState.IsMouseMove := False;
  _mouseState.IsMouseUp := False;
  _mouseState.IsMouseDown := False;

  Mouse.SetBoundary(0, 0, VGA.GetScreenWidth, VGA.GetScreenHeight);

  IDT.InstallHandler($2C, @Mouse.Callback);

  Write(stOK);

  IRQ_ENABLE;
end;

procedure SetResolution(const R: Byte); stdcall; [public, alias: 'k_Mouse_SetResolution'];
begin
  Mouse.WriteRegister($E8);
  Mouse.Wait(1);
  outb($60, R);
  Mouse.ReadRegister;
end;

procedure SetBoundary(const Left, Top, Right, Bottom: Word); stdcall;
begin
  _mouseBoundary.Left  := Left;
  _mouseBoundary.Top   := Top;
  _mouseBoundary.Right := Right;
  _mouseBoundary.Bottom:= Bottom;
  _mouseState.X := (Left+Right) div 2 + Left;
  _mouseState.Y := (Top+Bottom) div 2 + Top;
end;

procedure GetState(const p: PMouseStruct); stdcall; [public, alias: 'k_Mouse_GetState'];
begin
  p^:= _mouseState;
end;

end.
