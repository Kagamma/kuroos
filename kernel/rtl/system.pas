unit system;

interface

{$MACRO ON}
{$DEFINE DEBUG}
{$MODE OBJFPC}
{$H-}

{$DEFINE IRQ_ENABLE := asm sti end}
{$DEFINE IRQ_DISABLE:= asm cli end}
{$DEFINE INFINITE_LOOP:=
  asm
    @loop:
      jmp @loop
  end
}

{$DEFINE FPC_IS_KERNEL}
{$DEFINE FPC_IS_SYSTEM}

type
  Cardinal  = 0..$FFFFFFFF;
  HResult   = Cardinal;
  DWord     = Cardinal;
  PtrUInt   = Cardinal;
  Integer   = LongInt;
  SizeUInt  = Cardinal;
  SizeInt   = LongInt;
  PtrInt    = LongInt;
  AnsiChar  = Char;
  ValReal   = Single;

  PChar     = ^Char;
  PAnsiChar = PChar;
  PByte     = ^Byte;
  PWord     = ^Word;
  PPtrUInt  = ^PtrUInt;
  PCardinal = ^Cardinal;
  PInteger  = ^Integer;
  PLongInt  = ^LongInt;
  PText     = ^Text;
  PSingle   = ^Single;
  PPointer  = ^Pointer;
  PPtrInt   = ^PtrInt;
  KernelString = ShortString;
  PShortString = ^ShortString;
  KernelCardinal = Cardinal;
  PKernelCardinal = ^KernelCardinal;
  ObjpasInt = Integer;

  Pjmp_buf = ^jmp_buf;
  jmp_buf = packed record
    ebx: LongInt;
    esi: LongInt;
    edi: LongInt;
    bp : Pointer;
    sp : Pointer;
    pc : Pointer;
  end;

  PObjectVMT = ^TObjectVMT;
  TObjectVMT = record
    Size, MSize: SizeUInt;
    Parent: Pointer;
  end;

// List of function pointers used by system unit
var
  IncDecLock: PCardinal = nil;
  Spinlock_Lock: procedure(const ALock: PCardinal); stdcall;
  Spinlock_Unlock: procedure(const ALock: PCardinal); stdcall;
  Console_WriteChar: procedure(const C: Char); stdcall;
  Console_WriteStr: procedure(const S: PChar); stdcall;
  KHeap_Alloc: function(const ASize: Cardinal): Pointer; stdcall;
  KHeap_ReAlloc: function(const APtr: Pointer; const ASize: Cardinal): Pointer; stdcall;
  KHeap_Free: procedure(var APtr: Pointer); stdcall;

{$I common_h.inc}

function  fpc_help_constructor(_self: Pointer; var _vmt: Pointer; _vmt_pos: Cardinal): Pointer; compilerproc;
procedure fpc_help_destructor(_self,_vmt:pointer;vmt_pos:cardinal); compilerproc;

function Chr(C: Byte): Char; inline;
procedure getmem(var p: pointer; const size: PtrUInt);
procedure freemem(p: Pointer);
procedure reallocmem(var p: Pointer; const size: PtrUInt);
function  fpc_getmem(size: PtrUInt): Pointer; compilerproc;
procedure fpc_freemem(p: Pointer); compilerproc;

function  fpc_get_output: PText; compilerproc;
procedure fpc_Write_Text_Char(Len: Longint; var f: Text; const c: Char); compilerproc;
procedure fpc_Write_End(var f: Text); compilerproc;
procedure fpc_Writeln_End(var f: Text); compilerproc;
procedure fpc_Write_Text_SInt(Len: LongInt; var t: Text; l: PtrInt); compilerproc;
procedure fpc_Write_Text_UInt(Len: LongInt; var t: Text; l: PtrUInt); compilerproc;

procedure fpc_Write_Text_ShortStr(Len: Longint; var f: Text; const s: String); compilerproc;
procedure fpc_Write_Text_PChar_As_Pointer(Len: Longint; var f: Text; p: Pointer); compilerproc;
procedure fpc_shortstr_assign(Len: LongInt; sstr, dstr: Pointer); compilerproc;
procedure fpc_Shortstr_SetLength(var s:shortstring;len:SizeInt); compilerproc;
function  fpc_shortstr_length(const s: ShortString): Byte;
procedure fpc_shortstr_to_shortstr(out res: ShortString; const sstr: ShortString); compilerproc;
procedure fpc_shortstr_concat(var dests: ShortString; const s1, s2: ShortString); compilerproc;
procedure fpc_shortstr_concat_multi(var dests:shortstring;const sarr:array of pshortstring);compilerproc;
function fpc_shortstr_compare_equal(const left,right:shortstring): longint; compilerproc;
procedure fpc_pchar_to_shortstr(out res: ShortString; p: PChar); compilerproc;
procedure fpc_write_text_float(rt, fixkomma, Len: Longint; var t : Text; r : ValReal); compilerproc;
function fpc_pchar_length(p:pchar):sizeint; compilerproc;

