{
    File:
        pci.pas
    Description:
        PCI-related routines.
    License:
        General Public License (GPL)
}

unit pci;

interface

procedure Init; stdcall;

var
  SSEAvail: Boolean;

implementation

uses
  console;

procedure Init; stdcall;
begin
  Console.WriteStr('Detecting PCI... ');
  Console.WriteStr(stOk);
end;

end.
