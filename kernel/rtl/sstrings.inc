procedure fpc_Write_Text_ShortStr(Len: Longint; var f: Text; const s: String); compilerproc;
var
  i: Cardinal;
begin
  for i:= 1 to Byte(s[0]) do
    fpc_WriteChar(s[i]);
end;

procedure fpc_Shortstr_SetLength(var s:shortstring;len:SizeInt); compilerproc; [Public,Alias : 'FPC_SHORTSTR_SETLENGTH'];
begin
  if Len>255 then
   Len:=255;
  s[0]:=Char(len);
end;

procedure fpc_shortstr_assign(Len: LongInt; sstr, dstr: Pointer); compilerproc; [public,alias:'FPC_SHORTSTR_ASSIGN'];
begin
  Move(Pointer(sstr)^, Pointer(dstr)^, 256);
end;

function  fpc_shortstr_length(const s: ShortString): Byte;
begin
  exit(Byte(s[0]));
end;

procedure fpc_shortstr_to_shortstr(out res: ShortString; const sstr: ShortString); compilerproc;
begin
  Move(sstr[0], res[0], Byte(sstr[0])+1);
end;

procedure fpc_shortstr_concat(var dest: ShortString; const s1, s2: ShortString); compilerproc;
var
  i , p : Byte;
  l1, l2: Byte;
begin
  l1:= Byte(s1[0]);
  l2:= Byte(s2[0]);
  i:= 0;
  if l1 > 0 then
    for i:= 1 to l1 do
      dest[i]:= s1[i];
  p:= i;
  if l2 > 0 then
    for i:= 1 to l2 do
      dest[p + i]:= s2[i];
  dest[0]:= Char(l1 + l2);
end;

procedure fpc_shortstr_concat_multi(var dests:shortstring;const sarr:array of pshortstring);compilerproc;
var
  s2l : byte;
  LowStart,i,
  Len : longint;
  pc : pchar;
  needtemp : boolean;
  tmpstr  : shortstring;
  p,pdest  : pshortstring;
begin
  if high(sarr)=0 then
    begin
      DestS:='';
      exit;
    end;
  lowstart:=low(sarr);
  if Pointer(@DestS)=Pointer(sarr[lowstart]) then
    inc(lowstart);
  { Check for another reuse, then we can't use
    the append optimization and need to use a temp }
  needtemp:=false;
  for i:=lowstart to high(sarr) do
    begin
      if Pointer(@DestS)=Pointer(sarr[i]) then
        begin
          needtemp:=true;
          break;
        end;
    end;
  if needtemp then
    begin
      lowstart:=low(sarr);
      tmpstr:='';
      pdest:=@tmpstr
    end
  else
    begin
      { Start with empty DestS if we start with concatting
        the first array element }
      if lowstart=low(sarr) then
        DestS:='';
      pdest:=@DestS;
    end;
  { Concat all strings, except the string we already
    copied in DestS }
  Len:=length(pdest^);
  pc:=@pdest^[1+Length(pdest^)];
  for i:=lowstart to high(sarr) do
    begin
      p:=sarr[i];
      if assigned(p) then
        begin
          s2l:=length(p^);
          if Len+s2l>high(dests) then
            s2l:=high(dests)-Len;
          Move(p^[1],pc^,s2l);
          inc(pc,s2l);
          inc(Len,s2l);
        end;
    end;
  pdest^[0]:=Chr(Len);
  if needtemp then
    DestS:=TmpStr;
end;

function  fpc_ShortStr_Compare_equal(const s1, s2: ShortString): SizeInt; [Public,Alias : 'FPC_SHORTSTR_COMPARE_EQUAL'];  compilerproc;
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

procedure fpc_pchar_to_shortstr(out res: ShortString; p: PChar); compilerproc;
var
  b: PByte;
begin
  b := @res[0];
  b^:= 0;
  while (Char(p^) <> #0) do
  begin
    Inc(b^);
    res[b^]:= Char(p^);
    Inc(p);
  end;
end;
