{
    File:
        spinlock.pas
    Description:
        N/A.
    License:
        General Public License (GPL)
}

unit spinlock;

{$I KOS.INC}

interface

type
  TSpinlock = Cardinal;
  PSpinLock = ^TSpinlock;

function  Create: PSpinLock; stdcall;
procedure Release(var ALock: PSpinLock); stdcall;
function  IsLocked(const ALock: PSpinLock): Boolean; stdcall;
procedure Lock(const ALock: PSpinLock); stdcall;
procedure Unlock(const ALock: PSpinLock); stdcall;

implementation

uses
  console,
  pmm;

function  Create: PSpinLock; stdcall; inline;
begin
  Create:= PMM.Alloc(4);
  Create^:= 0;
end;

procedure Release(var ALock: PSpinLock); stdcall; inline;
begin
  PMM.Free(ALock);
end;

function  IsLocked(const ALock: PSpinLock): Boolean; stdcall; inline;
begin
  exit(Boolean(ALock^));
end;

procedure Lock(const ALock: PSpinLock); stdcall; inline;
begin
  if ALock <> nil then
  begin
    while ALock^ = 1 do PROCESS_WAIT;
    ALock^:= 1;
  end;
end;

procedure Unlock(const ALock: PSpinLock); stdcall; inline;
begin
  ALock^:= 0;
end;

end.

