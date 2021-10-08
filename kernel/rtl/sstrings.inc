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

procedure fpc_shortstr_shortstr_intern_charmove(const src: shortstring; const srcindex: byte; var dst: shortstring; const dstindex, len: byte); {$ifdef SYSTEMINLINE}inline;{$endif}
begin
  move(src[srcindex],dst[dstindex],len);
end;

procedure fpc_shortstr_assign(Len: LongInt; sstr, dstr: Pointer); compilerproc; [public,alias:'FPC_SHORTSTR_ASSIGN'];
var
  slen : byte;
begin
  slen:=length(pshortstring(sstr)^);
  if slen<len then
    len:=slen;
  move(sstr^,dstr^,len+1);
  if slen>len then
    pchar(dstr)^:=chr(len);
end;

function  fpc_shortstr_length(const s: ShortString): Byte;
begin
  exit(Byte(s[0]));
end;

procedure fpc_shortstr_to_shortstr(out res: ShortString; const sstr: ShortString); compilerproc;
var
  slen : byte;
begin
  slen:=length(sstr);
  if slen>high(res) then
    slen:=high(res);
  move(sstr[0],res[0],slen+1);
  res[0]:=chr(slen);
end;

procedure fpc_shortstr_concat(var dests: ShortString; const s1, s2: ShortString); compilerproc;
var
  s1l, s2l : ObjpasInt;
begin
  s1l:=length(s1);
  s2l:=length(s2);
  if s1l+s2l>high(dests) then
    begin
      if s1l>high(dests) then
        s1l:=high(dests);
      s2l:=high(dests)-s1l;
    end;
  if @dests=@s1 then
    fpc_shortstr_shortstr_intern_charmove(s2,1,dests,s1l+1,s2l)
  else
    if @dests=@s2 then
      begin
        fpc_shortstr_shortstr_intern_charmove(dests,1,dests,s1l+1,s2l);
        fpc_shortstr_shortstr_intern_charmove(s1,1,dests,1,s1l);
      end
  else
    begin
      fpc_shortstr_shortstr_intern_charmove(s1,1,dests,1,s1l);
      fpc_shortstr_shortstr_intern_charmove(s2,1,dests,s1l+1,s2l);
    end;
  dests[0]:=chr(s1l+s2l);
end;

procedure fpc_shortstr_concat_multi(var dests:shortstring;const sarr:array of pshortstring);compilerproc;
var
  s2l : byte;
  LowStart,i,
  Len : ObjpasInt;
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
  needtemp:=False;
  for i:=lowstart to high(sarr) do
    begin
      if Pointer(@DestS)=Pointer(sarr[i]) then
        begin
          needtemp:=True;
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
  for i:=lowstart to high(sarr) do
    begin
      p:=sarr[i];
      if assigned(p) then
        begin
          s2l:=length(p^);
          if Len+s2l>high(dests) then
            s2l:=high(dests)-Len;
          fpc_shortstr_shortstr_intern_charmove(p^,1,pdest^,Len+1,s2l);
          inc(Len,s2l);
        end;
    end;
  pdest^[0]:=Chr(Len);
  if needtemp then
    DestS:=TmpStr;
end;

function fpc_shortstr_compare_equal(const left,right:shortstring): longint; [public,alias:'FPC_SHORTSTR_COMPARE_EQUAL']; compilerproc;
begin
  Result := ObjpasInt(left[0]) - ObjpasInt(right[0]);
  if Result = 0 then
    Result := CompareByte(left[1],right[1], ObjpasInt(left[0]));
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
