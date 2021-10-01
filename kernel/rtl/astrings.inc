type
  PAnsiRec = ^TAnsiRec;
  TAnsiRec = packed record
    Ref,
    Len   : SizeInt;
    First : Char;
  end;

const
  AnsiRecLen = SizeOf(TAnsiRec);
  FirstOff   = SizeOf(TAnsiRec)-1;

procedure NewAnsiString(out S: Pointer; Len : SizeInt);
{
  Allocate a new AnsiString on the heap.
  initialize it to zero length and reference count 1.
}
Var
  P : Pointer;
begin
  { request a multiple of 16 because the heap manager alloctes anyways chunks of 16 bytes }
  GetMem(P,Len+AnsiRecLen);
  If P<>Nil then
  begin
    PAnsiRec(P)^.Ref:=1;         { Set reference count }
    PAnsiRec(P)^.Len:=0;         { Initial length }
    PAnsiRec(P)^.First:=#0;      { Terminating #0 }
    inc(p,firstoff);             { Points to string now }
  end;
  S:= P;
end;

Procedure DisposeAnsiString(Var S : Pointer);
{
  Deallocates a AnsiString From the heap.
}
begin
  If S=Nil then
    exit;
  Dec(S,FirstOff);
  FreeMem(S);
  S:= Nil;
end;

procedure fpc_Write_Text_AnsiStr(Len: Longint; var f: Text; const s: AnsiString); compilerproc;
var
  i: Integer;
begin
  for i:= 1 to Length(s) do
    Console_WriteChar(s[i]);
end;

procedure fpc_Write_Text_PChar_As_Pointer(Len: Longint; var f: Text; p: Pointer); compilerproc;
begin
  fpc_Write(p);
end;

procedure fpc_ansistr_incr_ref(var s: Pointer); compilerproc; [public, alias : 'FPC_ANSISTR_INCR_REF'];
var
  p: Pointer;
begin
  if s = nil then
    exit;
  p:= Pointer(s) - FirstOff;
  if PAnsiRec(p)^.Ref < 0 then exit;
  IncLocked(PAnsiRec(p)^.Ref);
end;

procedure ansistr_decr_ref(var s: Pointer); compilerproc;
var
  p: Pointer;
begin
  if s = nil then
    exit;
  p:= Pointer(s) - FirstOff;
  if PAnsiRec(p)^.Ref < 0 then exit;
  DecLocked(PAnsiRec(p)^.Ref);
  if PAnsiRec(p)^.Ref = 0 then
  begin
    DisposeAnsiString(S);
  end;
end;

procedure fpc_ansistr_incr_ref_2(var s: Pointer);
var
  p: Pointer;
begin
  if s = nil then
    exit;
  p:= Pointer(s) - FirstOff;
  if PAnsiRec(p)^.Ref < 0 then exit;
  IncLocked(PAnsiRec(p)^.Ref);
end;

procedure fpc_ansistr_decr_ref_2(var s: Pointer);
var
  p: Pointer;
begin
  if s = nil then
    exit;
  p:= Pointer(s) - FirstOff;
  if PAnsiRec(p)^.Ref < 0 then exit;
  DecLocked(PAnsiRec(p)^.Ref);
  if PAnsiRec(p)^.Ref = 0 then
  begin
    DisposeAnsiString(S);
  end;
end;

procedure fpc_ansistr_decr_ref(var s: Pointer); compilerproc; [public, alias : 'FPC_ANSISTR_DECR_REF'];
begin
  ansistr_decr_ref(s);
end;

procedure fpc_AnsiStr_SetLength(var s: AnsiString; l: SizeInt); compilerproc; [public, alias : 'FPC_ANSISTR_SETLENGTH'];
var
  Dst: Pointer;
begin
  if Pointer(S) <> nil then
  begin
    Dst:= KHeap_ReAlloc(Pointer(Pointer(S) - FirstOff), l + AnsiRecLen);
    Pointer(S):= Dst;
  end
  else
  begin
    Pointer(S):= KHeap_Alloc(l + AnsiRecLen);
    PAnsiRec(Pointer(S))^.Ref:= 1;
  end;
  PAnsiRec(Pointer(S))^.Len:= l;
  PAnsiRec(Pointer(S))^.First:= #0;
  Pointer(S):= Pointer(S) + FirstOff;
