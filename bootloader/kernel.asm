	[org    0x8000]

	push    si
	mov     si, hello
	call    printf
	pop     si

hang:
	hlt
	jmp     hang

hello           db      "Hello from The OS Unidentified.", 0

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
