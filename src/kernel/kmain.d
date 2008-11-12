/**
This file declares the main kernel code for XOmB.
The original purpose of this code is to boot the system, check for memory errors in booting,
and print out information to assist in debugging processor problems.

Written: 2007
*/
module kernel.kmain;

// log
import kernel.core.log;

import kernel.arch.x86_64.vmem;
import kernel.mem.pmem;

import kernel.core.multiboot;

import kernel.dev.vga;

import kernel.dev.keyboard;

//imports
import config;
import kernel.arch.x86_64.globals;

import gdb.kgdb_stub;

import kernel.arch.select;

import kernel.error;
import kernel.core.elf;
import kernel.core.system;
import kernel.core.util;
import multiboot = kernel.core.multiboot;

import kernel.arch.x86_64.mp;
import kernel.arch.x86_64.acpi;
import kernel.arch.x86_64.hpet;

/**
This is the main function of PGOS. It is executed once GRUB loads
fully. It accepts "magic," the magic number of the GRUB bootloader,
and "addr," the address of the multiboot variable, passed by the GRUB bootloader.
	Params:
		magic = the magic number returned by the GRUB bootloader
		addr = the address of the multiboot header, passed to the kernel to by the
			GRUB bootloader.
*/


extern(C) void kmain(uint magic, uint addr)
{	
	auto mbi = cast(multiboot_info_t*)addr;
	int mb_flag = 0;

	// Clear the screen in order to begin printing.
	Console.cls(true);

	// Print initial booting information.
	Console.setColors(Color.HighGreen, Color.Black);
	kprintf!(" XOmB 0.0 $Rev$")();
	Console.resetColors();
	int x,y;
	Console.getPosition(x,y);
	Console.setPosition(80-40, y);

	// Print out our slogan. Literally, "We came, we saw, we conquered."
	Console.setColors(Color.Yellow, Color.LowBlue);
	kprintfln!("Venimus, vidimus, vicimus!  --PittGeeks")();
	Console.setColors(Color.LowGreen, Color.Black);
	kprintf!("--------------------------------------------------------------------------------")();
	Console.resetColors();

	// get the globals from the linker definitions
	printLogLine("Initializing Globals");
	Globals.init();
	printLogSuccess();

	// Make sure the multiboot header is valid
	// and print out memory info, etc
	multiboot.init(magic, addr);

	if(enable_kgdb)
	{
		printLogLine("Enabling kgdb");
		set_debug_traps();
		breakpoint();
		printLogSuccess();
	}

	// check to see if the CPU has the features we require
	// if this fails, the CPU will hang.
	Cpu.validate();

	printLogLine("Installing Heap Allocator");
	// Set up the heap memory allocator
	if (pMem.install(mbi) == ErrorVal.Success)
	{
		printLogSuccess();
	}
	else
	{
		printLogFail();
	}

	//pMem.test();

	// boot and initialize the primary CPU
	Cpu.install();
	
	// Now that page tables are implemented,
	// Map in the BIOS regions.

	multiboot.mapRegions();

	// Turn general interrupts on, so the computer can deal with errors and faults.
	Cpu.enableInterrupts();

	//kprintfln!("Setting lstar, star and SF_MASK...")();
	
	// TESTING MUTEXES
	printLogLine("Testing Kernel Locks");
	int failcode = test_kmutex();
	if (failcode == 0)
	{
		printLogSuccess();
	}
	else
	{
		printLogFail();	
	}

	if (ACPI.init() == ErrorVal.Success)
	{
		// use ACPI Tables

		// initialize IO APICs
		ACPI.initIOAPIC();

		// initialize Local APICs
		ACPI.initAPIC();
	}
	else
	{
		// fall back on the MP tables
	
		// initialize multiprocessor information
		MP.init();

		// initialize IO APICs
		MP.initIOAPIC();
	
		// initialize Local APICs
		MP.initAPIC();
	}
	
	printLogLine("Initializing HPET");
	if (HPET.init() == ErrorVal.Success)
	{
		printLogSuccess();
		//HPET.initTimer(0, 5000);
	}
	else
	{
		printLogFail();
	}

	kprintfln!("")();
	
	kprintfln!("Keyboards?")();
	Keyboard.init();

	//for (;;) {}

	kprintfln!("Jumping to User Mode...\n")();

	asm
	{
		// Jump to user mode.
		"movq $testUser, %%rcx" ::: "rcx";

		// r11 contains the EFLAGS
		// the EFLAGS will be set upon the sysretq
		// we used to push $0 (but that disables interrupts!!!)

		// we could push the current EFLAGS to r11
		//"pushf";
		//"pop %%r11";

		// but for now, let's just enable interrupts
		// beware of the IOPL flag! (figure 2-4, section 2-13 of System Guide A Intel)
		// http://en.wikipedia.org/wiki/FLAGS_register_(computing)

		"movq $((1 << 9) | (3 << 12)), %%r11" ::: "r11";
		"sysretq";
	}

	kprintfln!("BACK!!!")();
}

import user.syscall;

extern(C) void testUser()
{
	//Cpu.enableInterrupts();
	//asm {
	//	sti;
	//}//
		
	//for(;;){}
	kprintfln!("In User Mode.")();
// 
// 	auto ptr = cast(long*)0x1000;
// 
// 	if(cast(SyscallError)user.syscall.allocPage(ptr) == SyscallError.OK)
// 	{
// 		kprintfln!("!!Page allocation succeeded!!  Testing..")();
// 
// 		ptr[0] = 5;
// 		kprintfln!("ptr[0] = {}")(ptr[0]);
// 	}
// 	else
// 		kprintfln!("Page allocation failed..")();

	user.syscall.exit(0);

	for(;;) {}

	while(true)
	{
	}
}