procedure fpc_Write_Text_AnsiStr(Len: Longint; var f: Text; const s: AnsiString); compilerproc;
function  fpc_ShortStr_To_AnsiStr(const s2 : ShortString): AnsiString; compilerproc;
procedure fpc_AnsiStr_To_ShortStr(out res: ShortString; const S2: Ansistring); compilerproc;
Function  fpc_Char_To_AnsiStr(const c : Char): AnsiString; compilerproc;
procedure fpc_AnsiStr_SetLength(var s: AnsiString; l: SizeInt); compilerproc;
procedure fpc_ansistr_incr_ref(var s: Pointer); compilerproc;
procedure fpc_ansistr_decr_ref(var s: Pointer); compilerproc;
procedure fpc_AnsiStr_Concat (var DestS:ansistring;const S1,S2 : AnsiString); compilerproc;
Function  fpc_AnsiStr_Compare_equal(const S1,S2 : AnsiString): SizeInt; compilerproc;
function fpc_AnsiStr_Concat_multi (const sarr:array of Ansistring): ansistring; compilerproc;
Function  fpc_ansistr_Unique(Var S : Pointer): Pointer; compilerproc;
function  AnsiLength(const s: AnsiString): Cardinal;
function fpc_mul_int64(f1,f2 : int64; checkoverflow : longbool) : int64; compilerproc;
function fpc_div_int64(n,z : int64) : int64;assembler; compilerproc;
function fpc_mul_qword(f1,f2 : qword; checkoverflow : longbool) : qword; compilerproc;

function  fpc_PushExceptAddr(Ft: LongInt; _buf,_newaddr: Pointer): PJmp_buf; compilerproc;
procedure fpc_ReRaise; compilerproc;
procedure fpc_PopAddrStack; compilerproc;
function  SetJmp(var s: Jmp_buf): LongInt; compilerproc;
procedure longJmp(var s: Jmp_buf; value: LongInt); compilerproc;

implementation

uses
  math;
 { {$IFDEF FPC_IS_KERNEL}
  , console, kheap
  {$ENDIF FPC_IS_KERNEL};}

var
  _textBuffer: array[0..255] of Byte;
  { widechar, because also used by widestring -> pwidechar conversions }
  emptychar : widechar;public name 'FPC_EMPTYCHAR';

{$I common.inc}
{$I strings.inc}

procedure RunError(const V: Integer);
begin
  Write('Runtime Error: ', V);
end;

procedure IncLocked(var AValue: Integer); inline;
begin
  Spinlock_Lock(IncDecLock);
  Inc(AValue);
  Spinlock_Unlock(IncDecLock);
end;

procedure DecLocked(var AValue: Integer); inline;
begin
  Spinlock_Lock(IncDecLock);
  Dec(AValue);
  Spinlock_Unlock(IncDecLock);
end;

procedure getmem(var p: pointer; const size: PtrUInt);
begin
  p:= fpc_getmem(size);
end;

procedure freemem(p: Pointer);
begin
  fpc_freemem(p);
end;

procedure reallocmem(var p: Pointer; const size: PtrUInt);
begin
  p:= KHeap_ReAlloc(p, size);
end;

procedure fpc_WriteChar(const c: Char); inline;
begin
  {$IFDEF FPC_IS_KERNEL}
  Console_WriteChar(C);
  {$ENDIF FPC_IS_KERNEL}
end;

procedure fpc_Write(const s: PChar); inline;
begin
  Console_WriteStr(s);
end;

{$I generic.inc}
{$I astrings.inc}
{$I sstrings.inc}
{$I int64p.inc}

function Chr(C: Byte): Char;
begin
  Chr := Char(C);
end;

function  fpc_getmem(size: PtrUInt): Pointer; compilerproc;
begin
  exit(KHeap_Alloc(size));
end;

procedure fpc_freemem(p: Pointer); compilerproc;
begin
  KHeap_Free(p);
end;

// ----------

function  fpc_get_output: PText; compilerproc;
begin
  exit(nil);
end;

procedure fpc_Write_Text_Char(Len: Longint; var f: Text; const c: Char); compilerproc;
begin
  fpc_WriteChar(c);
end;

procedure fpc_write_text_float(rt, fixkomma, Len: Longint; var t : Text; r : ValReal); compilerproc;
var
  positive: Single;
  back,
  front: LongInt;
  backF: Single;
begin
  positive := Abs(r);
  front := Round(positive);
  if front > positive then
    Dec(front);
  backF := positive - front;
  back := Round(backF * 10000);
  if r < 0 then
    Write('-', front, '.', back)
  else
    Write(front, '.', back);
end;

procedure fpc_Write_End(var f: Text); compilerproc;
begin
end;

procedure fpc_Writeln_End(var f: Text); compilerproc;
begin
  fpc_Write(#10#13);
end;

procedure fpc_Write_Text_SInt(Len: LongInt; var t: Text; l: PtrInt); compilerproc;
begin
  if l < 0 then
  begin
    fpc_WriteChar('-');
    l:= -l;
  end;
  fpc_Write_Text_UInt(len, t, l);
end;

procedure fpc_Write_Text_UInt(Len: LongInt; var t: Text; l: PtrUInt); compilerproc;
var
  buf: array[0..11] of char;
  p  : LongInt;
begin
  if l = 0 then
    fpc_Write('0')
  else
  begin
    p     := High(buf);
    buf[p]:= #0;
    while l > 0 do
    begin
      Dec(p);
      buf[p]:= Char((l mod 10) + Byte('0'));
      l:= l div 10;
    end;
    fpc_Write(PChar(@buf[p]));
  end;
end;

// ----------

function  fpc_PushExceptAddr(Ft: LongInt; _buf,_newaddr: Pointer): PJmp_buf; compilerproc; [public, Alias : 'FPC_PUSHEXCEPTADDR'];
begin
  exit(nil);
end;

procedure fpc_ReRaise; compilerproc; [public, alias: 'FPC_RERAISE'];
begin
end;

procedure fpc_PopAddrStack; compilerproc; [public, alias: 'FPC_POPADDRSTACK'];
begin
end;

function  SetJmp(var s: Jmp_buf): LongInt; compilerproc; compilerproc; [public, alias: 'FPC_SETJMP'];
begin
end;

procedure longJmp(var s: Jmp_buf; value: LongInt); compilerproc; [public, alias: 'FPC_LONGJMP'];
begin
end;

end.
