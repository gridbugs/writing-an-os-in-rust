build := build
src := src

kernel := $(build)/kernel.bin
iso := $(build)/os.iso

linker_script := $(src)/linker.ld
grub_cfg := $(src)/grub.cfg
asm_src := $(wildcard $(src)/*.asm)

asm_obj := $(patsubst $(src)/%.asm, $(build)/%.o, $(asm_src))

.PHONY: all clean run iso

all: $(kernel)

clean:
	rm -r $(build)

run: $(iso)
	qemu-system-x86_64 -cdrom $(iso)

iso: $(iso)

$(iso): $(kernel) $(grub_cfg)
	mkdir -p $(build)/isofiles/boot/grub
	cp $(kernel) $(build)/isofiles/boot
	cp $(grub_cfg) $(build)/isofiles/boot/grub
	grub-mkrescue --output=$(iso) $(build)/isofiles
	rm -r $(build)/isofiles

$(kernel): $(asm_obj) $(linker_script)
	ld --nmagic --output=$(kernel) --script=$(linker_script) $(asm_obj)

$(build)/%.o: $(src)/%.asm
	mkdir -p $(build)
	nasm -f elf64 $< -o $@
