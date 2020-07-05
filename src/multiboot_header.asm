section .multiboot_header

%define MULTIBOOT_2_MAGIC_NUMBER 0xE85250D6
%define ARCHITECTURE 0 ; protected mode i386
%define HEADER_LENGTH (header_end - header_start)
%define CHECKSUM (0x100000000 - (MULTIBOOT_2_MAGIC_NUMBER + ARCHITECTURE + HEADER_LENGTH))

header_start:
    dd MULTIBOOT_2_MAGIC_NUMBER
    dd ARCHITECTURE
    dd HEADER_LENGTH
    dd CHECKSUM

    ; end tag
    dw 0 ; type
    dw 0 ; flags
    dd 8 ; size
header_end:
