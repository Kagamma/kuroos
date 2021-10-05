{
    File:
        fat.pas
    Description:
        Unit contains functions for FAT manipulation.
    License:
        General Public License (GPL)
}

{ ref: http://msdn.microsoft.com/en-US/windows/hardware/gg463084 }

unit fat;

{$I KOS.INC}

interface

uses
  console,
  ide;

const
  FAT_ATTR_READONLY    = 1;
  FAT_ATTR_HIDDEN      = 2;
  FAT_ATTR_SYSTEM      = 4;
  FAT_ATTR_VOLUMELABEL = 8;
  FAT_ATTR_DIRECTORY   = 16;
  FAT_ATTR_ARCHIVE     = 32;
  FAT_ATTR_WEIRD0      = 64;
  FAT_ATTR_WEIRD1      = 128;

  FAT_DELETION_MARK    = $E5;

type
  { Start at offset 0 of the first sector. }
  PFATMBRStruct = ^TFATMBRStruct;
  TFATMBRStruct = packed record
    JmpBoot   : array[0..2] of Byte;
    OEMName   : array[0..7] of Byte;
    BytsPerSec: Word;
    SecPerClus: Byte;
    RsvdSecCnt: Word;
    NumFATs   : Byte;
    RootEntCnt: Word;
    TotSec16  : Word;
    Media     : Byte;
    FATSz16   : Word;
    SecPerTrk : Word;
    NumHeads  : Word;
    HiddSec   : Cardinal;
    TotSec32  : Cardinal;

    FATSz32   : Cardinal;
    ExtFlags  : Word;
    FSVer     : Word;
    RootClus  : Cardinal;
    FSInfo    : Word;
    BkBootSec : Word;
    _pad1     : array[0..11] of Byte;
    DrvNum    : Byte;
    _pad2     : Byte;
    BootSig   : Byte;
    VolID     : Cardinal;
    VolLab    : array[0..10] of Byte;
    FilSysType: array[0..7] of Byte;
  end;

  PFATSector1Struct = ^TFATSector1Struct;
  TFATSector1Struct = packed record
    FirstSignature: Cardinal; { $52, $52, $61, $41 }
    _pad1         : array[0..479] of Byte;
    FSInfoSector  : Cardinal; { $72, $72, $41, $61 }
    FreeClusters  : Integer;
  end;

  PFATStruct = ^TFATStruct;
  TFATStruct = packed record
    MBR      : TFATMBRStruct;
    Sector1  : TFATSector1Struct;
  end;

  PFATDirectoryStruct = ^TFATDirectoryStruct;
  TFATDirectoryStruct = packed record
    Name   : array[0..10] of Byte;
    Attr   : Byte;
    _pad1  : array[0..9] of Byte;
    Time,
    Date,
    Cluster: Word;
    Size   : Cardinal;
  end;

  PFile = ^TFile;
  TFile = packed record
    Name          : array[0..10] of Byte;
    Attr          : Byte;
    Time,
    Date,
    Cluster,
    CurrentCluster: Word;
    DataPtr,
    Size          : Cardinal;
    Opened        : Boolean;
    Drive         : PDriveInfoStruct;
  end;

{ 4 FAT structs for 4 drive }
var
  fatStructs: array[0..3] of TFATStruct;
  fatDrive  : PDriveInfoStruct = nil;

procedure Init; stdcall;
function  IsFileExists(const AFileName: KernelString; const AFile: PFile): Boolean; stdcall;
function  IsDirectoryExists(const ADirName: KernelString; const ADir: PFile): Boolean; stdcall;
function  FileOpen(const AFileName: KernelString; const AFile: PFile): Boolean; stdcall;
function  FileClose(const AFile: PFile): Boolean; stdcall;
procedure FileSeek(const AFile: PFile; const APos: Cardinal); stdcall;
function  FileRead(const AFile: PFile; ABuf: Pointer; ACount: Integer): Cardinal; stdcall;
function  EOF(const AFile: PFile): Boolean; stdcall;

implementation

uses
  sysutils,
  kheap;

{ Private }

const
  FAT_ILLEGAL_CHARNAME: array[0..39] of Byte =
    ($01, $02, $03, $04, $06, $07, $08, $09, $0A, $0B, $0C, $0D,
     $0E, $0F, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19,
     $22, $2A, $2B, $2C, $2E, $2F, $3A, $3B, $3C, $3D, $3E, $3F,
     $5B, $5C, $5D, $7C);

function  IsValidFAT(const ADrive: PDriveInfoStruct): Boolean; stdcall;
var
  fat: PFATMBRStruct;
begin
  fat:= ADrive^.FileSystem;
  exit((fat^.FilSysType[0] = Byte('F')) and
       (fat^.FilSysType[1] = Byte('A')) and
       (fat^.FilSysType[2] = Byte('T')) and
       (fat^.FilSysType[3] = Byte('3')) and
       (fat^.FilSysType[4] = Byte('2')));
end;

function  GetClusterSize(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(mbr^.BytsPerSec * mbr^.SecPerClus);
end;

{ Get number of root directory sectors }
function  GetRootDirSectors(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(((mbr^.RootEntCnt * 32) + mbr^.BytsPerSec - 1) div mbr^.BytsPerSec);
end;

{ Get first root dir cluster }
function  GetFirstRootDirCluster(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(mbr^.RootClus);
end;

{ Get first root dir sector }
function  GetFirstRootDirSector(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(mbr^.RootClus * mbr^.SecPerClus);
end;

{ Get first fat sector }
function  GetFirstFATSector(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(mbr^.RsvdSecCnt);
end;

{ Get first data sector }
function  GetFirstDataSector(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(mbr^.RsvdSecCnt + (mbr^.NumFATs * mbr^.FATSz32) + GetRootDirSectors(ADrive));
end;

{ The number of sectors in data region }
function  GetDataSectorCount(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  c    : Cardinal;
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(mbr^.TotSec32 - GetFirstDataSector(ADrive));
end;

{ The number of cluster in data region }
function  GetDataClusterCount(const ADrive: PDriveInfoStruct): Cardinal; stdcall; inline;
var
  fat  : PFATStruct;
  mbr  : PFATMBRStruct;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  exit(GetDataSectorCount(ADrive) div mbr^.SecPerClus);
end;

{ Read a number of clusters from data clusters. }
function  ReadDataClusters(const ADrive: PDriveInfoStruct; const ABuf: Pointer; const AFirstCluster, ACount: Cardinal): Boolean; stdcall; inline;
var
  result: Boolean;
  i     : Cardinal;
  fat   : PFATStruct;
  mbr   : PFATMBRStruct;
begin
  result:= False;
  fat   := ADrive^.FileSystem;
  mbr   := @fat^.MBR;
  for i:= 0 to ACount * mbr^.SecPerClus - 1 do
  begin
    result:= IDE.LBA_ReadSector(ADrive, ABuf + i*512, GetFirstDataSector(ADrive) + AFirstCluster*mbr^.SecPerClus + i - GetFirstRootDirSector(ADrive));
    if NOT result then
      break;
  end;
  exit(result);
end;

{ Write stuff from buffer to data clusters. }
function  WriteDataClusters(const ADrive: PDriveInfoStruct; const ABuf: Pointer; const AFirstCluster, ACount: Cardinal): Boolean; stdcall; inline;
var
  result: Boolean;
  i     : Cardinal;
  fat   : PFATStruct;
  mbr   : PFATMBRStruct;
begin
  result:= False;
  fat   := ADrive^.FileSystem;
  mbr   := @fat^.MBR;
  for i:= 0 to ACount * mbr^.SecPerClus - 1 do
  begin
    result:= IDE.LBA_WriteSector(ADrive, ABuf + i*512, GetFirstDataSector(ADrive) + AFirstCluster*mbr^.SecPerClus + i - GetFirstRootDirSector(ADrive));
    if NOT result then
      break;
  end;
  exit(result);
end;

{ Check if is EOF. }
function  isEOF(const AValue: Cardinal): Boolean; stdcall; inline;
begin
  if AValue > $0FFFFFF8 then
    exit(True)
  else
    exit(False);
end;

{ Get FAT value from FAT table. }
function  GetFATTableValue(const ADrive: PDriveInfoStruct; const AActiveCluster: Cardinal): Cardinal; stdcall; inline;
var
  fatTable : array[0..511] of Byte;
  fat      : PFATStruct;
  mbr      : PFATMBRStruct;
  fatOffset,
  fatSector,
  entOffset: Cardinal;
begin
  fat  := ADrive^.FileSystem;
  mbr  := @fat^.MBR;
  fatOffset:= AActiveCluster * 4;
  fatSector:= GetFirstFATSector(ADrive) + fatOffset div mbr^.BytsPerSec;
  entOffset:= fatOffset mod mbr^.BytsPerSec;

  { Read the FAT from the disk. }
  IDE.LBA_ReadSector(ADrive, @fatTable[0], fatSector);
  exit(Cardinal(Pointer(@fatTable[entOffset])^) and $0FFFFFFF);
end;

{ Convert an array of char to KernelString. }
function  Array2ShortStr(const p: Pointer; const ALen: Byte): KernelString; stdcall; inline;
var
  i: Byte;
begin
  Array2ShortStr:= '';
  Array2ShortStr[0]:= Char(ALen);
  for i:= 1 to ALen do
    Array2ShortStr[i]:= Char((p + i - 1)^);
end;

{ Convert a SFN format to normal file name. }
function  SFN2Name(const AStr: KernelString): KernelString; stdcall; inline;
var
  i, j: Cardinal;
begin
  SFN2Name[0]:= #0;
  for i:= 1 to 8 do
  begin
    if (AStr[i] <> #32) and (AStr[i] <> #0) then
    begin
      SFN2Name[i]:= AStr[i];
      Inc(Byte(SFN2Name[0]));
    end
    else
      break;
  end;
  if (AStr[9] <> #32) and (AStr[9] <> #0) then
  begin
    SFN2Name[i]:= '.';
    Inc(Byte(SFN2Name[0]));
    j:= i;
    for i:= 9 to 11 do
    begin
      if (AStr[i] <> #32) and (AStr[i] <> #0) then
      begin
  Inc(j);
  SFN2Name[j]:= AStr[i];
  Inc(Byte(SFN2Name[0]));
      end
      else
        break;
    end;
  end;
  SFN2Name[Byte(SFN2Name[0]) + 1]:= #0;
end;

{ Search for file/folder. }
function  SearchForEntry(const ADrive: PDriveInfoStruct; APath: KernelString; const AEntry: PFATDirectoryStruct): Boolean; stdcall;
var
  start   : Byte = 1;
  result  : Boolean;
  fat     : PFATStruct;
  mbr     : PFATMBRStruct;
  j,
  i, pos  : Cardinal;
  lastName,
  name    : KernelString;
  p       : Pointer;
  csize,
  cluster : Cardinal;
begin
  fat     := ADrive^.FileSystem;
  mbr     := @fat^.MBR;
  pos     := 0;
  name    := '';
  lastName:= '';
  { Calculate cluster size. }
  csize   := GetClusterSize(ADrive) div SizeOf(TFATDirectoryStruct);

  cluster := GetFirstRootDirCluster(ADrive);
  { Allocate enough space for a cluster. }
  p:= KHeap.Alloc(GetClusterSize(ADrive));

  { Put a delimitor if it isn't exist. }
  if (APath[Byte(APath[0])] <> '/') then
  begin
    APath[Byte(APath[0]) + 1]:= '/';
    Inc(Byte(APath[0]));
  end;
  for i:= 1 to Byte(APath[0]) do
  begin
    if (APath[i] = '/') then
    begin
      { Found a directory path, processing... }
      pos     := i;
      lastName:= UpperCase(name);
      name    := '';
      result  := False;
      repeat
  { Read a cluster from HD. }
        ReadDataClusters(ADrive, p, cluster, 1);
        { Loop through the entire cluster. }
        for j:= start to csize-1 do
        begin
          { We found an entry that has the same name! }
          if (PFATDirectoryStruct(p + 32 * j)^.Name[0] <> FAT_DELETION_MARK) and
            (Compare(SFN2Name(Array2ShortStr(@PFATDirectoryStruct(p + 32 * j)^.Name[0], 11)), lastName) = 0) then
          begin
            { TODO: Make sure this is a directory. }
          //if (i < Byte(APath[0])) and (PFATDirectoryStruct(p + 32 * j)^.Attr and FAT_ATTR_DIRECTORY <> 0) then
            begin
              cluster:= PFATDirectoryStruct(p + 32 * j)^.Cluster;
              result := True;
              break;
            end;
          end;
        end;
        start:= 0;
  { We found an entry so no need to loop through another cluster. }
        if result then
        begin
          { We meet the last entry of the path! }
          if i >= Byte(APath[0]) then
            AEntry^:= PFATDirectoryStruct(p + 32 * j)^;
          break;
            end;
      { Found no entry. Process to the next cluster. }
      cluster:= GetFATTableValue(ADrive, cluster);
      until IsEOF(cluster);
    end
    else
    begin
      name:= name + APath[i];
    end;
  end;
  { Free chunk. }
  KHeap.Free(p);
  exit(result);
end;

{ Public }

{ TODO: Many functions should move to a IDE.DetectDriveFormat function }
procedure Init; stdcall;
var
  driveNo,
  i         : Cardinal;
  buf1, buf2: array[0..511] of Byte;
  drive     : PDriveInfoStruct;
  fatSt     : PFATStruct;
  mbrSt     : PFATMBRStruct;
  sector1   : PFATSector1Struct;
  p         : Pointer;
  entry     : TFATDirectoryStruct;
  f         : TFile;
  s         : KernelString;
begin
  for driveNo:= 0 to DRIVE_MAX-1 do
  begin
    fatSt  := @fatStructs[driveNo];
    mbrSt  := @fatSt^.MBR;
    sector1:= @fatSt^.Sector1;

    { Get drive. }
    drive:= @DriveInformationStructs[driveNo];
    drive^.FileSystem:= fatSt;

    { Map buffer to mbrSt/Sector1 interface. }
    Move(buf1[0], mbrSt^, 512);
    Move(buf2[0], sector1^, 512);

    { Read first sector to the buffer. }
    if NOT drive^.ATAPI then
      if (NOT IDE.LBA_ReadSector(drive, mbrSt, 0)) or
         (NOT IDE.LBA_ReadSector(drive, sector1, 1)) then
        continue;

    Console.SetFgColor(14);
    Writeln('Disk #', driveNo, ' file system information:');
    Console.SetFgColor(7);

    { Check to see if this drive is FAT or not. }
    if (NOT IsValidFAT(drive) and not drive^.ATAPI) then
    begin
      Writeln(' - File System       : Unknown');
      continue;
    end;
    { Check to see if this drive is CDFS or not. }
    if drive^.ATAPI then
    begin
      Writeln(' - File System       : CDFS');
      continue;
    end;
    drive^.Formatted:= True;
    if fatDrive = nil then
      fatDrive:= drive;

    { Read the BS_FilSysType. }
    Write(' - File System       : ');
    for i:= 0 to 7 do
      Write(Char(fatSt^.MBR.FilSysType[i]));
    Writeln;

    Write(' - Label             : ');
    Console.WriteArrayChars(@fatSt^.MBR.VolLab[0], 11);
    Writeln;
    Writeln(' - Cluster Size      : ', GetClusterSize(drive), ' bytes');
    Writeln(' - Free Clusters     : ', sector1^.FreeClusters);

{	p:= KHeap.Alloc(4096);
  FillChar(p^, 4096, 0);
  s:= 'SDKS/SRC/HELLO.PAS';

  FAT.FileOpen(s, @f);
  Writeln;
  Writeln('Path: ', s);
        Writeln('File size: ', f.Size, ' bytes');
  Writeln('Current File Pointer: ', f.DataPtr);
  Writeln('Performing seek...');
  FAT.FileSeek(@f, 8);
  Writeln('Current File Pointer: ', f.DataPtr);
  Writeln('Read: ', FAT.FileRead(@f, p, 4096), ' bytes');
  Writeln('Data read from file: ');
  Console.SetFgColor(14);
  Console.WriteArrayChars(p, f.Size);
        Console.SetFgColor(7);
  Writeln;
  Writeln('Current File Pointer: ', f.DataPtr);
  Writeln;
  FAT.FileClose(@f);

  KHeap.Free(p);   }
  end;
  Writeln;
end;

function  IsFileExists(const AFileName: KernelString; const AFile: PFile): Boolean; stdcall;
var
  result: Boolean;
  entry : TFATDirectoryStruct;
begin
  result:= SearchForEntry(fatDrive, AFileName, @entry);
  if (result) and (entry.Attr and FAT_ATTR_DIRECTORY = 0) then
  begin
    Move(entry.Name[0], AFile^.Name, 11);
    AFile^.Attr   := entry.Attr;
    AFile^.Time   := entry.Time;
    AFile^.Date   := entry.Date;
    AFile^.Cluster:= entry.Cluster;
    AFile^.Size   := entry.Size;
    AFile^.Drive  := fatDrive;
    AFile^.CurrentCluster:= entry.Cluster;
    exit(True);
  end
  else
    exit(False);
end;

function  IsDirectoryExists(const ADirName: KernelString; const ADir: PFile): Boolean; stdcall;
var
  result: Boolean;
  entry : TFATDirectoryStruct;
begin
  result:= SearchForEntry(fatDrive, ADirName, @entry);
  if (result) and (entry.Attr and FAT_ATTR_DIRECTORY <> 0) then
  begin
    Move(entry.Name[0], ADir^.Name, 11);
    ADir^.Attr   := entry.Attr;
    ADir^.Time   := entry.Time;
    ADir^.Date   := entry.Date;
    ADir^.Cluster:= entry.Cluster;
    ADir^.Size   := entry.Size;
    ADir^.Drive  := fatDrive;
    ADir^.CurrentCluster:= entry.Cluster;
    exit(True);
  end
  else
    exit(False);
end;

function  FileOpen(const AFileName: KernelString; const AFile: PFile): Boolean; stdcall;
var
  result: Boolean;
begin
  result:= FAT.IsFileExists(AFileName, AFile);
  if result then
  begin
    AFile^.Opened := True;
    AFile^.DataPtr:= 0;
    AFile^.Drive  := fatDrive;
  end
  else
    AFile^.Opened:= False;
  exit(result);
end;

function  FileClose(const AFile: PFile): Boolean; stdcall;
begin
  AFile^.Opened:= False;
  exit(True);
end;

procedure FileSeek(const AFile: PFile; const APos: Cardinal); stdcall;
var
  clusCount: Cardinal;
  fatSt    : PFATStruct;
  mbrSt    : PFATMBRStruct;
  i        : Cardinal;
begin
  if NOT AFile^.Opened then
    exit;

  fatSt:= AFile^.Drive^.FileSystem;
  mbrSt:= @fatSt^.MBR;
  if APos > AFile^.Size then
    AFile^.DataPtr:= AFile^.Size
  else
    AFile^.DataPtr:= APos;
  { Reset currentCluster. }
  AFile^.CurrentCluster:= AFile^.Cluster;
  { Now we have to calculate the current cluster of this position. }
  clusCount:= APos div GetClusterSize(AFile^.Drive);
  { If clusCount > 0 then that mean we have to Move our currentCluster. }
  if clusCount > 0 then
  begin
    for i:= 1 to clusCount do
    begin
      AFile^.CurrentCluster:= GetFATTableValue(AFile^.Drive, AFile^.CurrentCluster);
    end;
  end;
  AFile^.DataPtr:= APos;
end;

function  FileRead(const AFile: PFile; ABuf: Pointer; ACount: Integer): Cardinal; stdcall;
var
  clusCount : Cardinal;
  fatSt     : PFATStruct;
  mbrSt     : PFATMBRStruct;
  numRead   : Cardinal;
  result    : Cardinal = 0;
  p         : Pointer;
  modulo,
  csize,
  i         : Cardinal;
begin
  if NOT AFile^.Opened then
    exit(result);

  fatSt:= AFile^.Drive^.FileSystem;
  mbrSt:= @fatSt^.MBR;
  { Allocate a chunk for cluster. }
  csize:= GetClusterSize(AFile^.Drive);
  p    := KHeap.Alloc(csize);

  if ACount > AFile^.Size - AFile^.DataPtr then
    ACount:= AFile^.Size - AFile^.DataPtr;
  while ACount > 0 do
  begin
    { Read cluster from current location. }
    ReadDataClusters(AFile^.Drive, p, AFile^.CurrentCluster, 1);
    { MoveP data from cluster buffer to result buffer. }
    modulo:= AFile^.DataPtr mod csize;
    if csize - modulo < ACount then
      numRead:= csize - modulo
    else
      numRead:= ACount;
    Move(Pointer(p + modulo)^, ABuf^, numRead);

    Inc(ABuf, numRead);
    Inc(AFile^.DataPtr, numRead);
    Inc(result, numRead);
    Dec(ACount, numRead);

    { MoveP to another cluster if we still have some data need to read. }
    if ACount > 0 then
    begin
      AFile^.CurrentCluster:= GetFATTableValue(AFile^.Drive, AFile^.CurrentCluster);
    end;
  end;

  KHeap.Free(p);
  exit(result);
end;

function  EOF(const AFile: PFile): Boolean; stdcall;
var
  clusCount: Cardinal;
  fatSt    : PFATStruct;
  mbrSt    : PFATMBRStruct;
begin
  if NOT AFile^.Opened then
    exit(True);

  fatSt:= AFile^.Drive^.FileSystem;
  mbrSt:= @fatSt^.MBR;
  exit(AFile^.DataPtr >= AFile^.Size);
end;

end.
