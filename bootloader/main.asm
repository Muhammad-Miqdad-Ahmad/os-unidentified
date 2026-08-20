; nasm  main.asm -f bin -o boot.img
; nasm -f bin -l boot.lst main.asm -o boot.img

	[org    0x7c00]								; will start the code at this memory location.
; This is the location where the BIOS expects to find a bootloader.
; The first thing I will do is to save the value in the dl register. it is actually the
; boot drive number.



	xor     ax, ax								; Making the ax register 0
	mov     ds, ax								; set data segment to 0 usi,ng zeroed ax
	mov     es, ax								; set extra segment to 0 usi,ng zeroed ax
	mov     ss, ax								; set stack segment to 0 usi,ng zeroed ax
	mov     sp, 0x7C00							; set stack pointer to 0x7C00 (grows downward from here)

	mov     [boot_drive], dl					; store BIOS-provided drive number into boot_drive variable

	; mov     ah, 0Eh								; sooooooooooooo 0x0E is 14 I can load 14 instead of 0x0E
	mov     bh, 0								; set page number to 0 for the teletype output function

	mov     ah, 0x41							; 41h is the function to check the EDD
	mov     bx, 0x55aa							; Checking if the bios supports the AH = 42h. EDD installation check
	mov     dl, [boot_drive]
	int     13h									; calling the 13h function
	mov     [saved_bx], bx
	mov     [saved_cx], cx
	; Theoritaclly speaking it should set CF = 1
	; I cant check cf like normal register. it is a flag and not a register.
	jc      edd_not_supported					; cf is not zero so it jumps

; cf is 0:

;checking the bx register
	cmp     word [saved_bx], 0xaa55
	jne     edd_not_supported

; bx worked the strings were equal
	test    word [saved_cx], 1					; the zeroeth bit or the rightmost bit should be 1
	; TEST performs a bitwise AND without changing CX.
	; It only updates the FLAGS register.
	jnz     cx_worked							; jump if not zero
	jmp     edd_not_supported

cx_worked:

	push    si
	mov     si, cfIs0
	call    print_string
	mov     si, newline
	call    print_string
	pop     si

	push    si
	mov     si, bxdidswap
	call    print_string
	mov     si, newline
	call    print_string
	pop     si

	push    si
	mov     si, cxsetbit
	call    print_string
	mov     si, newline
	call    print_string
	pop     si

	; Now lets load the second sector into the memory by using the 42h
	mov     ah, 42h
	mov     dl, [boot_drive]

	mov     si, dap								; SI = offset of DAP
; DS is already 0


	int     13h
	jc      read_failed

	jmp     0x0000:0x8000


edd_not_supported:
	push    si
	mov     si, edd_unsupported
	call    print_string
	mov     si, newline
	call    print_string
	pop     si

read_failed:
	mov     si, failure_reading
	call    print_string

hang:
	hlt     									; halt the CPU until the next interrupt
	jmp     hang								; jump back to hang, creating an infinite loop

newline         db      0x0D, 0x0A, 0
boot_drive      db      0						; storage for boot drive number (also doubles as string bytes here)
cfIs0           db      "CF = 0. The AH=41h check succeeded. Continue checking BX and CX.", 0
bxdidswap       db      "Bx value is aa55, 42h is supported", 0
cxsetbit        db      "CX 0th bit is 1, 42h is supported", 0
edd_unsupported db      "Edd is not supported. Exiting the Bootloader", 0
saved_bx        dw      0
saved_cx        dw      0
failure_reading db      "Could not read the next sector", 0

dap:
	db      16									; size
	db      0
	dw      1									; read 1 sector

	dw      0x8000								; offset
	dw      0x0000								; segment

	dq      1									; LBA = 1


print_string:   								; sub routiene aka function in assembly
	push    ax									; Save AX OH I LOVE THE STACK
	mov     ah, 0Eh
.loop_start:
	mov     al, [si]							; load the data at the memory address stored in DS+SI,
	cmp     al, 0x00							; compare if al is 0 (string terminator)
	je      .loop_end							; if yes then go to loop end if not then continue

	int     10h									; execute the interrupt
	inc     si									; increment thevalue of si,
	jmp     .loop_start							; Jump back to '.loop_start' regardless
.loop_end:
	pop     ax
	ret     									; return to the caller

	times   510-($-$$) db 0						; pad with zeros
	dw      0xAA55								; boot signature
