{$ASMMODE ATT}
function fpc_div_int64(n,z : int64) : int64;assembler; compilerproc;
var
    saveebx,saveedi,saveesi : longint;
asm
      movl %ebx,saveebx
      movl %esi,saveesi
      movl %edi,saveedi
      { the following piece of code is taken from the     }
      { AMD Athlon Processor x86 Code Optimization manual }
      movl n+4,%ecx
      movl n,%ebx
      movl %ecx,%eax
      orl %ebx,%eax
      jnz .Lnodivzero
      movl  %ebp,%edx
      movl  $200,%eax
      // call HandleErrorFrame
      jmp .Lexit
.Lnodivzero:
      movl z+4,%edx
      movl z,%eax
      movl %ecx,%esi
      xorl %edx,%esi
      sarl $31,%esi
      movl %edx,%edi
      sarl $31,%edi
      xorl %edi,%eax
      xorl %edi,%edx
      subl %edi,%eax
      sbbl %edi,%edx
      movl %ecx,%edi
      sarl $31,%edi
      xorl %edi,%ebx
      xorl %edi,%ecx
      subl %edi,%ebx
      sbbl %edi,%ecx
      jnz .Lbigdivisor
      cmpl %ebx,%edx
      jae .Ltwo_divs
      divl %ebx
      movl %ecx,%edx
      xorl %esi,%eax
      xorl %esi,%edx
      subl %esi,%eax
      sbbl %esi,%edx
      jmp .Lexit
.Ltwo_divs:
      movl %eax,%ecx
      movl %edx,%eax
      xorl %edx,%edx
      divl %ebx
      xchgl %ecx,%eax
      divl %ebx
      movl %ecx,%edx
      jmp .Lmake_sign
.Lbigdivisor:
      subl $12,%esp
      movl %eax,(%esp)
      movl %ebx,4(%esp)
      movl %edx,8(%esp)
      movl %ecx,%edi
      shrl $1,%edx
      rcrl $1,%eax
      rorl $1,%edi
      rcrl $1,%ebx
      bsrl %ecx,%ecx
      shrdl %cl,%edi,%ebx
      shrdl %cl,%edx,%eax
      shrl %cl,%edx
      roll $1,%edi
      divl %ebx
      movl (%esp),%ebx
      movl %eax,%ecx
      imull %eax,%edi
      mull 4(%esp)
      addl %edi,%edx
      subl %eax,%ebx
      movl %ecx,%eax
      movl 8(%esp),%ecx
      sbbl %edx,%ecx
      sbbl $0,%eax
      xorl %edx,%edx
      addl $12,%esp
.Lmake_sign:
      xorl %esi,%eax
      xorl %esi,%edx
      subl %esi,%eax
      sbbl %esi,%edx
.Lexit:
      movl saveebx,%ebx
      movl saveesi,%esi
      movl saveedi,%edi
end;
{$ASMMODE INTEL}

function fpc_mul_int64(f1,f2 : int64;checkoverflow : longbool) : int64; compilerproc;
var
  sign : boolean;
  q1,q2,q3 : qword;
begin
  begin
    sign:=false;
    if f1<0 then
    begin
      sign:=not(sign);
      q1:=qword(-f1);
    end
    else
    q1:=f1;
    if f2<0 then
    begin
      sign:=not(sign);
      q2:=qword(-f2);
    end
    else
    q2:=f2;
    { the q1*q2 is coded as call to mulqword }
    q3:=q1*q2;

    if sign then
    fpc_mul_int64:=-q3
    else
    fpc_mul_int64:=q3;
  end;
end;

function fpc_mul_qword(f1,f2 : qword;checkoverflow : longbool) : qword; compilerproc;
var
  _f1,bitpos : qword;
  l : longint;
  f1overflowed : boolean;
begin
  fpc_mul_qword:=0;
  bitpos:=1;
  f1overflowed:=false;

  for l:=0 to 63 do
    begin
      if (f2 and bitpos)<>0 then
        begin
          _f1:=fpc_mul_qword;
          fpc_mul_qword:=fpc_mul_qword+f1;
        end;
      { when bootstrapping, we forget about overflow checking for qword :) }
      f1overflowed:=f1overflowed or ((f1 and (1 shl 63))<>0);
      f1:=f1 shl 1;
      bitpos:=bitpos shl 1;
    end;
end;