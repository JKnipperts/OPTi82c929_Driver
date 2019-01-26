; TSR to force SB Pro compatible mixerchip into stereo mode
; (Some SB Pro clone cards tend to switch mode irrequlary)
; (c) 2018 by Jan Knipperts
; v0.2 - 12/23/2018
;
; Known issues: Installation check does not work when loaded to high memory

[BITS 16]
[ORG 0x0100]
[SECTION .code]


Start:                                 ; Start of Program
jmp Main                               ; Skip data and inteerupt routine

i1cHandlerSegment dw 0000h
i1cHandlerOffset  dw 0000h
sbmixerport       dw 0000h
ticks             db 00h

TSR:                                    ;Our own interrupt code
cmp byte [cs:ticks],1
je  step1                               ;SB mixerchip needs a little delay therefore
cmp byte [cs:ticks],3                   ;the stereo bit is checked everey 3 tick
je  step2
add byte [cs:ticks],1
jmp return

step1:
 mov dx,[cs:sbmixerport]
 mov al,0Eh                            ;Write Mixer command
 out dx,al
 add byte [cs:ticks],1
 jmp return

step2:
 mov dx,[cs:sbmixerport]
 add dx,1
 mov al,51                             ;Write 51 to set proper stereo
 out dx,al                             ;This is also our ID to detect if handler is already installed
 mov byte [cs:ticks],0

return:
 push WORD [CS:i1cHandlerSegment]
 push WORD [CS:i1cHandlerOffset]
 retf


Main:
                mov dx,Title            ;Write title message
		mov ah,9
                int 21h

                jmp DetectSB            ;Go on with sound blaster detection and skip data

Title		db 'Stereo fix for SB Pro clones v.0.2á - (c) 2018 by Jan Knipperts',10,13,'$'
noSB		db 'ERROR: Sound Blaster Pro not found!',10,13,'$'
aloaded		db 'Fix is already installed!',10,13,'$'
success		db 'Fix installed!',10,13,'$'

;Detect Sound Blaster card and the acutal base address

DetectSB:
 	        mov dx,220h
SearchNext:	add dl,6		;Reset port 2x6h
		mov al,1
		out dx,al               ;Write 1

		sub al,al		;just a little delay
Delay:
                dec al
                jnz Delay

		out dx,al               ; Write 0 to Reset Port

         	sub al,al		;just another little delay
Delay1:
                dec al
                jnz Delay1


                sub dl,6
		add dl,0Eh              ; Buffer status port, 2xEh
		sub cx,cx		;Max of 65536 tries

WaitCMD:
		in al,dx                 ;Read status port
		shl al,1
		jc CMDReady
loop WaitCMD				;Bit 7 clear, try again


DoNext:
		sub dl,0Eh
		add dl,10h
		cmp dl,60h	        ;All valid ports (210h-260h) tried?
		jbe SearchNext		;No? Than test the next one
		jmp SBNotFound		;If yes, no SB was found

CMDReady:	sub dl,0Eh
		add dl,0Ah		;2xAh =Read Data port
                in al,dx
		cmp al,0AAh            ;Do we receive the success code, 0AAh?
		je  SBResetOK
		add dl,4
		jne DoNext

SBResetOK:
		sub dl,0Ah
		add dl,0Ch             ;2xCh write command port
                mov al,0E1h          ;command E1h - Get DSP version
                out dx,al

                sub dl,0Ch
                add dl,0Eh	     ;2xEh Read Buffer status

                sub cx,cx

WaitCMD1:       in al,dx	    ;Check for data to read
                shl al,1
                jc CheckVer
loop WaitCMD1

		jmp SBNotFound

CheckVer:
		sub dl,0Eh
		add dl,0Ah
		in al,dx
	        cmp al,3	    ;DSP 3.x?
		je  Install

SBNotFound:
                mov dx,noSB         ;Write no SB found message
                mov ah,9
                int 21h
                mov ah,4Ch
                mov al,1            ;Quit with exit code 1
                int 21h

Install:
                sub dl,0Ah
                add dl,4             ;Mixerport is 2x4h
                mov WORD [sbmixerport],dx  ;Save value for interrupt routine

		cli
                mov ax,351Ch  ;Get old 1c vector
                int 21h

                mov WORD  [i1cHandlerSegment],es
                mov WORD  [i1cHandlerOffset],bx

                mov di,bx            ;Test if byte at offset 44 is 51
                add di,44
                mov al,[es:di]
                cmp al,51
                je already_installed  ;Yes, then it is already our vector

                mov ax,251Ch       ;Set our own vector
                mov dx,TSR
                int 21h
		sti

		mov dx,success     ;Write success message
		mov ah,9
		int 21h

                mov dx,(Main+1) ;Offset of last byte to remain resident +1
                int 27h ;TSR it

already_installed:
                mov dx,aloaded      ;Write already loaded message
                mov ah,9
                int 21h
                mov ah,4Ch          ;Quit with exit code 1
                mov al,1
                int 21h

