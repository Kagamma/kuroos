{  Note: _vmt will be reset to -1 when memory is allocated,
   this is needed for fpc_help_fail }
function fpc_help_constructor(_self:pointer;var _vmt:pointer;_vmt_pos:cardinal):pointer;[public,alias:'FPC_HELP_CONSTRUCTOR'];compilerproc;
type
  ppointer = ^pointer;
  pvmt = ^tvmt;
  tvmt=packed record
    size,msize:ptruint;
    parent:pointer;
  end;
var
  vmtcopy : pointer;
begin
  { Inherited call? }
  if _vmt=nil then
    begin
      fpc_help_constructor:=_self;
      exit;
    end;
  vmtcopy:=_vmt;

  if (_self=nil) and
     (pvmt(_vmt)^.size>0) then
    begin
      getmem(_self,pvmt(_vmt)^.size);
      { reset vmt needed for fail }
      _vmt:=pointer(-1);
    end;
  if _self<>nil then
    begin
      fillchar(_self^,pvmt(vmtcopy)^.size,#0);
      ppointer(_self+_vmt_pos)^:=vmtcopy;
    end;
  fpc_help_constructor:=_self;
end;

{ Note: _self will not be reset, the compiler has to generate the reset }
procedure fpc_help_destructor(_self,_vmt:pointer;vmt_pos:cardinal); compilerproc; [public,alias:'FPC_HELP_DESTRUCTOR'];
type
  ppointer = ^pointer;
  pvmt = ^tvmt;
  tvmt = packed record
    size,msize : ptruint;
    parent : pointer;
  end;
begin
   { already released? }
   if (_self=nil) or
      (_vmt=nil) or
      (ppointer(_self+vmt_pos)^=nil) then
     exit;
   if (pvmt(ppointer(_self+vmt_pos)^)^.size=0) or
      (pvmt(ppointer(_self+vmt_pos)^)^.size+pvmt(ppointer(_self+vmt_pos)^)^.msize<>0) then
      RunError(210);
   { reset vmt to nil for protection }
   ppointer(_self+vmt_pos)^:=nil;
   freemem(_self);
end;

function CompareByte(Const buf1,buf2;len:SizeInt):SizeInt;
var
  aligncount : sizeint;
  psrc,pdest,pend : pbyte;
  b : ptrint;
begin
  b:=0;
  psrc:=@buf1;
  pdest:=@buf2;
  if (len>4*sizeof(ptruint)-1)
{$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
    and ((PtrUInt(pdest) and (sizeof(PtrUInt)-1))=(PtrUInt(psrc) and (sizeof(PtrUInt)-1)))
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
    then
    begin
      { Align on native pointer size }
      aligncount:=(sizeof(PtrUInt)-(PtrUInt(pdest) and (sizeof(PtrUInt)-1))) and (sizeof(PtrUInt)-1);
      dec(len,aligncount);
      pend:=psrc+aligncount;
      while psrc<pend do
        begin
          b:=(ptrint(psrc^)-ptrint(pdest^));
          if b<>0 then
            begin
              if b<0 then
                exit(-1)
              else
                exit(1);
            end;
          inc(pdest);
          inc(psrc);
        end;
      { use sizeuint typecast to force shr optimization }
      pptruint(pend):=pptruint(psrc)+(sizeuint(len) div sizeof(ptruint));
      len:=len and (sizeof(PtrUInt)-1);
      while psrc<pend do
        begin
          b:=(pptrint(psrc)^-pptrint(pdest)^);
          if b<>0 then
            begin
              len:=sizeof(ptruint);
              break;
            end;
          inc(pptruint(pdest));
          inc(pptruint(psrc));
        end;
    end;
  if (psrc+len >= psrc) then
    pend:=psrc+len
  else
    pend:=pbyte(high(ptruint)-1);
  while psrc<pend do
    begin
      b:=(ptrint(psrc^)-ptrint(pdest^));
      if b<>0 then
        begin
          if b<0 then
            exit(-1)
          else
            exit(1);
        end;
      inc(pdest);
      inc(psrc);
    end;
  result:=0;
end;

function IndexByte(Const buf;len:SizeInt;b:byte):SizeInt;
var
  psrc,pend : pbyte;
begin
  psrc:=@buf;
  { simulate assembler implementations behaviour, which is expected }
  { fpc_pchar_to_ansistr in astrings.inc                            }
  if (len < 0) or
     (psrc+len < psrc) then
    pend:=pbyte(high(PtrUInt)-sizeof(byte))
  else
    pend:=psrc+len;
  while (psrc<pend) do
    begin
      if psrc^=b then
        begin
          result:=psrc-pbyte(@buf);
          exit;
        end;
      inc(psrc);
    end;
  result:=-1;
end;

function fpc_pchar_length(p:pchar):sizeint;[public,alias:'FPC_PCHAR_LENGTH']; compilerproc;
begin
  if assigned(p) then
    Result:=IndexByte(p^,high(Result),0)
  else
    Result:=0;
end;