end;

function  AnsiLength(const s: AnsiString): Cardinal;
begin
  if Pointer(S) <> nil then
    exit(PAnsiRec(Pointer(S))^.Len)
  else
    exit(0);
end;

Function fpc_ShortStr_To_AnsiStr (Const S2 : ShortString): ansistring; compilerproc;
{
  Converts a ShortString to a AnsiString;
}
Var
  Size : SizeInt;
begin
  Size:=Length(S2);
  Setlength (fpc_ShortStr_To_AnsiStr,Size);
  if Size>0 then
    Move(S2[1],Pointer(fpc_ShortStr_To_AnsiStr)^,Size);
end;


procedure fpc_AnsiStr_To_ShortStr (out res: shortstring; const S2 : Ansistring);[Public, alias: 'FPC_ANSISTR_TO_SHORTSTR'];  compilerproc;
{
  Converts a AnsiString to a ShortString;
}
Var
  Size : SizeInt;
begin
  if S2='' then
   res:=''
  else
   begin
     Size:=Length(S2);
     If Size>high(res) then
      Size:=high(res);
     Move (S2[1],res[1],Size);
     byte(res[0]):=byte(Size);
   end;
end;

Function fpc_Char_To_AnsiStr(const c : Char): AnsiString; compilerproc;
{
  Converts a Char to a AnsiString;
}
begin
  Setlength (fpc_Char_To_AnsiStr,1);
  PByte(Pointer(fpc_Char_To_AnsiStr))^:=byte(c);
  { Terminating Zero }
  PByte(Pointer(fpc_Char_To_AnsiStr)+1)^:=0;
end;

procedure fpc_AnsiStr_Concat (var DestS:ansistring;const S1,S2 : AnsiString); compilerproc;
Var
  Size,Location : SizeInt;
  same : boolean;
begin
  { only assign if s1 or s2 is empty }
  if (S1='') then
    begin
      DestS:=s2;
      exit;
    end;
  if (S2='') then
    begin
      DestS:=s1;
      exit;
    end;
  Location:=Length(S1);
  Size:=length(S2);
  { Use Pointer() typecasts to prevent extra conversion code }
  if Pointer(DestS)=Pointer(S1) then
    begin
      same:=Pointer(S1)=Pointer(S2);
      SetLength(DestS,Size+Location);
      if same then
        Move(Pointer(DestS)^,(Pointer(DestS)+Location)^,Size)
      else
        Move(Pointer(S2)^,(Pointer(DestS)+Location)^,Size+1);
    end
  else if Pointer(DestS)=Pointer(S2) then
    begin
      SetLength(DestS,Size+Location);
      Move(Pointer(DestS)^,(Pointer(DestS)+Location)^,Size+1);
      Move(Pointer(S1)^,Pointer(DestS)^,Location);
    end
  else
    begin
      DestS:='';
      SetLength(DestS,Size+Location);
      Move(Pointer(S1)^,Pointer(DestS)^,Location);
      Move(Pointer(S2)^,(Pointer(DestS)+Location)^,Size+1);
    end;
end;

function fpc_AnsiStr_Concat_multi (const sarr:array of Ansistring): ansistring; compilerproc;
Var
  i  : Longint;
  p  : pointer;
  pc : pchar;
  Size,NewLen : SizeInt;
begin
  { First calculate size of the result so we can do
    a single call to SetLength() }
  NewLen:=0;
  for i:=low(sarr) to high(sarr) do
    inc(NewLen,length(sarr[i]));
  SetLength(result,NewLen);
  pc:=pchar(result);
  for i:=low(sarr) to high(sarr) do
    begin
      p:=pointer(sarr[i]);
      if assigned(p) then
        begin
          Size:=length(ansistring(p));
          Move(pchar(p)^,pc^,Size+1);
          inc(pc,size);
        end;
    end;
