<img height="300" src="https://i.imgur.com/AKzAEAK.png" />   <img height="300" src="https://i.imgur.com/HkhQRig.png" />

#### Download link
- https://drive.google.com/file/d/14O9d_dTaAWlkyUeu2qfs4uV3vY4Q32CU/view?usp=sharing

#### How to build
- Everything need to build is included in repo. If you are on Windows, run `build.bat` and it will create a `kos.iso` at root directory.

#### Things that work
- PS2 mouse/keyboard driver
- VGA driver
- VESA driver
- ATA/ATAPI driver
- Basic support for FAT32 (read only) & CDFS
- PIC/RTC
- Preemptive multi-tasking
- Basic window manager

#### Things that need more work
- All process runs at ring 0 at the moment
