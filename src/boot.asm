global start

section .text

%define VGA_BUFFER 0xB8000

bits 32
start:
    mov dword [VGA_BUFFER], 0x2F4B2F4F
    hlt
