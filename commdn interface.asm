section .command
be desktop
be internet like-google (MM for timing,  and TT for full always)
be a video game with thsoe caractersitics :
be a etc.. . 


section .bss
    command resb 1024    
section .text
    global _start

_start:
    ; Read input from stdin
    mov rdi, 0         ; File descriptor 0 (stdin)
    mov rsi, command   ; Buffer to store the command
    mov rdx, 1024       ; Number of bytes to read
    mov rax, 0         ; syscall number for sys_read
    syscall

    ; Process command (e.g., just print it out)
    mov rdi, 1         ; File descriptor 1 (stdout)
    mov rax, 1         ; syscall number for sys_write
    mov rdx, 1024       ; Number of bytes to write (not really correct here)
    syscall

    ; Exit the program
    mov rax, 60        ; syscall number for sys_exit
    xor rdi, rdi       ; Exit code 0
    syscall
