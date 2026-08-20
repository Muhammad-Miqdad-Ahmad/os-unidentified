; ============================================================================
;  boot.asm  --  Stage-1 boot sector
;
;  Purpose: verify the BIOS actually speaks EDD, then LBA-read one sector into
;           memory using INT 13h AH=42h (Extended Read), refusing to run
;           anything if either step fails.
;
;  Assemble:  nasm -f bin boot.asm -o boot.bin
;  Result:    exactly 512 bytes, ending in the 55AA signature.
;
;  Runtime layout: the BIOS loads this sector at physical 0000:7C00, so every
;                  label address below assumes that origin.
; ============================================================================

BITS 16                     ; The CPU is in 16-bit real mode the instant the
                            ; BIOS jumps to us. Everything here is 16-bit.
ORG  0x7C00                 ; Where the BIOS puts us. NASM resolves all label
                            ; offsets relative to this, so [boot_drive] etc.
                            ; point at the right linear addresses.

; ---- Where we're going to drop the sector we read -------------------------
STAGE2_SEG  equ 0x0000      ; Destination segment.
STAGE2_OFF  equ 0x7E00      ; Destination offset. 0x7E00 = the 512 bytes that
                            ; sit *immediately after* this boot sector, so the
                            ; two are contiguous in memory. Nothing to collide.
STAGE2_LBA  equ 1           ; LBA 0 is this boot sector; LBA 1 is the sector
                            ; right after it on the disk. Change to taste.

; ===========================================================================
start:
    ; --- 1. Get to a known machine state ----------------------------------
    ; Don't inherit the BIOS's idea of the segment registers or stack.
    cli                     ; Mask interrupts while the stack/segments are in a
                            ; half-built state. An IRQ firing right now, with SS
                            ; set but SP garbage, corrupts memory silently.
    xor ax, ax              ; AX = 0.
    mov ds, ax              ; DS = 0  -> our ORG-0x7C00 data offsets resolve.
    mov es, ax              ; ES = 0  -> matches the segment we read into.
    mov ss, ax              ; SS = 0.
    mov sp, 0x7C00          ; Stack grows DOWNWARD from just below our code, so
                            ; pushes never touch the 0x7C00..0x8000 region we
                            ; care about.
    cld                     ; Clear direction flag: lodsb/stosb increment SI/DI.
                            ; The BIOS *usually* leaves DF clear, but "usually"
                            ; is not "guaranteed" -- our print routine relies on
                            ; forward string ops, so we make it true ourselves.
    sti                     ; Interrupts back on (BIOS calls want them enabled).

    ; --- 2. SAVE THE BOOT DRIVE NUMBER, deliberately ----------------------
    ; The BIOS handed us the drive we booted from in DL. Right now nothing above
    ; this line has touched DL, so it is still valid -- we could technically get
    ; away with just leaving it in the register. We don't. We stash it on
    ; purpose: this is the "I don't trust future-me not to add a call that
    ; clobbers DL" posture, not the "nothing happens to collide with it yet"
    ; posture. INT 13h itself is free to trash DL, and we're about to call it
    ; twice, so the saved copy is the source of truth from here on.
    mov [boot_drive], dl

    ; --- 3. Does this BIOS actually support EDD? (INT 13h, AH=41h) ---------
    ; "Check Extensions Present." We need THREE things to all be true; any one
    ; failing means we must not attempt the packet read.
    mov ah, 0x41            ; Function 41h.
    mov bx, 0x55AA          ; Magic value IN. A genuine EDD-aware BIOS must hand
                            ; it back byte-swapped -- that handshake is what
                            ; proves a real BIOS answered, not stale garbage.
    mov dl, [boot_drive]    ; Drive to interrogate (from our saved copy).
    int 0x13

    jc  no_edd              ; (a) CF set  -> function unsupported. Bail.
    cmp bx, 0xAA55          ; (b) BX must come back byte-swapped. If it's still
    jne no_edd              ;     0x55AA or garbage, no real EDD BIOS replied.
                            ;     NOTE: CF clear alone is NOT enough -- it only
                            ;     proves the call returned, not that the feature
                            ;     exists. That's why we check BX separately.
    test cx, 1              ; (c) CX bit 0 = "packet-structure access (AH=42h..)
    jz  no_edd              ;     supported". Without this bit the extended read
                            ;     we're about to do is not available.

    ; --- 4. Extended read (INT 13h, AH=42h) -------------------------------
    ; This function takes ALL its parameters from the Disk Address Packet that
    ; DS:SI points at (defined at the bottom). Registers just say "which drive,
    ; where's the packet."
    mov ah, 0x42            ; Function 42h: Extended Read.
    mov dl, [boot_drive]    ; Same drive (reload -- AH=41h may have touched it).
    mov si, dap             ; DS:SI -> our DAP. DS is still 0.
    int 0x13

    jc  disk_error          ; CF set -> read failed, AH holds the error code.
                            ; Critically, we DO NOT fall through into the loaded
                            ; region on failure -- that would execute whatever
                            ; random bytes happen to be sitting at 0x7E00.

    ; --- 5. Success --------------------------------------------------------
    ; If we reach here, the 512 bytes we asked for are now at 0000:7E00.
    mov si, msg_ok
    call print

    ; >>> VERIFICATION POINT <<<
    ; This is where you prove the read worked byte-for-byte, before trusting it.
    ; Break here in GDB (QEMU: -s -S, then `b *0x7c??` at this address) and:
    ;     (gdb) x/512xb 0x7e00
    ; then compare against the on-disk sector, e.g. on the host:
    ;     xxd -s 512 -l 512 disk.img
    ; The two must match exactly. "It printed OK" is not proof; the bytes are.
    ;
    ; Once verified, replace the hang below with the real hand-off:
    ;     jmp STAGE2_SEG:STAGE2_OFF
    jmp hang

