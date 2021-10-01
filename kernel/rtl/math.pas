unit math;

{$MODE DELPHI}

{$I KOS.INC}

interface

const
  PI = 3.141592653;

procedure InitFPU;
function InRect(const x, y, x1, y1, x2, y2: Integer): Boolean; inline;
function Lerp(const x, y, t: Single): Single; inline;
function Clamp(const v, x, y: LongInt): LongInt; inline; overload;
function Clamp(const v, x, y: Single): Single; inline; overload;
procedure Swap(var x, y: Integer); inline; overload;
procedure Swap(var x, y: Cardinal); inline; overload;
procedure Swap(var x, y: Single); inline; overload;
function Min(const x, y: Single): Single; inline; overload;
function Max(const x, y: Single): Single; inline; overload;
function Min(const x, y: LongInt): LongInt; inline; overload;
function Max(const x, y: LongInt): LongInt; inline; overload;
function Sin(const x: Single): Single; inline;
function Cos(const x: Single): Single; inline;
function Tan(const x: Single): Single; inline;
function Sqrt(const x: Single): Single; inline;
function Round(const x: Single): LongInt; inline;
function Trunc(const x: Single): LongInt; inline;
function Floor(const x: Single): LongInt; inline;
function Ceil(const x: Single): LongInt; inline;
function Abs(const x: LongInt): LongInt; inline; overload;
function Abs(const x: Single): Single; inline; overload;

implementation

procedure InitFPU; assembler;
asm
    mov edx, cr0
    and edx, -37
    mov cr0, edx
    fninit
end ['edx'];

procedure Swap(var x, y: Integer);
var
  tmp: Integer;
begin
  tmp := x;
  x := y;
  y := tmp;
end;

procedure Swap(var x, y: Cardinal);
var
  tmp: Cardinal;
begin
  tmp := x;
  x := y;
  y := tmp;
end;

procedure Swap(var x, y: Single);
var
  tmp: Single;
begin
  tmp := x;
  x := y;
  y := tmp;
end;

function InRect(const x, y, x1, y1, x2, y2: Integer): Boolean;
begin
  exit((x >= x1) and (x <= x2) and (y >= y1) and (y <= y2));
end;

function Lerp(const x, y, t: Single): Single;
begin
  Result := x + (y-x) * t;
end;

function Clamp(const v, x, y: LongInt): LongInt;
begin
  if v < x then
    exit(x)
  else if v > y then
    exit(y)
  else
    exit(v);
end;

function Clamp(const v, x, y: Single): Single;
begin
  if v < x then
    exit(x)
  else if v > y then
    exit(y)
  else
    exit(v);
end;

function Min(const x, y: Single): Single;
begin
  if x < y then
    exit(x)
  else
    exit(y);
end;

function Max(const x, y: Single): Single;
begin
  if x > y then
    exit(x)
  else
    exit(y);
end;

function Min(const x, y: LongInt): LongInt;
begin
  if x < y then
    exit(x)
  else
    exit(y);
end;

function Max(const x, y: LongInt): LongInt;
begin
  if x > y then
    exit(x)
  else
    exit(y);
end;

function Sin(const x: Single): Single; assembler;
asm
    fld x
    fsin
    fstp Result
end;

function Cos(const x: Single): Single; assembler;
asm
    fld x
    fcos
    fstp Result
end;

function Tan(const x: Single): Single; assembler;
asm
    fld x
    fptan
    fstp Result
end;

function Sqrt(const x: Single): Single; assembler;
asm
    fld x
    fsqrt
    fstp Result
end;

function Round(const x: Single): LongInt; assembler;
asm
    fld x
    fistp Result
end;

function Trunc(const x: Single): LongInt;
begin
  Result := Floor(x);
end;

function Floor(const x: Single): LongInt;
begin
  Result := Round(x);
  if (Result < 0) and (Result < x) then
    Inc(Result)
  else if (Result > 0) and (Result > x) then
    Dec(Result);
end;

function Ceil(const x: Single): LongInt;
begin
  Result := Round(x);
  if (Result < 0) and (Result > x) then
    Dec(Result)
  else if (Result > 0) and (Result < x) then
    Inc(Result);
end;

function Abs(const x: LongInt): LongInt;
begin
  if x < 0 then
    Result := -x
  else
    Result := x;
end;

function Abs(const x: Single): Single; assembler;
asm
    fld x
    fabs
    fstp Result
end;

end.