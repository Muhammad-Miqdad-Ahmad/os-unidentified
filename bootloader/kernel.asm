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
	mov     esp, 0x90000	; initializing the stack at the memory 0x90000

	; Now Writing the VGA memory
	; Hello from OS unidentified

	mov     esi, hello
	call    printf

	mov     esi, hello2
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
	push    esi
	push    edi
	mov     edi, [cursor]
.loop:
	mov     al, [esi]

	cmp     al, 0
	je      .done

	cmp     al, 10
	je      .newline

	mov     [edi], al
	mov     byte [edi + 1], 0x0F

	inc     esi
	add     edi, 2

	jmp     .loop

.newline:
	mov     [cursor], edi
	call    newline
	mov     edi, [cursor]

	inc     esi
	jmp     .loop

.done:
	mov     [cursor], edi
	pop     edi
	pop     esi
	ret

newline:
    ; Get current cursor offset
	mov     eax, [cursor]
	sub     eax, 0xB8000

    ; Divide by row size (160 bytes)
	mov     ebx, 160
	xor     edx, edx
	div     ebx

    ; Calculate beginning of next row
	inc     eax
	imul    eax, 160

    ; Convert back to VGA address
	add     eax, 0xB8000

    ; Save new cursor position
	mov     [cursor], eax

	ret

hello           db      "Hello from The OS Unidentified.", 0
hello2          db      10, "Checking if the newline characters work or not.", 0
cursor:         dd      0xB8000					;Stores the VGA address, change it to keep track of the cursor