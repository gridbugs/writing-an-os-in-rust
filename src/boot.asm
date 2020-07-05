global start
extern long_mode_start

%define VGA_BUFFER 0xB8000

section .text
bits 32
start:
    mov esp, stack_top                  ; set up stack

    call check_multiboot
    call check_cpuid
    call check_long_mode

    call set_up_page_tables
    call enable_paging

    lgdt [gdt64.pointer]

    jmp gdt64.code:long_mode_start

    mov dword [VGA_BUFFER], 0x2F4B2F4F  ; print OK

    hlt

enable_paging:
    %define .CR4_FLAG_PAE      (1 << 5)
    %define .MSR_EFER          0xC0000080
    %define .EFER_LONG_MODE    (1 << 8)
    %define .CR0_ENABLE_PAGING (1 << 31)

    ; load top-level page table address into cr3
    mov eax, p4_table
    mov cr3, eax

    ; enable PAE flag in cr4
    mov eax, cr4
    or eax, .CR4_FLAG_PAE
    mov cr4, eax

    ; set long mode bit in EFER MSR
    mov ecx, .MSR_EFER
    rdmsr
    or eax, .EFER_LONG_MODE
    wrmsr

    ; enable paging in cr0
    mov eax, cr0
    or eax, .CR0_ENABLE_PAGING
    mov cr0, eax

    ret

set_up_page_tables:
    %define .PRESENT                 (1 << 0)
    %define .WRITABLE                (1 << 1)
    %define .HUGE                    (1 << 7)
    %define .N_PAGE_SIZE             4096
    %define .N_PAGE_TABLE_ENTRY_SIZE 8
    %define .N_PAGE_TABLE_ENTRIES    (.N_PAGE_SIZE / .N_PAGE_TABLE_ENTRY_SIZE)  ; 512
    %define .P2_HUGE_PAGE_SIZE       (.N_PAGE_TABLE_ENTRIES * .N_PAGE_SIZE)     ; 2M

    mov eax, p3_table
    or eax, (.PRESENT | .WRITABLE)
    mov [p4_table], eax
    mov eax, p2_table
    or eax, (.PRESENT | .WRITABLE)
    mov [p3_table], eax

    mov ecx, 0
.map_p2_table_loop:
    mov eax, .P2_HUGE_PAGE_SIZE
    mul ecx
    or eax, (.PRESENT | .WRITABLE | .HUGE)
    mov [p2_table + ecx * 8], eax
    inc ecx
    cmp ecx, .N_PAGE_TABLE_ENTRIES
    jne .map_p2_table_loop

    ret

check_multiboot:
    %define .MAGIC 0x36D76289
    cmp eax, .MAGIC
    jne .no_multiboot
    ret
.no_multiboot:
    mov al, "0"
    jmp error

check_cpuid:
    ; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
    ; in the FLAGS register. If we can flip it, CPUID is available.

    ; Copy FLAGS in to EAX via stack
    pushfd
    pop eax

    ; Copy to ECX as well for comparing later on
    mov ecx, eax

    ; Flip the ID bit
    xor eax, 1 << 21

    ; Copy EAX to FLAGS via the stack
    push eax
    popfd

    ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfd
    pop eax

    ; Restore FLAGS from the old version stored in ECX (i.e. flipping the
    ; ID bit back if it was ever flipped).
    push ecx
    popfd

    ; Compare EAX and ECX. If they are equal then that means the bit
    ; wasn't flipped, and CPUID isn't supported.
    cmp eax, ecx
    je .no_cpuid
    ret
.no_cpuid:
    mov al, "1"
    jmp error

check_long_mode:
    ; test if extended processor info in available
    mov eax, 0x80000000    ; implicit argument for cpuid
    cpuid                  ; get highest supported argument
    cmp eax, 0x80000001    ; it needs to be at least 0x80000001
    jb .no_long_mode       ; if it's less, the CPU is too old for long mode

    ; use extended info to test if long mode is available
    mov eax, 0x80000001    ; argument for extended processor info
    cpuid                  ; returns various feature bits in ecx and edx
    test edx, 1 << 29      ; test if the LM-bit is set in the D-register
    jz .no_long_mode       ; If it's not set, there is no long mode
    ret
.no_long_mode:
    mov al, "2"
    jmp error

; Prints "ERR: x" where x is the ascii char passed in al
error:
    mov dword [VGA_BUFFER + 0x0], 0x4F524F45
    mov dword [VGA_BUFFER + 0x4], 0x4F3A4F52
    mov dword [VGA_BUFFER + 0x8], 0x4F204F20
    mov byte [VGA_BUFFER + 0xA], al
    hlt

section .rodata
gdt64:
    %define .EXECUTABLE      (1 << 43)
    %define .DESCRIPTOR_TYPE (1 << 44)
    %define .PRESENT         (1 << 47)
    %define .ENABLE_64BIT    (1 << 53)

    dq 0     ; gdt must start with 0 entry
.code equ $ - gdt64    ; offset into gdt for code segment
    dq (.EXECUTABLE | .DESCRIPTOR_TYPE | .PRESENT | .ENABLE_64BIT) ; code segment
.pointer:
    dw $ - gdt64 - 1   ; gdt length minus 1
    dq gdt64           ; gdt start pointer

section .bss
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 64
stack_top:
