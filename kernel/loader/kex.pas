unit kex;

{$I kos.inc}

interface

type
  PKEXHeader = ^TKEXHeader;
  TKEXHeader = packed record
    ID: array[0..3] of Char;
    Version   : Cardinal;
    Size      : Cardinal;
    StartAddr : Cardinal;
    StackSize : Cardinal;
    EntryPoint: Cardinal;
    IconAddr  : Cardinal;
  end;

implementation

end.

