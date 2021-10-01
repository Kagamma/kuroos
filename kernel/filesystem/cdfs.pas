{
    File:
        cdfs.pas
    Description:
        Unit contains functions for cdfs manipulation.
        For now we only support iso9660.
    License:
        General Public License (GPL)

    ref:
        http://alumnus.caltech.edu/~pje/iso9660.html
        http://www.cdroller.com/htm/readdata.html
}

unit cdfs;

{$I KOS.INC}

interface

uses
  console,
  ide;

const
  CDFS_MAGIC = $89010552;
  CDFS_BUFFER_SIZE = 65536;

type
  PCDFSVolumeDescriptor = ^TCDFSVolumeDescriptor;
  TCDFSVolumeDescriptor = packed record
    Typ  : Byte;
    Ident: array[0..4] of Byte;
    Version: Byte;
    case Byte of
      0: (
        _pad1: array[0..2040] of Byte;
      );
      1: ( // Boot record
        BootSystemIdent: array[0..31] of Byte;
        BootIdent      : array[0..31] of Byte;
        BootSystemUse  : array[0..1976] of Byte;
      );
      2: ( // Primary Volume Descriptor
        _pad2               : Byte;
        SystemIdent         : array[0..31] of Byte;
        VolumeIdent         : array[0..31] of Byte;
        _pad3               : array[0..7] of Byte;
        VolumeSpaceSize     : array[0..1] of Cardinal;
        _pad4               : array[0..31] of Byte;
        VolumeSetSize       : array[0..1] of Word;
        VolumeSequenceNumber: array[0..1] of Word;
        LogicalBlockSize    : array[0..1] of Word;
        PathTableSize       : array[0..1] of Cardinal;
        LPathTableLoc       : Cardinal;  // LBA
        OpLPathTableLoc     : Cardinal;  // LBA
        MPathTableLoc       : Cardinal;  // LBA
        OpMPathTableLoc     : Cardinal;  // LBA
        RootDirEntry        : array[0..33] of Byte;
        VolumeSetIdent      : array[0..127] of Byte;
        PublisherIdent      : array[0..127] of Byte;
        DataPrepIdent       : array[0..127] of Byte;
        AppIdent            : array[0..127] of Byte;
        CpRightFileIdent    : array[0..37] of Byte;
        AbRightFileIdent    : array[0..35] of Byte;
        _pad5               : array[0..1271] of Byte;
      );
  end;

  PCDFSPathTable = ^TCDFSPathTable;
  TCDFSPathTable = packed record
    DirIdentLen : Byte;
    AttrRecExLen: Byte;
    LocOfExtent : Cardinal;
    DirNumber   : Byte;
   // DirIdent    : array [0..2039] of Byte;
  end;

  PCDFSDirectory = ^TCDFSDirectory;
  TCDFSDirectory = packed record
    DirRecLen   : Byte;
    AttrRecExLen: Byte;
    LocOfExtent : array[0..1] of Cardinal;
    DataLen     : array[0..1] of Cardinal;
    DateTime    : array[0..6] of Byte;
    FileFlag    : Byte;
    FileUnitSize: Byte;
    InterGap    : Byte;
    VolumeSeqNum: Cardinal;
    case Byte of
      0: (
        FileIdentLen: Byte;
        FileIdent   : array[0..11] of Char;
      );
      1: (
        FileIndentStr: String[12];
      );
  end;

  PCDFSStruct = ^TCDFSStruct;
  TCDFSStruct = record
    Dir   : TCDFSDirectory;
    Level : Byte;
    Parent: PCDFSStruct;
  end;

  PCDFSObject = ^TCDFSObject;
  TCDFSObject = object
  private
    FDirectoryArray: PCDFSStruct;
    FDirectoryCount: Integer;
  public
    constructor Init;
    // Scan for directories from a parent directory struct.
    procedure   ScanForDirectories(const ADriveInfoSt: PDriveInfoStruct;
        const AStruct: PCDFSStruct);
    // Set working drive
    // Flush all data from array
    procedure   Flush;
    // Special Loader for EXE. For now it's only support loading from level 0.
    function    Loader(const ADriveInfoSt: PDriveInfoStruct;
        const AFileName: KernelString): Pointer;
    //
    procedure   Test;

    property    DirectoryArray: PCDFSStruct read FDirectoryArray;
    property    DirectoryCount: Integer read FDirectoryCount;
  end;

var
  CDFSObj: PCDFSObject;

implementation

uses
  sysutils,
  kheap;

// Private

