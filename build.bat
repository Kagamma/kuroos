SET PATH=.;.\tools;..\..\tools;

@echo KOS build script
@echo ------------------
@echo Clear all object files...
mkdir libs
@del libs\*.bin
@del libs\*.a
@del libs\*.o
@del libs\*.ppu
@del libs\*.obj

@echo assemble stub.asm...

cd app
cd cmm
@c-- /OS /5 helloc.c
@c-- /OS /5 nep.c
@c-- /OS /5 clock.c
@c-- /OS /5 memtest.c
@move helloc.bin ../../grub/helloc.kex
@move nep.bin ../../grub/nep.kex
@move clock.bin ../../grub/clock.kex
@move memtest.bin ../../grub/memtest.kex
cd ..
cd ..

@fasm app/asm/hello.asm grub/hello.kex
@fasm app/asm/process.asm grub/process.kex
@fasm app/asm/threads.asm grub/threads.kex
@fasm app/asm/win.asm grub/win.kex

@fasm kernel/asm/real.asm libs/real.bin
@bin2pas libs/real.bin kernel/real.pas

@fasm kernel/asm/stub.asm libs/stub.o

@echo compile the kernel and all associated parts...
rem @fpc -Fukernel\debug -Fukernel\rtl -Fukernel\asm -Fukernel\bios -Fukernel\drivers -Fukernel\filesystem -Fukernel\tasks -Fukernel\gfx -Fukernel\interrupts -Fukernel\mm -Fukernel\vga -Fikernel\ -FUlibs\ -Aelf -n -O1 -OpPENTIUM -Si -Sc -Sg -Xd -CX -XXs -Rintel -Tlinux kernel/kernel.pas
@fpc -Fukernel\debug -Fukernel\rtl -Fukernel\wm -Fukernel\asm -Fukernel\bios -Fukernel\strings -Fukernel\drivers -Fukernel\filesystem -Fukernel\loader -Fukernel\tasks -Fukernel\console -Fukernel\gfx -Fukernel\interrupts -Fukernel\mm -Fukernel\vga -Fikernel\ -FUlibs\ -Aelf -Sg -Rintel -Tlinux kernel/kernel.pas

@echo link everything into kernel.obj...
@i386-linux-ld --gc-sections -s -Map=libs/kernel.map -Tkernel/linker.script -o libs/kernel.obj libs/trace.o libs/stub.o libs/real.o libs/bios.o libs/kex.o libs/schedule.o libs/mutex.o libs/spinlock.o libs/consolecmd.o libs/fat.o libs/cdfs.o libs/filesystem.o libs/pmm.o libs/vmm.o libs/kheap.o libs/rtc.o libs/pic.o libs/ide.o libs/keyboard.o libs/mouse.o libs/vga.o libs/vbe.o libs/kurogl.o libs/int0x03.o libs/int0x0e.o libs/int0x61.o libs/int0x69.o libs/int0x71.o libs/console.o libs/gdt.o libs/idt.o libs/isr_irq.o libs/mboot.o libs/kernel.o libs/system.o libs/sysutils.o libs/ImageLoader.o libs/math.o libs/sysfonts.o libs/objects.o libs/kurowm.o

@map libs/kernel.map grub/kernel.1 grub/kernel.2

@echo off

@echo Copying kernel file...
@copy libs\kernel.obj grub\boot\kos

@echo Building iso...
@mkisofs -r -o kos.iso -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table grub

pause