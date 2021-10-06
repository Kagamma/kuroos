{
    File:
        ide.pas
    Description:
        ATA/ATAPI driver unit.
    License:
        General Public License (GPL)

  ref: http://www.nondot.org/sabre/os/articles/DiskandDiscDrives/
       http://wiki.osdev.org/ATA_PIO_Mode
       http://wiki.osdev.org/ATAPI
       http://wiki.osdev.org/PCI_IDE_Controller
       http://www.ulinktech.com/downloads/ATA_command_table_alphabetic.pdf
       http://www.t13.org/Documents/UploadedDocuments/project/d1153r18-ATA-ATAPI-4.pdf
  TODO:
       Allow to read data from CDROM using PIO mode.
       Support for LBA48 and DMA mode.

}

unit ide;

{$I KOS.INC}

interface

uses
  console;

const
  DRIVE_MAX = 4;

  // ATA

  ATA_BUS_PRIMARY = $1F0;
  ATA_BUS_SECONDARY = $170;

  ATA_DATA        = $0;
  ATA_FEATURES    = $1;
  ATA_ERROR       = $1;
  ATA_NSECTOR     = $2;
  ATA_ADDR1       = $3;   ATA_SECTOR  = $3;
  ATA_ADDR2       = $4;   ATA_LCYL    = $4;
  ATA_ADDR3       = $5;   ATA_HCYL    = $5;
  ATA_DRV_SELECT  = $6;
  ATA_STATUS      = $7;   ATA_COMMAND = $7;
  ATA_READ        = $20;
  ATA_WRITE       = $30;
  ATA_DEV_CTL     = $206;

  ATA_STATUS_BSY  = $80;
  ATA_STATUS_DRDY = $40;
  ATA_STATUS_DRQ  = $08;
  ATA_STATUS_ERR  = $01;

  ATA_IDENTIFY    = $EC;

  ATA_CTL_SRST = $04;
  ATA_CTL_nIEN = $02;

  ATA_TIMEOUT = 10000;

  ATA_SECTOR_SIZE = 512;

  // ATAPI

  ATAPI_SECTOR_SIZE = 2048;
  ATAPI_COMMAND   = $A0;
  ATAPI_IDENTIFY  = $A1;
  ATAPI_READ      = $A8;
 // ATAPI_WRITE     = $AA;

type
  PDriveInfoStruct = ^TDriveInfoStruct;
  TDriveInfoStruct = record
    ControllerPort: Word;
    DriveNumber   : Byte;
    Present,
    Formatted     : Boolean;
    ATAPI,
    LBA,
    DMA           : Boolean;
    Size,                                    // Size in bytes.
    Cylinders,
    Heads,
    Sectors,
    Capacity      : Cardinal;
    Model         : array[0..39] of Byte;
    Serial        : array[0..19] of Byte;
    Firmware      : array[0..7] of Byte;
    FileSystem    : Pointer;
  end;

var
  // For now we only support up to 4 drives
  DriveInformationStructs: array[0..DRIVE_MAX-1] of TDriveInfoStruct;

procedure Test; stdcall;
// Install IRQs and read drive information.
procedure Init; stdcall;
function  DetectController(const AControllerPort: Word): Boolean; stdcall;
function  DetectDrive(const ADriveInfoSt: PDriveInfoStruct): Boolean; stdcall;
// Read data from DATA_REGISTER ($1F0 or $170).
procedure ReadDriveIdentity(const ADriveInfoSt: PDriveInfoStruct);
// Reset controller.
function  ResetController(const ADriveInfoSt: PDriveInfoStruct): Boolean;
// Wait for controller.
function  Polling(const ADriveInfoSt: PDriveInfoStruct;
                  const AMask, AValue: Byte; const ATimeout: Cardinal): Cardinal; stdcall;

// Read functions. Return false when failed to access the drive.
function  LBA_ReadSector(const ADriveInfoSt: PDriveInfoStruct;
                               const ABuf: Pointer;
			       const LBA: Cardinal): Boolean; stdcall;
// Write functions. Return false when failed to access the drive.
function  LBA_WriteSector(const ADriveInfoSt: PDriveInfoStruct;
                                const ABuf: Pointer;
				const LBA: Cardinal): Boolean; stdcall;
