{
    File:
        apm.pas
    Description:
        APM.
    License:
        General Public License (GPL)
    ref: https://wiki.osdev.org/APM
}

unit apm;

interface

function Check: Boolean;
procedure Shutdown;

implementation

uses
  bios, console;

function Check: Boolean;
var
  R: TX86Registers;
begin
  R.ax := $5300;
  R.bx := 0;
  BIOS.Int(R, $15);
  if (BCDToBin(R.ax shr 8) >= 1) and (BCDToBin(R.ax) >= 1) then
    exit(True);
  exit(False);
end;

procedure Shutdown;
var
  R: TX86Registers;
begin
  if not Check then
  begin
    Console.WriteStr('Your system doesn''t support APM 1.1.'#10#13'Can''t perform automatic shutdown.'#10#13);
    exit;
  end;
  // Disconnect from any APM devices
  R.ax := $5304;
  R.bx := 0;
  BIOS.Int(R, $15);
  // Set APM driver version
  R.ax := $530E;
  R.bx := 0;
  R.cx := $0101;
  BIOS.Int(R, $15);
  // Enable power management for all devices
  R.ax := $5308;
  R.bx := 1;
  R.cx := 1;
  BIOS.Int(R, $15);
  // Shutdown
  R.ax := $5307;
  R.bx := 1;
  R.cx := 3;
  BIOS.Int(R, $15);
end;

end.