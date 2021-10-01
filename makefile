ROOTDIR = .
TOOLSDIR = $(ROOTDIR)/tools
KERNELDIR = $(ROOTDIR)/kernel
LIBDIR = $(ROOTDIR)/libs
GRUBDIR = $(ROOTDIR)/grub/boot

all:    
    $(TOOLSDIR)/fasm.exe $(KERNELDIR)/asm/real.asm $(LIBDIR)/real.o
	$(TOOLSDIR)/bin2pas.exe libs/real.o kernel/real.pas
	$(TOOLSDIR)/fasm.exe $(KERNELDIR)/asm/stub.asm $(LIBDIR)/stub.o
	$(TOOLSDIR)/fpc.exe -vb -Fu$(KERNELDIR)/rtl -Fu$(KERNELDIR)/asm -Fu$(KERNELDIR)/drivers -Fu$(KERNELDIR)/filesystem -Fu$(KERNELDIR)/interrupts -Fu$(KERNELDIR)/mm -Fu$(KERNELDIR)/vga -Fi$(KERNELDIR)/ -FU$(LIBDIR)/ -Aelf -O1 -n -OpPENTIUM -Si -Sc -Sg -Xd -CX -XXs -Rintel -Tlinux $(KERNELDIR)/kernel.pas
	$(TOOLSDIR)/i386-linux-ld.exe --gc-sections -s -T$(KERNELDIR)/linker.script -o $(LIBDIR)/kernel.obj $(LIBDIR)/stub.o $(LIBDIR)/real.o $(LIBDIR)/fat.o $(LIBDIR)/pmm.o $(LIBDIR)/vmm.o $(LIBDIR)/kheap.o $(LIBDIR)/rtc.o $(LIBDIR)/pic.o $(LIBDIR)/ide.o $(LIBDIR)/keyboard.o $(LIBDIR)/mouse.o $(LIBDIR)/vga.o $(LIBDIR)/vbe.o $(LIBDIR)/int0x03.o $(LIBDIR)/int0x0e.o $(LIBDIR)/int0x61.o $(LIBDIR)/common.o $(LIBDIR)/console.o $(LIBDIR)/gdt.o $(LIBDIR)/idt.o $(LIBDIR)/isr_irq.o $(LIBDIR)/mboot.o $(LIBDIR)/kernel.o $(LIBDIR)/system.o $(LIBDIR)/sysutils.o  
	cp $(LIBDIR)/kernel.obj $(GRUBDIR)/akarin
	$(TOOLSDIR)/mkisofs.exe -r -o akarinos.iso -b boot/grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table $(TRUNKDIR)/grub

clean:
	rm $(LIBDIR)/*.a
	rm $(LIBDIR)/*.o
	rm $(LIBDIR)/*.ppu


