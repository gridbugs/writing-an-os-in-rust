global long_mode_start


%define VGA_BUFFER 0xB8000

section .text
bits 64
long_mode_start:

    ; load 0 into all data segment registers
    mov ax, 0
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; print 'OKAY'
    mov rax, 0x2F592F412F4B2F4F
    mov qword [VGA_BUFFER], rax
    hlt