// Find drive
function  FindDrive(const IsATAPI: Boolean): PDriveInfoStruct; stdcall;

implementation

uses
  sysutils,
  idt,
  pic,
  kheap,
  schedule,
  spinlock;

// Private

var
  SLock: PSpinlock;
  _mutex: Boolean; // Only allow one process to access the drive.
  _IDE_Wait: array[0..1] of Boolean; // Wait for IRQ

// Delay for 400ns
procedure ATADelay(const ABus: Word); inline;
begin
  inb(ABus + $206);
  inb(ABus + $206);
  inb(ABus + $206);
  inb(ABus + $206);
end;

procedure FixIDEString(const APtr: Pointer; const ACount: Cardinal);
var
  b   : Byte;
  p, e: Pointer;
begin
  p:= APtr;
  e:= APtr + ACount;
  // Swap characters.
  while p <> e do
  begin
    b:= Byte(p^);
    Byte(p^):= Byte((p + 1)^);
    Byte((p + 1)^):= b;
    Inc(p, 2);
  end;
  Byte((e-1)^):= 0;
end;

procedure Primary_Callback(r: TRegisters); stdcall;
var
  i: Byte;
begin
  _IDE_Wait[0]:= True;
end;

procedure Secondary_Callback(r: TRegisters); stdcall;
var
  i: Byte;
begin
  _IDE_Wait[1]:= True;
end;

// Public

procedure Test; stdcall;
var
  p: PChar;
  i: Cardinal;
begin
  // Try to access CD
  if DriveInformationStructs[0].ATAPI then
  begin
    Console.SetFgColor(14);
    Writeln('Try to read the first 256 bytes from CD-ROM''s sector 16:');
    Console.SetFgColor(7);
    p:= KHeap.Alloc(2048);
    LBA_ReadSector(@DriveInformationStructs[0], p, 16);
    for i:= 0 to 255 do
    begin
      Console.WriteHex(i, 2);
      Write(': ');
      Console.WriteHex(Byte(p[i]), 2);
      Write('/');
      Console.WriteChar(p[i]);
      Write('  ');
    end;
    Writeln;
    KHeap.Free(p);
  end;
end;

procedure Init; stdcall;
  procedure ShowDriveInformation(const ADriveInformationStruct: PDriveInfoStruct); stdcall;
  var
    p: PByte;
    i: Integer;
  begin
    Console.WriteStr(' - Type     : ');
    if ADriveInformationStruct^.ATAPI then
    begin
      Writeln('CD-ROM');
    end
    else
      Writeln('Hard Disk');

    Console.WriteStr(' - Model    : ');
    Console.WriteStr(PChar(@ADriveInformationStruct^.Model[0]));
    Writeln;

    Console.WriteStr(' - Serial   : ');
    Console.WriteStr(PChar(@ADriveInformationStruct^.Serial[0]));
    Writeln;

    Console.WriteStr(' - Firmware : ');
    Console.WriteStr(PChar(@ADriveInformationStruct^.Firmware[0]));
    Writeln;

    //if ADriveInformationStruct^.ATAPI then
    //  exit;
    if not ADriveInformationStruct^.ATAPI then
    begin
      Writeln(' - Cylinders: ', ADriveInformationStruct^.Cylinders,
	      '; Heads: ', ADriveInformationStruct^.Heads,
	      '; Sectors: ', ADriveInformationStruct^.Sectors);
      Writeln(' - Size     : ', ADriveInformationStruct^.Size, ' bytes');
    end;
  end;

