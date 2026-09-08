# ── config ──
SRCDIR     := bootloader
BUILDDIR   := bootloader/build
BOOT_SRC   := $(SRCDIR)/main.asm
KERNEL_SRC := $(SRCDIR)/kernel.asm
BOOT_BIN   := $(BUILDDIR)/boot.img
KERNEL_BIN := $(BUILDDIR)/kernel.img
DISK       := $(BUILDDIR)/disk.img
SECTORS    := 2880

ASM := nasm

all: $(DISK)

# create build dir if missing
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(BOOT_BIN): $(BOOT_SRC) | $(BUILDDIR)
	$(ASM) $< -f bin -o $@

$(KERNEL_BIN): $(KERNEL_SRC) | $(BUILDDIR)
	$(ASM) $< -f bin -o $@

$(DISK): $(BOOT_BIN) $(KERNEL_BIN)
	dd if=/dev/zero of=$@ bs=512 count=$(SECTORS) status=none
	dd if=$(BOOT_BIN)   of=$@ bs=512 count=1        conv=notrunc status=none
	dd if=$(KERNEL_BIN) of=$@ bs=512 seek=1 count=1 conv=notrunc status=none
	@echo "built $@ ($(SECTORS) sectors)"

run: $(DISK)
	qemu-system-x86_64 -hda $(DISK) -s -S

run-pro: $(DISK)
	qemu-system-i386 -hda $(DISK) -s -S

lst: $(BOOT_SRC) $(KERNEL_SRC) | $(BUILDDIR)
	$(ASM) $(BOOT_SRC)   -f bin -o $(BOOT_BIN)   -l $(BUILDDIR)/boot.lst
	$(ASM) $(KERNEL_SRC) -f bin -o $(KERNEL_BIN) -l $(BUILDDIR)/kernel.lst

clean:
	rm -rf $(BUILDDIR)

.PHONY: all run lst clean