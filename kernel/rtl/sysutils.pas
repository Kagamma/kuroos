unit sysutils;

interface

{$MACRO ON}
{$DEFINE DEBUG}

function  IntToStr(AValue: Cardinal): ShortString; stdcall;
function  IntToStr(AValue: Integer): ShortString; stdcall;
function  HexToStr(AValue: Cardinal; const ASize: Cardinal): AnsiString; stdcall;
function  StrToInt(const AStr: AnsiString): Integer; stdcall;
function  FloatToStr(AValue: Single): ShortString; stdcall;
function  StrToFloat(const AStr: AnsiString): Single; stdcall;

function  UpperCase(const S: AnsiString): AnsiString; stdcall;
function  LowerCase(const S: AnsiString): AnsiString; stdcall;

function  Pos(const SubStr: ShortString; const S: ShortString): Cardinal; stdcall; overload;
function  Pos(const SubStr: AnsiString; const S: AnsiString): Cardinal; stdcall; overload;
function  Copy(const s: ShortString; const Index, Count: Integer): ShortString; stdcall; overload;
function  Copy(const s: AnsiString; const Index, Count: Integer): AnsiString; stdcall; overload;
function  ExtractFileExt(S: String): String; stdcall;
function  ExtractFilePath(S: String): String; stdcall;
function  ExtractFileName(S: String): String; stdcall;
procedure Insert(const source: ShortString; var s: ShortString; index: SizeInt); stdcall;
procedure Delete(var s: ShortString; index: SizeInt; count: SizeInt); stdcall;
function  Compare(const s1, s2: ShortString): LongInt; stdcall;

implementation

uses
  math;

function  IntToStr(AValue: Cardinal): ShortString; stdcall;
var
  buf : array[0..11] of Char;
  p, i: LongInt;
begin
  if AValue = 0 then
    IntToStr:= '0'
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
    SetLength(IntToStr, High(buf) - p);
    for i:= p to High(buf) do
      IntToStr[i - p + 1]:= buf[i];
  end;
end;

function  IntToStr(AValue: Integer): ShortString; stdcall;
var
  buf   : array[0..12] of Char;
  p, i  : LongInt;
  signed: Integer;
begin
  if AValue = 0 then
    IntToStr:= '0'
  else
  begin
    p:= High(buf);
    buf[p]:= #0;
    if AValue < 0 then
    begin
      signed:= 2;
      AValue:= -AValue;
    end
    else
      signed:= 1;
    while AValue > 0 do
    begin
      Dec(p);
      buf[p]:= BASE10_CHARACTERS[AValue mod 10];
      AValue:= AValue div 10;
    end;
    SetLength(IntToStr, High(buf) - p + signed - 1);
    if signed = 2 then
      IntToStr[1]:= '-';
    for i:= p to High(buf) do
      IntToStr[i - p + signed]:= buf[i];
  end;
end;

function  HexToStr(AValue: Cardinal; const ASize: Cardinal): AnsiString; stdcall;
var
  buf  : array[0..8] of Char;
  str  : PChar;
  digit: Cardinal;
begin
  for digit:= 0 to 7 do
    buf[digit]:= #0;
  str  := @buf[8];
  str^ := #0;
  digit:= AValue;
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
  digit:= 1;
  SetLength(HexToStr, ASize);
  while str^ <> #0 do
  begin
    HexToStr[digit]:= str^;
    Inc(str);
    Inc(digit);
  end;
  HexToStr[digit]:= #0;
end;

function  StrToInt(const AStr: AnsiString): Integer; stdcall;
var
  i: Integer;
  b: Byte;
begin
  if (Pointer(AStr) = nil) or (Length(AStr) = 0) then
    exit(0);
  StrToInt:= 0;
  for i:= 1 to Length(AStr) do
  begin
    b:= Byte(AStr[i]) - Byte('0');
    StrToInt:= StrToInt * 10 + b;
  end;
end;

function  FloatToStr(AValue: Single): ShortString; stdcall;
var
  positive: Single;
  back,
  front: LongInt;
  backF: Single;
  frontS,
  backS,
  backSS: ShortString;
begin
  positive := Abs(AValue);
  front := Round(positive);
  if front > positive then
    Dec(front);
  backF := positive - front;
  back := Round(backF * 100000000);
  backS := IntToStr(back);
  while (Length(backS) > 0) and (Byte(backS[Length(backS)]) = Byte('0')) do
  begin
    SetLength(backS, Length(backS)-1);
  end;
  if Length(backS) > 0 then
    backSS := '.' + backS
  else
    backSS := backS;
  if AValue < 0 then
  begin
    frontS := '-' + IntToStr(front);
    exit(frontS + backSS);
  end
  else
    exit(IntToStr(front) + backSS);
end;

function  StrToFloat(const AStr: AnsiString): Single; stdcall;
begin
end;

function  UpperCase(const S: AnsiString): AnsiString; stdcall;
var
  i: Cardinal;
begin
  SetLength(UpperCase, Length(S));
  for i:= 1 to Length(S) do
  begin
    if S[i] in ['a'..'z'] then
      UpperCase[i]:= Char(Byte(S[i]) - 32)
    else
    begin
      UpperCase[i]:= S[i];
    end;
  end;
end;

function  LowerCase(const S: AnsiString): AnsiString; stdcall;
var
  i: Cardinal;