begin
  // Install IRQs
  IRQ_DISABLE;

  SLock:= Spinlock.Create;

  Console.WriteStr('Installing IDE handler (0x2E & 0x2F)... ');
  IDT.InstallHandler($2E, @IDE.Primary_Callback);
  IDT.InstallHandler($2F, @IDE.Secondary_Callback);
  Console.WriteStr(stOK);

  IRQ_ENABLE;

  //
  Console.WriteStr('Detecting drives...'+#10#13);

  DriveInformationStructs[0].ControllerPort:= ATA_BUS_PRIMARY;
  DriveInformationStructs[0].DriveNumber   := 0;

  DriveInformationStructs[1].ControllerPort:= ATA_BUS_PRIMARY;
  DriveInformationStructs[1].DriveNumber   := 1;

  DriveInformationStructs[2].ControllerPort:= ATA_BUS_SECONDARY;
  DriveInformationStructs[2].DriveNumber   := 0;

  DriveInformationStructs[3].ControllerPort:= ATA_BUS_SECONDARY;
  DriveInformationStructs[3].DriveNumber   := 1;

  if IDE.DetectController(ATA_BUS_PRIMARY) then
  begin
    if IDE.DetectDrive(@DriveInformationStructs[0]) then
    begin
      Console.SetFgColor(14);
      Console.WriteStr('Primary controller: Master drive detected.'+#10#13);
      Console.SetFgColor(7);
      IDE.ReadDriveIdentity(@DriveInformationStructs[0]);
      ShowDriveInformation(@DriveInformationStructs[0]);
    end;
    if IDE.DetectDrive(@DriveInformationStructs[1]) then
    begin
      Console.SetFgColor(14);
      Console.WriteStr('Primary controller: Slave drive detected.'+#10#13);
      Console.SetFgColor(7);
      IDE.ReadDriveIdentity(@DriveInformationStructs[1]);
      ShowDriveInformation(@DriveInformationStructs[1]);
    end;
  end;
  if IDE.DetectController(ATA_BUS_SECONDARY) then
  begin
    if IDE.DetectDrive(@DriveInformationStructs[2]) then
    begin
      Console.SetFgColor(14);
      Console.WriteStr('Secondary controller: Master drive detected.'+#10#13);
      Console.SetFgColor(7);
      IDE.ReadDriveIdentity(@DriveInformationStructs[2]);
      ShowDriveInformation(@DriveInformationStructs[2]);
    end;
    if IDE.DetectDrive(@DriveInformationStructs[3]) then
    begin
      Console.SetFgColor(14);
      Console.WriteStr('Secondary controller: Slave drive detected.'+#10#13);
      Console.SetFgColor(7);
      IDE.ReadDriveIdentity(@DriveInformationStructs[3]);
      ShowDriveInformation(@DriveInformationStructs[3]);
    end;
  end;
  Writeln;
end;

function  DetectController(const AControllerPort: Word): Boolean; stdcall;
var
  port: Word;
begin
  port:= AControllerPort + ATA_SECTOR;
  outb(port, $07);
  exit(inb(port) = $07);
end;

function  DetectDrive(const ADriveInfoSt: PDriveInfoStruct): Boolean; stdcall;
var
  port : Word;
  drive: Byte;
  buf  : array[0..511] of Byte;
  I    : Byte;
  Status: Boolean;
begin
  port := ADriveInfoSt^.ControllerPort;
  drive:= ADriveInfoSt^.DriveNumber;
  // Detect drive. $A0 = master, $B0 = slave.
  outb(port + ATA_DRV_SELECT, $A0 + $10 * drive);
  //PIC.Sleep(1);
  ATADelay(port);
  for I := 0 to ATA_TIMEOUT - 1 do
    Status := Boolean(inb(port + ATA_STATUS));
  if Status then
  begin
    ADriveInfoSt^.Present:= True;
    exit(True);
  end
  else
  begin
    ADriveInfoSt^.Present:= False;
    exit(False);
  end;
end;

// Read data from DATA_REGISTER ($1F0 or $170).
procedure ReadDriveIdentity(const ADriveInfoSt: PDriveInfoStruct);
var
  i    : Cardinal;
  port : Word;
  cl,
  ch,
  drive: Byte;
  buf  : array[0..255] of Word;
begin
  port := ADriveInfoSt^.ControllerPort;
  drive:= ADriveInfoSt^.DriveNumber;
  IDE.ResetController(ADriveInfoSt);
  // Select drive.
  outb(port + ATA_DRV_SELECT, $A0 or (drive shl 4));
  // Send the IDENTITY command to the command port ($07).

  // See ATA/ATAPI-4 spec, section 8.12.5.2 and 9.1.
  ADriveInfoSt^.Formatted:= False;
  ADriveInfoSt^.Present  := False;
  if (inb(port + ATA_NSECTOR) = 1) and (inb(port + ATA_SECTOR) = 1) then
  begin
    cl:= inb(port + ATA_LCYL);
    ch:= inb(port + ATA_HCYL);
    // Check if this drive is a CD-ROM
    if (cl = $14) and (ch = $EB) then
      ADriveInfoSt^.ATAPI:= True
    else
      ADriveInfoSt^.ATAPI:= False;
  end;

  if ADriveInfoSt^.ATAPI then
    outb(port + ATA_COMMAND, ATAPI_IDENTIFY)
  else
    outb(port + ATA_COMMAND, ATA_IDENTIFY);
  // Wait for the controller.
  // See ATA/ATAPI-4 spec, section 9.7
  if (IDE.Polling(ADriveInfoSt,
      ATA_STATUS_BSY or ATA_STATUS_DRQ or ATA_STATUS_ERR,
      ATA_STATUS_DRQ, ATA_TIMEOUT) = 0) then
    exit;

  // Read the identity.
  for i:= 0 to 255 do
  begin
    buf[i]:= inw(port);
  end;
  ADriveInfoSt^.LBA:= Boolean((buf[49] shr 9) and 1);
  ADriveInfoSt^.DMA:= Boolean((buf[49] shr 8) and 1);
  ADriveInfoSt^.Cylinders:= buf[1];
  ADriveInfoSt^.Heads    := buf[3];
  ADriveInfoSt^.Sectors  := buf[6];
  ADriveInfoSt^.Size     := buf[1] * buf[3] * buf[6] * 512;
  if ADriveInfoSt^.LBA then
    ADriveInfoSt^.Capacity:= buf[60]
  else
    ADriveInfoSt^.Capacity:= 0;
  Move(buf[27], ADriveInfoSt^.Model[0], 40);
  Move(buf[10], ADriveInfoSt^.Serial[0], 20);
  Move(buf[23], ADriveInfoSt^.Firmware[0], 8);

  IDE.FixIDEString(@ADriveInfoSt^.Model[0], 40);
  IDE.FixIDEString(@ADriveInfoSt^.Serial[0], 20);
  IDE.FixIDEString(@ADriveInfoSt^.Firmware[0], 8);
end;

// Reset controller.
function  ResetController(const ADriveInfoSt: PDriveInfoStruct): Boolean;
var
  port : Word;
  drive: Byte;
begin
  port := ADriveInfoSt^.ControllerPort;
  drive:= ADriveInfoSt^.DriveNumber;

  outb(port + ATA_DEV_CTL, ATA_CTL_SRST);
  //PIC.Sleep(5);
  ATADelay(port);

  if IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY, ATA_STATUS_BSY, ATA_TIMEOUT) = 0 then
    exit(False);
  outb(port + ATA_DEV_CTL, 0);
  if IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY, 0, ATA_TIMEOUT) = 0 then
    exit(False);
  exit(True);
end;

// Wait for controller.
function  Polling(const ADriveInfoSt: PDriveInfoStruct;
                  const AMask, AValue: Byte; const ATimeout: Cardinal): Cardinal; stdcall;
var
  port     : Word;
  countDown: Cardinal;
  status   : Byte;
begin
  port:= ADriveInfoSt^.ControllerPort + 7;
  countDown:= ATimeout;
  repeat
    Dec(countDown);
    status:= inb(port) and AMask;
  until (countDown = 0) or (status = AValue);
  exit(countDown);
end;

function  LBA_ATA_AccessSector(const ADriveInfoSt: PDriveInfoStruct;
                                 const ACommand: Byte; // 0 = Read, 1 = Write
                                 const ABuf: Pointer;
			         const LBA: Cardinal): Boolean; stdcall; inline;
var
  port : Word;
  drive: Byte;
  i, j: Cardinal;
  tmp : Word;
  buf : Pointer;
  driveMask: Byte;
begin
  while _mutex do ;
  _mutex:= True;

  port := ADriveInfoSt^.ControllerPort;
  drive:= ADriveInfoSt^.DriveNumber;

  if (NOT IDE.DetectController(port)) or (NOT IDE.DetectDrive(ADriveInfoSt)) then
  begin
    _mutex:= False;
    exit(False);
  end;

  { Enter PIO mode. }
  outb(port+ATA_FEATURES, $00);
  { Send sector count. }
  outb(port+ATA_NSECTOR, 1);
  { Send block address to port. }
  outb(port+ATA_ADDR1, Byte(LBA));
  outb(port+ATA_ADDR2, Byte(LBA shr 8));
  outb(port+ATA_ADDR3, Byte(LBA shr 16));

 { driveMask:= $E0;
  if ADriveInfoSt^.DriveNumber = 1 then
    driveMask:= driveMask or $10;

  outb(port+ATA_DRV_SELECT, Byte(driveMask or (LBA and $0F000000) shl 24));}
  outb(port+ATA_DRV_SELECT, $E0 or (drive shl 4) or ((LBA shr 24) and $0F));

  case ACommand of
    0:
      begin
        { Send the command "Read" ($20) to ATA_COMMAND. }
        outb(port+ATA_COMMAND, ATA_READ);
        buf:= ABuf;
	      { Wait for the controller. }
        ATADelay(port);
        if IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY, 0, ATA_TIMEOUT) = 0 then
        begin
          _mutex:= False;
          exit(False);
        end;
	      { Verify if there are errors }
        if (inb(port + ATA_STATUS) and ATA_STATUS_ERR) <> 0 then
        begin
          _mutex:= False;
          exit(False);
        end;
        { Read data from cache. }
        inw(port, buf, ATA_SECTOR_SIZE div 2);
      end;
    1:
      begin
	outb(port+ATA_COMMAND, ATA_WRITE);
        buf:= ABuf;
        { Wait for the controller. }
	//PIC.Sleep(1);
        ATADelay(port);
        if IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY, 0, ATA_TIMEOUT) = 0 then
        begin
          _mutex:= False;
          exit(False);
        end;
	     { Verify if there are errors }
        if (inb(port + ATA_STATUS) and ATA_STATUS_ERR) <> 0 then
        begin
          _mutex:= False;
          exit(False);
        end;
        // We use otw instead of outsw because we need delay between each write. }
       { Write 512 bytes to the disk. }
        for i:= 0 to 255 do
        begin
          outw(port, Word(buf^));
	  Inc(buf, 2);
        end;
        //outw(port, buf, ATA_SECTOR_SIZE div 2 * ASector);
      end;
  end;
  { Flush the cache. }
  outb(port+ATA_COMMAND, $E7);
  { Wait at least 400ns for the hardware to flush the cache. }
  if IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY, 0, ATA_TIMEOUT) = 0 then
  begin
    _mutex:= False;
    exit(False);
  end;
  _mutex:= False;
  exit(True);
