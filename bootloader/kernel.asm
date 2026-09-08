; db → 1 byte
; dw → 2 bytes
; dd → 4 bytes
; dq → 8 bytes

	[org    0x8000]

	push    si
	mov     si, hello
	call    printf

	mov     si, newline
	call    printf
	mov     si, newline
	call    printf
	pop     si
	
	lgdt [gdt_discriptor]

hang:
	hlt
	jmp     hang

gdt_discriptor:
	dw      gdt_end - gdt_start - 1
	dd      gdt_start

gdt_start:
	dq      0									; NULL descriptor ;dq writes an entire 8 byte to memory. 64 bit
	dq      0x00CF9A000000FFFF					; CODE descriptor
	dq      0x00CF92000000FFFF					; DATA descriptor
gdt_end:

hello           db      "Hello from The OS Unidentified.", 0
newline         db      0x0D, 0x0A, 0

printf:         								; sub routiene aka function in assembly
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

	times   512-($-$$) db 0
