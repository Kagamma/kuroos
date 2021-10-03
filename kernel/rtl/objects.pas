unit Objects;

interface

uses
  kheap;

type
  PList = ^TList;
  TList = object
  private
    FCapacity: Cardinal;
    FCount: Cardinal;
  public
    Tag: Cardinal;
    Items: PPointer;

    constructor Init;
    destructor Done; virtual;
    procedure Add(const P: Pointer);
    procedure Delete(const Index: Cardinal);
    procedure Clear;
    function IndexOf(const P: Pointer): LongInt;

    property Count: Cardinal read FCount;
  end;

implementation

constructor TList.Init;
begin
  FCapacity := 64;
  FCount := 0;
  Items := Alloc(FCapacity * SizeOf(Pointer));
end;

destructor TList.Done;
begin
  FreeMem(Items);
end;

procedure TList.Add(const P: Pointer);
var
  Size: Cardinal;
begin
  Size := GetSize(Items) div SizeOf(Pointer);
  Inc(FCount);
  if FCount >= Size then
    Items := ReAlloc(Items, (Size + FCapacity) * SizeOf(Pointer));
  Items[FCount-1] := P;
end;

procedure TList.Delete(const Index: Cardinal);
var
  Size: Cardinal;
begin
  if Index < FCount then
  begin
    Dec(FCount);
    Move(Items[Index+1], Items[Index], (FCount-Index) * SizeOf(Pointer));
    Size := GetSize(Items) div SizeOf(Pointer);
    if (FCount + FCapacity <= Size) and (Count > FCapacity) then
      Items := ReAlloc(Items, (Size - FCapacity) * SizeOf(Pointer));
  end;
end;

procedure TList.Clear;
begin
  FCount := 0;
  Items := ReAlloc(Items, FCapacity * SizeOf(Pointer));
end;

function TList.IndexOf(const P: Pointer): LongInt;
var
  i: Integer;
begin
  for i := 0 to Count-1 do
    if Items[i] = P then
    begin
      exit(i);
    end;
  exit(-1);
end;

end.