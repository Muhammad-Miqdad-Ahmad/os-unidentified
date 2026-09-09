; db → 1 byte
; dw → 2 bytes
; dd → 4 bytes
; dq → 8 bytes

	[org    0x8000]
	[bits   16]
	mov     ax, 0x0003
	int     0x10

	lgdt    [gdt_discriptor]

	mov     eax, cr0
	or      eax, 1
	mov     cr0, eax

	jmp     dword 0x08:protected_mode

protected_mode:
	[bits   32]
	mov     ax, 0x10
	mov     ds, ax
	mov     es, ax
	mov     ss, ax

	; Now Writing the VGA memory
	; Hello from OS unidentified

	mov     esi, hello
	mov     edi, 0xB8000
	call    printf


hang:
	cli
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

printf:
.loop:
	mov     al, [esi]
	cmp     al, 0
	je      .done

	mov     [edi], al
	mov     byte [edi + 1], 0x0F

	inc     esi
	add     edi, 2

	jmp     .loop

.done:
	ret

hello           db      "Hello from The OS Unidentified.", 0
