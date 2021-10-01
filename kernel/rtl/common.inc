

{$I fastmove.inc}

// Get value from port

function  inb(APort: Word): Byte; stdcall; inline; assembler; nostackframe;
asm
    mov   dx,APort
    xor   eax,eax
    in    al,dx
end ['edx'];

function  inw(APort: Word): Word; stdcall; inline; assembler; nostackframe;
asm
    mov   dx,APort
    xor   eax,eax
    in    ax,dx
end ['edx'];

function  inl(APort: Word): LongInt; stdcall; inline; assembler; nostackframe;
asm
    mov   dx,APort
    xor   eax,eax
    in    eax,dx
end ['edx'];

procedure inb(APort: Word; var ABuf; ACount: Cardinal); stdcall; inline; //nostackframe;
begin
  asm
    mov   ecx,ACount
    mov   edi,ABuf
    mov   dx,APort
    cld
    rep   insb
  end;
end;

procedure inw(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall; inline; //nostackframe;
begin
  asm
    mov   ecx,ACount
    mov   edi,ABuf
    mov   dx,APort
    cld
    rep   insw
  end;
end;

procedure inl(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall; inline; //nostackframe;
begin
  asm
    mov   ecx,ACount
    mov   edi,ABuf
    mov   dx,APort
    cld
    rep   insd
  end;
end;

// Set value to port

procedure outb(APort: Word; AValue: Byte); stdcall; inline; //nostackframe;
begin
  asm
    mov   dx,APort
    mov   al,AValue
    out   dx,al
  end;
end;

procedure outw(APort: Word; AValue: Word); stdcall; inline; //nostackframe;
begin
  asm
    mov   dx,APort
    mov   ax,AValue
    out   dx,ax
  end;
end;

procedure outl(APort: Word; AValue: LongInt); stdcall; inline; //nostackframe;
begin
  asm
    mov   dx,APort
    mov   eax,AValue
    out   dx,eax
  end;
end;

procedure outb(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall; inline; //nostackframe;
begin
  asm
    mov   ecx,ACount
    mov   esi,ABuf
    mov   dx,APort
    cld
    rep   outsb
  end;
end;

procedure outw(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall; inline; //nostackframe;
begin
  asm
    mov   ecx,ACount
    mov   esi,ABuf
    mov   dx,APort
    cld
    rep   outsw
  end;
end;

procedure outl(APort: Word; ABuf: Pointer; ACount: Cardinal); stdcall; inline; //nostackframe;
begin
  asm
    mov   ecx,ACount
    mov   esi,ABuf
    mov   dx,APort
    cld
    rep   outsd
  end;
end;

// Memory handle

{$asmmode att}
Procedure FillChar(var x;count:SizeInt;value:byte);assembler; nostackframe;
asm
        cmpl    $22,%edx          { empirically determined value on a Core 2 Duo Conroe }
        jg      .LFillFull
        orl     %edx,%edx
        jle     .LFillZero

.LFillLoop:
        movb    %cl,(%eax)
        incl    %eax
        decl    %edx
        jne     .LFillLoop
.LFillZero:
        ret

.LFillFull:
        cld
        push    %edi
        movl    %eax,%edi
        movzbl  %cl,%eax
        movl    %edx,%ecx
        imul    $0x01010101,%eax  { Expand al into a 4 subbytes of eax}
        shrl    $2,%ecx
        andl    $3,%edx
        rep
        stosl
        movl    %edx,%ecx
.LFill1:
        rep
        stosb
.LFillEnd:
        pop %edi
end;
{$asmmode intel}

procedure FillChar(var ABuf; ACount: Cardinal; AValue: Char);
begin
  FillChar(ABuf, ACount, Byte(AValue));
end;

{$asmmode att}
procedure filldword(var x;count : SizeInt;value : dword);assembler;
var
  saveedi : longint;
asm
        movl    %edi,saveedi
        movl    %eax,%edi
        movl    %ecx,%eax
        movl    %edx,%ecx
{ check for zero or negative count }
        cmpl    $0,%ecx
        jle     .LFillDWordEnd
        cld
        rep
        stosl
.LFillDWordEnd:
        movl    saveedi,%edi
end;
{$asmmode intel}

// Misc

function  BCDToBin(BCD: Byte): Byte;
begin
  BCDToBin:=((BCD shr 4)*10) + (BCD and $0F);
end;