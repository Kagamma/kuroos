{
    File:
        cpu.pas
    Description:
        CPU-related routines.
    License:
        General Public License (GPL)
}

unit cpu;

interface

procedure Init; stdcall;

var
  SSEAvail: Boolean;

implementation

uses
  console;

function CheckSSE: Boolean; assembler; nostackframe;
label
  nosse, endcheck;
asm
    mov eax,1
    cpuid
    test edx,1 shl 25
    jz  nosse
    jmp endcheck
nosse:
    xor eax,eax
endcheck:
end;

procedure EnableSSE; assembler; nostackframe;
asm
    mov eax,cr0
    and ax,$FFFB
    or  ax,2
    mov cr0,eax
    mov eax,cr4
    or  ax,3 shl 9
    mov cr4,eax
end;

procedure Init; stdcall;
begin
  Console.WriteStr('Enabling SSE... ');
  if CheckSSE then
  begin
    EnableSSE;
    Console.WriteStr(stOk);
    SSEAvail := True;
  end else
  begin
    Console.WriteStr(stFailed);
    SSEAvail := False;
  end;
end;

end.