begin
  SetLength(LowerCase, Length(S));
  for i:= 1 to Length(S) do
  begin
    if S[i] in ['A'..'Z'] then
      LowerCase[i]:= Char(Byte(S[i]) + 32)
    else
    begin
      LowerCase[i]:= S[i];
    end;
  end;
end;

function  Pos(const SubStr: ShortString; const S: ShortString): Cardinal; stdcall;
var
  isPos: Boolean;
  i, j : Byte;
begin
  Pos:= 0;
  if (Byte(S[0]) > 0) and (Byte(SubStr[0]) > 0) and (Byte(S[0]) >= Byte(SubStr[0])) then
    for i:= 1 to Byte(S[0]) do
    begin
      if S[i] = SubStr[1] then
      begin
      isPos:= True;
      for j:= 1 to Byte(SubStr[0]) do
      begin
        if SubStr[j] <> S[i + j - 1] then
        begin
          isPos:= False;
          break;
        end;
      end;
    if isPos then
      exit(i);
    end;
  end;
end;

function  Pos(const SubStr: AnsiString; const S: AnsiString): Cardinal; stdcall;
var
  isPos: Boolean;
  i, j : Byte;
begin
  Pos:= 0;
  if (Length(S) > 0) and (Length(S) > 0) and (Length(S) >= Length(S)) then
    for i:= 1 to Length(S) do
    begin
      if S[i] = SubStr[1] then
      begin
      isPos:= True;
      for j:= 1 to Length(SubStr) do
      begin
        if SubStr[j] <> S[i + j - 1] then
        begin
          isPos:= False;
          break;
        end;
      end;
    if isPos then
      exit(i);
    end;
  end;
end;

function  Copy(const s: ShortString; const Index, Count: Integer): ShortString; stdcall;
var
  i, c: Integer;
  Ret: ShortString;
begin
  c := Index + Count;
  if c > Length(s) then
    c := Length(s);
  for i := Index to c do
    Ret[i - Index] := s[i];
  exit(Ret);
end;

function  Copy(const s: AnsiString; const Index, Count: Integer): AnsiString; stdcall;
var
  i, c: Integer;
  Ret: AnsiString;
begin
  c := Index + Count;
  if c > Length(s) then
    c := Length(s);
  c := c - Index;
  SetLength(Ret, c);
  Move(s[Index], Ret[1], c);
  exit(Ret);
end;

function ExtractFileExt(S: String): String; stdcall;
var
  I, J, K: Integer;
  Ret: String;
begin
  Ret := '';
  K:=0;
  J:=length(S);
  for I:= J downto 1 do
    if (S[I]='.') or (S[I]='\') or (S[I]='/') or (S[I]=':') then
    begin
      K:= I;
      break;
    end;
  if (K>0) and (S[K]='.') then
    Ret := Copy(S, K, J-K+1);
  exit(Ret);
end;

function ExtractFileName(S: String): String; stdcall;
var
  I, J, K: Integer;
  Ret: String;
begin
  Ret := S;
  K := 0;
  J := Length(S);
  for I:=J downto 1 do if (S[I]='\') or (S[I]='/') or (S[I]=':') then begin
    K:=I;
    break;
  end;
  if K>0 then
    Ret := Copy(S, K+1, J-K+1);
  exit(Ret);
end;

function ExtractFilePath(S: String): String; stdcall;
var
  I, J, K: Integer;
  Ret: String;
begin
  Ret := S;
  K := 0;
  J := Length(S);
  for I:=J downto 1 do if (S[I]='\') or (S[I]='/') or (S[I]=':') then begin
    K:=I;
    break;
  end;
  if K>0 then
    Ret := Copy(S,1,K);
  exit(Ret);
end;

procedure Insert(const source: ShortString; var s: ShortString; index: SizeInt); stdcall;
var
  buf: ShortString;
  cut, srclen, indexlen: SizeInt;
begin
  buf:= s;
  if index<1 then
    index:= 1;
  if index > Length(s) then
    index:= Length(s)+1;
  indexlen:= Length(s)-Index+1;
  srclen:= Length(Source);
  if Length(source) + Length(s) >= 255 then
  begin
    cut:= Length(source) + Length(s) - 255 + 1;
    if cut > indexlen then
    begin
      Dec(srclen, cut-indexlen);
      indexlen:= 0;
    end
    else
      Dec(indexlen, cut);
  end;
  Move(buf[index], s[index+srclen], indexlen);
  Move(Source[1], s[index], srclen);
  s[0]:= Char(index + srclen + indexlen - 1);
end;

procedure Delete(var s: ShortString; index: SizeInt; count: SizeInt); stdcall;
begin
  if index<=0 then
    exit;
  if (Index <= Length(s)) and (Count>0) then
  begin
    if Count > Length(s)-Index then
      Count:= Length(s)-Index+1;
    s[0]:= Char(Length(s)-Count);
    if Index <= Length(s) then
      Move(s[Index+Count], s[Index], Length(s)-Index+1);
  end;
end;

function  Compare(const s1, s2: ShortString): LongInt; stdcall;
var
  i, len: Byte;
begin
  if Length(s1) < Length(s2) then
    len:= Length(s2)
  else
    len:= Length(s1);
  if len > 0 then
  begin
    for i:= 1 to len do
    begin
      if s1[i] <> s2[i] then
	    exit(Byte(s1[i]) - Byte(s2[i]));
	end;
  end;
  exit(0);
end;

end.