const
  A_CHARS: array[0..55] of Char = (
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', '0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', '_', '!', '"', '%',
    '&', '''','(', ')', '*', '+', ',', '-', '.', '/',
    ':', ';', '<', '=', '>', '?'
  );
  D_CHARS: array[0..36] of Char = (
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', '0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', '_'
  );

// Public

constructor TCDFSObject.Init;
begin
  // Allocate buffer to hold all directories found in CDROM
  FDirectoryArray:= KHeap.Alloc(SizeOf(TCDFSStruct) * 64);
  FDirectoryCount:= 0;
end;

procedure   TCDFSObject.ScanForDirectories(const ADriveInfoSt: PDriveInfoStruct;
    const AStruct: PCDFSStruct);
var
  VD  : PCDFSVolumeDescriptor;
  Buf : Pointer;
  CBuf: Pointer;
  Level,
  TotalSize,
  i, j, k: Cardinal;
  DirRec: PCDFSDirectory;
begin
  // Without a struct, we need to read the root from CD...
  if AStruct = nil then
  begin
    FDirectoryCount:= 0;
    Level:= 0;
    VD:= KHeap.Alloc(SizeOf(TCDFSVolumeDescriptor));
    // Try to read volume descriptor from CD
    IDE.LBA_ReadSector(ADriveInfoSt, VD, 16);
    // Try to read root directory entry record from CD
    DirRec:= PCDFSDirectory(@VD^.RootDirEntry[0]);
    // Try to read root directory record from CD (need to read mul.sectors)
    TotalSize:= DirRec^.DataLen[0];
    Buf:= KHeap.Alloc(TotalSize);
    for i:= 0 to TotalSize div ATAPI_SECTOR_SIZE - 1 do
      IDE.LBA_ReadSector(ADriveInfoSt,
          Buf + i * ATAPI_SECTOR_SIZE,
          DirRec^.LocOfExtent[0] + i);
    KHeap.Free(VD);
  end
  else
  // We have a struct, now we need to loop through array to find the struct
  // that has the same level with this one
  begin
    Level:= AStruct^.Level + 1;
    for j:= 0 to FDirectoryCount-1 do
    begin
      // We found it. Now we will replace it with our struct
      // This struct will act as parent for fallback.
      if AStruct^.Level = FDirectoryArray[j].Level then
      begin
        FDirectoryArray[j]:= AStruct^;
        Inc(FDirectoryCount);
        // Try to read root directory record from CD (need to read mul.sectors)
        TotalSize:= AStruct^.Dir.DataLen[0];
        Buf:= KHeap.Alloc(TotalSize);
        break;
      end;
    end;
    for i:= 0 to TotalSize div ATAPI_SECTOR_SIZE - 1 do
    begin
      IDE.LBA_ReadSector(ADriveInfoSt,
      Buf + i * ATAPI_SECTOR_SIZE,
      AStruct^.Dir.LocOfExtent[0] + i);
    end;
  end;
  CBuf:= Buf;
  for i:= 0 to TotalSize-4 do
  begin
    // We found a directory, it's time to save all of it's content to array
    if Cardinal(CBuf^) = CDFS_MAGIC then
    begin
      // Check to see if we exceed array size, if yes, we will allocate new buffer for it
      if FDirectoryCount >= KHeap.GetSize(FDirectoryArray) div SizeOf(TCDFSStruct) then
        KHeap.ReAlloc(FDirectoryArray, SizeOf(TCDFSStruct) * 2);
      // Scan for proper directory position in the buffer
      j:= 2;
      while not (Byte((CBuf - j)^) in [1..13]) do
      begin
        Inc(j);
      end;
      // Found it!
      DirRec:= Pointer(CBuf - j - 32);
      // Remove ";1" from file name
      if ((DirRec^.FileFlag and 2) <> 2) and (DirRec^.FileIdentLen > 1) then
        Dec(DirRec^.FileIdentLen, 2);
      // Now we copy the damn thing to array
      FDirectoryArray[FDirectoryCount].Dir:= DirRec^;
      FDirectoryArray[FDirectoryCount].Parent:= nil;
      FDirectoryArray[FDirectoryCount].Level:= Level;
      Inc(FDirectoryCount);
    end;
    Inc(CBuf);
  end;
  KHeap.Free(Buf);
end;

procedure   TCDFSObject.Flush;
begin
  KHeap.Free(FDirectoryArray);
  FDirectoryCount:= -1;
end;

function    TCDFSObject.Loader(const ADriveInfoSt: PDriveInfoStruct;
    const AFileName: KernelString): Pointer;
var
  i, j: Integer;
  Buf,
  SectorBuf: Pointer;
  UFileName: KernelString;
  St: PCDFSStruct;
  SectorNum: Cardinal;

begin
  Buf:= nil;
  UFileName:= UpperCase(AFileName);
  // Load root directory from CD
  ScanForDirectories(ADriveInfoSt, nil);
  // First we need to find the name in the list
  for i:= 0 to FDirectoryCount-1 do
  begin
    St:= @FDirectoryArray[i];
    // We found the name!
    if (St^.Level = 0) and
       (St^.Dir.FileFlag and $02 = 0) and
       (St^.Dir.FileIndentStr = UFileName) then
    begin
      // We find number of sectors contain the file's data
      SectorNum:= St^.Dir.DataLen[0] div ATAPI_SECTOR_SIZE;
      if St^.Dir.DataLen[0] mod ATAPI_SECTOR_SIZE > 0 then
        Inc(SectorNum);
      // Allocate buffer for reading data
      Buf:= KHeap.Alloc(St^.Dir.DataLen[0]);
      SectorBuf:= KHeap.Alloc(ATAPI_SECTOR_SIZE);
      // Looks like a compiler bug. For some reason we have to do this instead of for-loop or else j will only loop 1 time...
      j := 0;
      while j < SectorNum do
      begin
        // We read data to sector buffer
        IDE.LBA_ReadSector(ADriveInfoSt, SectorBuf, St^.Dir.LocOfExtent[0] + j);
        // Then we move data from sector buffer to buffer.
        if j <> SectorNum-1 then
        begin
          Move(SectorBuf^, Pointer(Buf + (j * ATAPI_SECTOR_SIZE))^, ATAPI_SECTOR_SIZE);
        end
        else
        begin
          Move(SectorBuf^, Pointer(Buf + (j * ATAPI_SECTOR_SIZE))^, St^.Dir.DataLen[0] mod ATAPI_SECTOR_SIZE);
        end;
        Inc(j);
      end;
      //
      KHeap.Free(SectorBuf);
      break;
    end;
  end;
  exit(Buf);
end;

procedure   TCDFSObject.Test;
var
  Buf: Pointer;
  DirRec: PCDFSDirectory;
  DriveInfoSt: PDriveInfoStruct = nil;
  i, j: Cardinal;
begin
  // Find CDROM drive
  DriveInfoSt:= IDE.FindDrive(True);
  // Try to read data from CD
  if DriveInfoSt <> nil then
  begin
    Buf:= KHeap.Alloc(ATAPI_SECTOR_SIZE);

    // TODO: If data length is longer than 2048, we need to read more from sector
    Console.SetFgColor(14);
    Writeln;
    Writeln('List of directories and files in CD''s root directory:');
    Console.SetFgColor(7);
    // Parse the data for files and dirs
    ScanForDirectories(DriveInfoSt, nil);
    // Show all folder and files
    for i:= 0 to FDirectoryCount-1 do
    begin
      DirRec:= @FDirectoryArray[i].Dir;
      Write(DirRec^.FileIndentStr);
      if (DirRec^.FileFlag and 2) = 2 then
      begin
        Console.SetCursorPos(30, Console.GetCursorPosY);
        Writeln('<DIR>');
      end
      else
      begin
        Console.SetCursorPos(30, Console.GetCursorPosY);
        Writeln(DirRec^.DataLen[0], ' bytes');
      end
    end;

    Console.SetFgColor(14);
    Writeln;
    Writeln('List of directories and files in CD''s BOOT directory:');
    Console.SetFgColor(7);
    // Parse the data for files and dirs
    ScanForDirectories(DriveInfoSt, @FDirectoryArray[0]);
    // Show all folder and files
    for i:= 0 to FDirectoryCount-1 do
    begin
      DirRec:= @FDirectoryArray[i].Dir;
      if FDirectoryArray[i].Level = 1 then
      begin
        Write(DirRec^.FileIndentStr);
        if (DirRec^.FileFlag and 2) = 2 then
        begin
          Console.SetCursorPos(30, Console.GetCursorPosY);
          Writeln('<DIR>');
        end
        else
        begin
          Console.SetCursorPos(30, Console.GetCursorPosY);
          Writeln(DirRec^.DataLen[0], ' bytes');
        end;
      end;
    end;

    //
    KHeap.Free(Buf);

    // Fallback to root folder
    ScanForDirectories(DriveInfoSt, nil);

    // Show README.TXT info
    Console.SetFgColor(14);
    Writeln;
    Writeln('Reading README.TXT...');
    Console.SetFgColor(7);
    Buf:= Self.Loader(DriveInfoSt, 'readme.txt');
    if Buf <> nil then
    begin
      for i:= 0 to KHeap.GetSize(Buf)-1 do
        Write(Char((Buf + i)^));
      Writeln;
      KHeap.Free(Buf);
    end
    else
      Writeln('File not found!');
  end;
end;

end.