end;

// For ATAPI
function  LBA_ATAPI_AccessSector(const ADriveInfoSt: PDriveInfoStruct;
                                 const ACommand: Byte; // 0 = Read, 1 = Write
                                 const ABuf: Pointer;
			         const LBA: Cardinal): Boolean; stdcall; inline;
var
  port : Word;
  msArr,
  drive: Byte;
  buf  : Pointer;
  i, j: Cardinal;
  ATAPICmd: array[0..11] of Byte;
begin
  while _mutex do ;
  _mutex:= True;

  port := ADriveInfoSt^.ControllerPort;
  drive:= ADriveInfoSt^.DriveNumber;
  buf:= ABuf;
  case port of
    ATA_BUS_PRIMARY:
      msArr:= 0;
    ATA_BUS_SECONDARY:
      msArr:= 1;
  end;

  if (NOT IDE.DetectController(port)) or (NOT IDE.DetectDrive(ADriveInfoSt)) then
  begin
    _mutex:= False;
    exit(False);
  end;
  { We now tell the hardware that we want to do it in PIO mode. }
  outb(port+ATA_FEATURES, 0);

  { Send sector count. }
  //outb(port+ATA_NSECTOR, 1);

  { Send block address to port. }
  //outb(port+ATA_SECTOR, Byte(LBA));
  outb(port+ATA_ADDR2, Word(ATAPI_SECTOR_SIZE) and $FF);
  outb(port+ATA_ADDR3, Word(ATAPI_SECTOR_SIZE) shr 8);
  case ACommand of
    0:
      begin
        { First we need to tell the hardware that we want to send an ATAPI
          command. }
        outb(port+ATA_COMMAND, ATAPI_COMMAND);
        { Poll. }
        if IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY, 0, ATA_TIMEOUT) = 0 then
        begin
          _mutex:= False;
          exit(False);
        end;
        { Now we send the command (6 word) to the port. }
        ATAPICmd[0] := ATAPI_READ;
        ATAPICmd[1] := $0;
        ATAPICmd[2] := (LBA shr $18) and $FF;
        ATAPICmd[3] := (LBA shr $10) and $FF;
        ATAPICmd[4] := (LBA shr $08) and $FF;
        ATAPICmd[5] := (LBA shr $00) and $FF;
        ATAPICmd[6] := $0;
        ATAPICmd[7] := $0;
        ATAPICmd[8] := $0;
        ATAPICmd[9] := $1; // 1 sector
        ATAPICmd[10]:= $0;
        ATAPICmd[11]:= $0;
        _IDE_Wait[msArr]:= False;
        outw(port, @ATAPICmd[0], 6);
        { Wait for irq or poll to occur }
        while not _IDE_Wait[msArr] do ;
        { TODO: Read the actual data size we read from disk. }
        j:= (inb(port+ATA_ADDR3) shl 8) or inb(port+ATA_ADDR2);
        { Read data from cache. }
        _IDE_Wait[msArr]:= False;
        inw(port, buf, ATAPI_SECTOR_SIZE div 2);
        { Wait for irq to occur (Why didn't it fire???) }
        //while not _IDE_Wait[msArr] do ;
        { Wait for BSY and DRQ to clear. }
        IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY or ATA_STATUS_DRQ, 0, ATA_TIMEOUT);
      end;
    1:
      begin

      end;
  end;
  { Flush the cache. }
  outb(port+ATA_COMMAND, $E7);
  { Wait at least 400ns for the hardware to flush the cache. }
  if IDE.Polling(ADriveInfoSt, ATA_STATUS_BSY, 0, ATA_TIMEOUT) = 0 then
  begin
    _mutex:= False;
    exit(False);
  end;
  _mutex:= False;
  exit(True);
end;

function  LBA_ReadSector(const ADriveInfoSt: PDriveInfoStruct;
                         const ABuf: Pointer;
			                   const LBA: Cardinal): Boolean; stdcall;
begin
  Spinlock.Lock(SLock);
  if ADriveInfoSt^.ATAPI then
    LBA_ReadSector:= IDE.LBA_ATAPI_AccessSector(ADriveInfoSt, 0, ABuf, LBA)
  else
    LBA_ReadSector:= IDE.LBA_ATA_AccessSector(ADriveInfoSt, 0, ABuf, LBA);
  Spinlock.Unlock(SLock);
end;

function  LBA_WriteSector(const ADriveInfoSt: PDriveInfoStruct;
                          const ABuf: Pointer;
				                  const LBA: Cardinal): Boolean; stdcall;
begin
  Spinlock.Lock(SLock);
  if ADriveInfoSt^.ATAPI then
    LBA_WriteSector:= IDE.LBA_ATAPI_AccessSector(ADriveInfoSt, 0, ABuf, LBA)
  else
    LBA_WriteSector:= IDE.LBA_ATA_AccessSector(ADriveInfoSt, 1, ABuf, LBA);
  Spinlock.Unlock(SLock);
end;

function  FindDrive(const IsATAPI: Boolean): PDriveInfoStruct; stdcall;
var
  i: Integer;
begin
  FindDrive:= nil;
  for i:= 0 to DRIVE_MAX-1 do
  begin
    DetectDrive(@DriveInformationStructs[i]);
    if (DriveInformationStructs[i].ATAPI = IsATAPI) and
       (DriveInformationStructs[i].Present) then
    begin
      exit(@DriveInformationStructs[i]);
    end;
  end;
end;

end.
