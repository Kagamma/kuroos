#### Things that work
- PS2 mouse/keyboard driver
- VGA driver
- VBE driver
- IDE driver (basic support for FAT32 & CDFS)
- PIC/RTC
- Multi-tasking, multi-threading (Cooperative)
- Basic window manager

#### Things that need more work
- All process runs at ring 0 at the moment
- Memory manager is pretty barebone. Process is allocated an entire map (4MB) of memory, without any ways to request for more memory
- If a process is forced to kill vis 'kill' command, the window manager still keeps it's window around