end;

// procedure fpc_AnsiStr_Concat_multi (var DestS:ansistring;const sarr:array of Ansistring); compilerproc;
// Var
//   lowstart,i  : Longint;
//   p,pc        : pointer;
//   Size,NewLen,
//   OldDestLen  : SizeInt;
//   destcopy    : pointer;
// begin
//   if high(sarr)=0 then
//     begin
//       DestS:='';
//       exit;
//     end;
//   destcopy:=nil;
//   lowstart:=low(sarr);
//   if Pointer(DestS)=Pointer(sarr[lowstart]) then
//     inc(lowstart);
//   { Check for another reuse, then we can't use
//     the append optimization }
//   for i:=lowstart to high(sarr) do
//     begin
//       if Pointer(DestS)=Pointer(sarr[i]) then
//         begin
//           { if DestS is used somewhere in the middle of the expression,
//             we need to make sure the original string still exists after
//             we empty/modify DestS                                       }
//           destcopy:=pointer(dests);
//           fpc_AnsiStr_Incr_Ref_2(destcopy);
//           lowstart:=low(sarr);
//           break;
//         end;
//     end;
//   { Start with empty DestS if we start with concatting
//     the first array element }
//   if lowstart=low(sarr) then
//     DestS:='';
//   OldDestLen:=length(DestS);
//   { Calculate size of the result so we can do
//     a single call to SetLength() }
//   NewLen:=0;
//   for i:=low(sarr) to high(sarr) do
//     inc(NewLen,length(sarr[i]));
//   SetLength(DestS,NewLen);
//   { Concat all strings, except the string we already
//     copied in DestS }
//   pc:=Pointer(DestS)+OldDestLen;
//   for i:=lowstart to high(sarr) do
//     begin
//       p:=pointer(sarr[i]);
//       if assigned(p) then
//         begin
//           Size:=length(ansistring(p));
//           Move(p^,pc^,Size+1);
//           inc(pc,size);
//         end;
//     end;
//   fpc_AnsiStr_Decr_Ref_2(destcopy);
// end;

Function fpc_AnsiStr_Compare_equal(const S1,S2 : AnsiString): SizeInt;[Public,Alias : 'FPC_ANSISTR_COMPARE_EQUAL']; compilerproc; inline;
{
  Compares 2 AnsiStrings for equality/inequality only;
  The result is
   0 if S1=S2
   <>0 if S1<>S2
}
Var
  MaxI,Temp : SizeInt;
begin
  if pointer(S1)=pointer(S2) then
    begin
      result:=0;
      exit;
    end;
  Maxi:=Length(S1);
  temp:=Length(S2);
  Result := Maxi - temp;
  if Result = 0 then
    if MaxI>0 then
      result:=CompareByte(S1[1],S2[1],MaxI);
end;

function fpc_truely_ansistr_unique(Var S : Pointer): Pointer;
Var
  SNew : Pointer;
  L    : SizeInt;
begin
  L:=PAnsiRec(Pointer(S)-FirstOff)^.len;
  SetLength(AnsiString(SNew), L);
  Move (Pointer(S)^,SNew^,L+1);
  PAnsiRec(SNew-FirstOff)^.len:=L;
  ansistr_decr_ref(Pointer(S));  { Thread safe }
  pointer(S):=SNew;
  pointer(result):=SNew;
end;

// MV: inline the basic checks for case that S is already unique.
// Rest is too complex to inline, so factor that out as a call.
Function fpc_ansistr_Unique(Var S : Pointer): Pointer; [Public,Alias : 'FPC_ANSISTR_UNIQUE']; compilerproc; inline;
{
  Make sure reference count of S is 1,
  using copy-on-write semantics.
}
begin
  pointer(result) := pointer(s);
  If Pointer(S)=Nil then
    exit;
  if PAnsiRec(Pointer(S)-Firstoff)^.Ref<>1 then
    result:=fpc_truely_ansistr_unique(s);
end;
