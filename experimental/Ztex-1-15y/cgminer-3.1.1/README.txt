FPGA Open Source Litecoin Miner patches for https://github.com/ckolivas/cgminer version 3.1.1

I don't think its appropriate to fork the repository in this case so I will
just supply patches to specific release versions.

WARNING - This is a VERY rough initial port. Its horribly buggy.

Compilation
Open the official repository (link above) in your browser, click the "branches"
dropdown menu in the middle left of the page, select the "tags" tab and scroll down
to the version required (3.1.1) and select it. Download the zip (right side of page)
and unzip the archive.

Copy my patch files (from this github folder) into the official cgminer 3.1.1 folder,
replacing existing files as necessary. Build as normal, see the README or windows-build.txt
NB Opencl should be disabled in the configuration (it may work, but I've not tested it)
./autogen.sh
CFLAGS="-O2" ./configure --enable-ztex --enable-scrypt --disable-opencl
It will show scrypt as disabled, but this is a lie (my horrible hack hard codes it to be
enabled since my coding skills are not up to mofifying the config).

Prebuit windows binary at https://www.dropbox.com/s/j00wu49vsdow1ig/cgminer.exe

Dependancies (DLL) at https://www.dropbox.com/s/unfq6sk8jm3k6j2/cgminer-3.1.1-scryptfpga.zip

To use the windows version, unzip the dependancies then move cgminer.exe into the folder.
Copy the bitstream folder from the official cgminer-3.1.1 distribution.
IMPORTANT Replace ztex_ufm1_15y1.bit with the litecoin bitstream (it must have exactly this name)

You will need to install the WinUSB driver using zadig which is available at
http://sourceforge.net/projects/libwdi/files/zadig/

Run as ...
cgminer --scrypt --disable-gpu --url pool:port --userpass username:password 2>log.txt

Notes:
Should you have problems, redirect the stderr output to log.txt and examine this for messages.
You may want to add --verbose for additional output, --debug may crash on windows though.
Do not use this for GPU mining as it will not work.
Do not use this for bitcoin mining as it will not work.
Only the ztex 1.15y board is supported. Frequency management is automatic using the
same algorithm as bitcoin. It can be overriden by the --ztex-clock option as follows
--ztex-clock 120:140	sets initial clock of 120MHz, max of 140Mhz
--ztex-clock 128:128	fixed clock speed of 128MHz
--ztex-clock 120:140,124:132,128:128,120:120	set individual fpga device speeds
I don't know if this will work for multiple boards, but its done the same way as
the icarus options so with luck it will be OK.
The clock resolution is 4MHz (rounds down) and the valid range is 100MHz to 250MHz.
If --ztex-clock is not used the default range is 124MHz to 196MHz.
NB The clock speed is divided by 8 internally for hashing purposes.