; ===========================================================================
; Error paths -- both END in a halt. Nothing undefined ever executes.
; ===========================================================================
no_edd:
    mov si, msg_no_edd
    call print
    jmp  hang

disk_error:
    ; AH still holds the BIOS error code here -- a good register to inspect in
    ; GDB (e.g. 0x01 = bad command, 0x04 = sector not found, 0x80 = timeout).
    mov si, msg_disk_err
    call print
    jmp  hang

hang:
    cli
.halt:
    hlt                     ; Halt until an interrupt. Interrupts are masked, so
    jmp .halt               ; this is a permanent, inspectable stop -- no garbage
                            ; runs, and the machine state is frozen for GDB.

; ---------------------------------------------------------------------------
; print -- write a NUL-terminated string via BIOS teletype (INT 10h, AH=0Eh).
;          Input: DS:SI -> string. Clobbers nothing the caller cares about.
; ---------------------------------------------------------------------------
print:
    push ax
    push bx
.next:
    lodsb                   ; AL = [DS:SI]; SI++ (needs DF=0, which we set).
    test al, al             ; Reached the NUL terminator?
    jz  .done
    mov ah, 0x0E            ; Teletype output.
    mov bh, 0x00            ; Video page 0.
    mov bl, 0x07            ; Attribute (ignored in text mode, set for safety).
    int 0x10
    jmp .next
.done:
    pop bx
    pop ax
    ret

; ===========================================================================
; Data
; ===========================================================================
boot_drive:   db 0x00       ; Runtime copy of the BIOS-supplied DL.

msg_ok:       db "Sector loaded", 13, 10, 0
msg_no_edd:   db "No EDD support", 13, 10, 0
msg_disk_err: db "Disk read error", 13, 10, 0

; ---------------------------------------------------------------------------
; Disk Address Packet (DAP) for INT 13h AH=42h.
; The field layout below is fixed by the BIOS spec -- offsets and widths are
; NOT negotiable. Get one wrong and the BIOS reads into the wrong place (or
; refuses). The db/dw/dq widths encode those exact sizes.
; ---------------------------------------------------------------------------
dap:
    db 0x10                 ; +0  (byte)  Packet size. 0x10 = 16-byte DAP.
    db 0x00                 ; +1  (byte)  Reserved, must be 0.
    dw 1                    ; +2  (word)  Sector count to transfer. Keep <=127;
                            ;             many BIOSes cap a single call there.
    dw STAGE2_OFF           ; +4  (word)  Transfer buffer OFFSET.  \ dest =
    dw STAGE2_SEG           ; +6  (word)  Transfer buffer SEGMENT. / 0000:7E00
    dq STAGE2_LBA           ; +8  (qword) Starting LBA, 64-bit. We want LBA 1.

; ===========================================================================
; Boot signature
; ===========================================================================
times 510-($-$$) db 0       ; Zero-pad from end-of-code up to byte 510. If the
                            ; code ever grows past 510 bytes this line goes
                            ; negative and NASM errors -- a free size check.
dw 0xAA55                   ; Bytes 511-512. On disk: 55 AA (little-endian).
                            ; The BIOS refuses to boot a sector lacking this.
