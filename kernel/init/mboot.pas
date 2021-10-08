unit mboot;

{$I KOS.INC}

interface

const
  KERNEL_STACKSIZE = $10000;
  BOOTLOADER_MAGIC = $2BADB002;

type
  TMB_Section_Header_Table = packed record
    num  : Cardinal;
    size : Cardinal;
    addr : Cardinal;
    shndx: Cardinal;
  end;
  PMB_Section_Header_Table = ^TMB_Section_Header_Table;

  TMB_Info = packed record
    flags      : Cardinal;
    mem_lower  : Cardinal;
    mem_upper  : Cardinal;
    boot_device: Cardinal;
    cmdline    : Cardinal;
    mods_count : Cardinal;
    mods_addr  : Cardinal;
    elf_sec    : TMB_Section_Header_Table;
    mmap_length: Cardinal;
    mmap_addr  : Cardinal;
  end;
  PMB_Info = ^TMB_Info;

  TModule = packed record
    mod_start: Cardinal;
    mod_end  : Cardinal;
    name     : Cardinal;
    reserved : Cardinal;
  end;
  PModule = ^TModule;

  TMemoryMap = packed record
    size     : Cardinal;
    base_addr: QWord;
    length   : QWord;
    mtype    : Cardinal;
  end;
  PMemoryMap = ^TMemoryMap;

var
  GlobalMB: PMB_Info;

implementation

end.
