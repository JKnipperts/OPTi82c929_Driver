{Yamaha OPL-2/3 FM-Chip Low Level Sounddriver}
{Version 1.5a vom 05.06.2002
Copyright (c) 2001/2002 by Jan Knipperts}

{23.03.2002 - Waveselect und variable FNummern hinzugefgt
 27.03      - SetKeyState und SetKey eingefgt
 14.04.     - Proceduren fr Rythm-Modus berarbeitet
 20.04.     - Proceduren fr das setzen der einzelenen Operatoren-Werte
              eingefgt
 04.06.     - Diversere kleinere Bugfixes
 05.06.     - FM-Port w„hlbar}

Unit OPLFM;

interface

const
 regs  : array[0..8] of array[1..11] of byte =    {OPL-3 Register}
  {Carrier, Modulator}
 (($23,$20,$43,$40,$63,$60,$83,$80,$C0,$E3,$E0),     {Channel 0}
  ($24,$21,$44,$41,$64,$61,$84,$81,$C1,$E4,$E1),     {Channel 1}
  ($25,$22,$45,$42,$65,$62,$85,$82,$C2,$E5,$E2),     {Channel 2}
  ($2B,$28,$4B,$48,$6B,$68,$8B,$88,$C3,$EB,$E8),     {Channel 3}
  ($2C,$29,$4C,$49,$6C,$69,$8C,$89,$C4,$EC,$E9),     {Channel 4}
  ($2D,$2A,$4D,$4A,$6D,$6A,$8D,$8A,$C5,$ED,$EA),     {Channel 5}
  ($33,$30,$53,$50,$73,$70,$93,$90,$C6,$F3,$F0),     {Channel 6}
  ($34,$31,$54,$51,$74,$71,$94,$91,$C7,$F4,$F1),     {Channel 7}
  ($35,$32,$55,$52,$75,$72,$95,$92,$C8,$F5,$F2));    {Channel 8}

   {  Offsets[operator, channel] gibt Offset  fr die richtigen Chip-Register
      in den untenstehenden Proceduren}
   Offsets : array[0..1, 0..8] of word =
      (($00, $01, $02, $08, $09, $0A, $10, $11, $12),
       ($03, $04, $05, $0B, $0C, $0D, $13, $14, $15));

 FnumNotes : array[1..25] of array[1..12] of word = (
    (343, 364, 385, 408, 433, 459, 486, 515, 546, 579, 614, 650),
    (344, 365, 387, 410, 434, 460, 488, 517, 548, 581, 615, 652),
    (345, 365, 387, 410, 435, 461, 489, 518, 549, 582, 617, 653),
    (346, 366, 388, 411, 436, 462, 490, 519, 550, 583, 618, 655),
    (346, 367, 389, 412, 437, 463, 491, 520, 551, 584, 619, 657),
    (347, 368, 390, 413, 438, 464, 492, 522, 553, 586, 621, 658),
    (348, 369, 391, 415, 439, 466, 493, 523, 554, 587, 622, 660),
    (349, 370, 392, 415, 440, 467, 495, 524, 556, 589, 624, 661),
    (350, 371, 393, 416, 441, 468, 496, 525, 557, 590, 625, 663),
    (351, 372, 394, 417, 442, 469, 497, 527, 558, 592, 627, 665),
    (351, 372, 395, 418, 443, 470, 498, 528, 559, 593, 628, 666),
    (352, 373, 396, 419, 444, 471, 499, 529, 561, 594, 630, 668),

    (353, 374, 397, 420, 445, 472, 500, 530, 562, 596, 631, 669),

    (354, 375, 398, 421, 447, 473, 502, 532, 564, 597, 633, 671),
    (355, 376, 398, 422, 448, 474, 503, 533, 565, 599, 634, 672),
    (356, 377, 399, 423, 449, 475, 504, 534, 566, 600, 636, 674),
    (356, 378, 400, 424, 450, 477, 505, 535, 567, 601, 637, 675),
    (357, 379, 401, 425, 451, 478, 506, 537, 569, 603, 639, 677),
    (358, 379, 402, 426, 452, 479, 507, 538, 570, 604, 640, 679),
    (359, 380, 403, 427, 453, 480, 509, 539, 571, 606, 642, 680),
    (360, 381, 404, 428, 454, 481, 510, 540, 572, 607, 643, 682),
    (360, 382, 405, 429, 455, 482, 511, 541, 574, 608, 645, 683),
    (361, 383, 406, 430, 456, 483, 512, 543, 575, 610, 646, 685),
    (362, 384, 407, 431, 457, 484, 513, 544, 577, 611, 648, 687),
    (363, 385, 408, 432, 458, 485, 514, 545, 578, 612, 649, 688));

 StandartFnum : array[0..11] of word = ($16b,$181,$198,$1b0,$1ca,$1e5,
                                        $202,$220,$241,$263,$287,$2ae);

   adlibport = $388; {standard I/O Port fr FM-Chip}
   freqend = $2AE;
 freqstart = $156;
 freqrange = freqend-freqstart;

type
  bit = 0..1;
  bitnum = 0..7;


var
 OPLReg                         : array[1..244] of byte;
 volumeC,
 volumeM                        : array[0..8] of byte;
 Fnum                           : array[0..11] of word;
 oplport                        : word;




procedure set_bit(var b:byte; bit:integer; value:boolean);


Function DetectOPL2 : boolean;
{Ist ein OPL-2 Chip vorhanden?}
Function DetectOPL3 : boolean;
{Ist ein OPL-3 Chip vorhanden ?}


Procedure InitOPL;
{Initalisiert den Soundchip und setzt alle Register auf 0}
Procedure ClearOPL;
{Setzt alle Channel auf Mute und die Chip-Register auf 0}

Procedure SetFnumTable(fn : array of word);
{Setzt andere Fnummern fr Noten}


Procedure Setreg(address,data : word);
{Setzt ein bestimmtes Register des OPL-Chips}
Procedure KeyOff(chan : byte);
{Per Keyoff-Bit aktuellen Ton im Channel ausschalten}
Procedure SetkeyState(chan : byte; onoff : boolean);
{Setzt oder l”scht das Keyon-Bit im angegebenen Channel}
Procedure switchOFF(ch : byte);
{Note 0 + Keyoff}


Function nFreq(note : Byte) : Word;
{Gibt die Frequenz in Hz fr eine Note zurck}
Function toHz(note,octave : byte) : word;
{Wandelt Note+Oktave in Hz-Frequenz um}


Procedure SetMvolume(chan,value : byte);
{Setzt Lautst„rke des Modulators
(0 = Laut, 63 = Leise. )}
Procedure SetCVolume(chan,value : byte);
{Setzt Lautst„rke des Carrier
(0 = Laut, 63 = Leise. )}
Function GetMvolume(chan : byte) : byte;
Function GetCvolume(chan : byte) : byte;

Procedure Waveselect(on : boolean);

Procedure KeyOn(chan,octave : byte;pitch : word);
{Spielt eine Note im angegebenen Channel}

Procedure Setkey(chan,octave : byte;pitch : word);
{Setzt eine Note im angegebenen Channel,ohne sie zu spielen}


Procedure Setfreq(chan : byte; freq : integer);
{Spielt eine bestimmte Frequenz im angegebenen Channel}
Function GetFreq(chan : byte) : word;
{Liefert die aktuelle Frequenz im angegebenen Channel in Hz}

{Fr Schlagzeug-Modus (Percussionmode)}
Procedure rhythm(value:boolean);
Procedure bass_drum(value:boolean);
Procedure snare_drum(value:boolean);
Procedure Tom_tom(value:boolean);
Procedure cymbal(value:boolean);
Procedure Hi_hat(value:boolean);

{Setzt die Parameter eines Operators}
procedure SetAM(chan, op : byte; bit, amd:boolean);
procedure SetVib(chan, op : byte; bit, amd:boolean);
procedure SetEG(chan, op : byte; bit:boolean);
procedure SetKSR(chan, op : byte; bit:boolean);
procedure SetHarmonic(chan, op : byte; value:byte);

procedure SetAttack(chan, op : byte; value:byte);
procedure SetDecay(chan, op : byte; value:byte);

procedure SetSustain(chan, op : byte; value:byte);
procedure SetRelease(chan, op : byte; value:byte);

procedure SetWaveform(chan, op : byte; value:byte);

procedure SetOutput(chan, op : byte; value:byte);
procedure SetKSL(chan, op : byte; value:byte);

procedure SetFeedback(channel:word; value:byte);
procedure SetFM(channel:word; value:boolean);


implementation


{============ Interne Hilfsgunktionen =================}

procedure set_bit(var b:byte; bit:integer; value:boolean);
{Schnelle Funktion zum setzen eines einzelnen Bit}
var
   c:byte;
begin
   c:= 1;
   if value then
      b:= b or (c shl bit)
   else
      b:= b and not(c shl bit);
end;

Function setBit( b : Byte; n : bitNum) : Byte;
{setzt ein Bit}
begin
  setBit := b or (1 shl n);
end;


Function getBit(b : Byte; n : bitNum) : bit;
{liefert den Zustand eines Bit}
begin
  getBit := bit(odd(b shr n));
end;

Function clrBit(b : Byte; n : bitNum) : Byte;
{l”scht ein Bit}
begin
  clrBit := b and hi($FEFF shl n);
end;


Procedure Addrdelay;
assembler;
asm
   mov     cx, 6           {6 Wiederhohlungen = 3.3 microsekunden}
   mov     dx, oplport        {Adlib Port (388h)}

@delayloop1:
   in      al, dx
   loop    @delayloop1
   ret
end;


Procedure Datadelay;
assembler;
asm
   mov     cx, 35          {35 Wiederhohlungen = 23 microsekunden}
   mov     dx, oplport     {Adlib Port (388h)}

@delayloop2:
   in      al, dx
   loop    @delayloop2
   ret
end;

procedure oplout(data: Word);
assembler;
asm
        mov     ax,data
        mov     dx,word ptr [oplport]
        out     dx,al
        mov     cx,6
@@1:    in      al,dx
        loop    @@1
        inc     dl
        mov     al,ah
        out     dx,al
        dec     dl
        mov     cx,24
@@2:    in      al,dx
        loop    @@2
end;





function _word(Lo,Hi: Byte): Word;
{Konvertiert zwei Byte (jeweils 8-Bit) in ein Word (16-Bit)}
assembler;
asm
        mov     al,Lo
        mov     ah,Hi
end;


{======================= OPL- Funktionen ===============}


Procedure Setreg(address,data : word);
{Setzt ein bestimmtes Port-register}
begin
 oplout(_word(address,data));
 OPLReg[address] := data;
end;

Procedure Setkey(chan,octave : byte;pitch : word);
{Setzt eine Note im angegebenen Channel,ohne sie zu spielen}
var
   highpitch,
   lowpitch,a,b :byte;
begin
   lowpitch:= pitch and $00FF;
   highpitch:= (pitch and $FF00) shr 8;
   b := (octave shl 2) + highpitch;
   set_bit(b, 5, false); {Keyon aus}
   a := lowpitch;
   setreg($B0+chan,b);
   setreg($A0+chan,a);
end;


Procedure Setkeystate(chan : byte; onoff : boolean);
begin
 set_bit(OPLReg[$B0+chan],5,onoff);
 setreg($B0+chan,OPLReg[$B0+chan]);
end;



Procedure  KeyOff(chan : byte); {Channel aus}
begin
 set_bit(OPLReg[$B0+chan],5,false);
 setreg($B0+chan,OPLReg[$B0+chan]);
end;



{Instrument - funktionen :}

Procedure Waveselect(on : boolean);
var b,c : byte;
begin
 for c :=  0 to 8 do
 begin
  setreg(regs[c][10],0);
  setreg(regs[c][11],0);
 end;

 if on then
 begin
  setreg($01,$20);          {Waveforms an}
 end
 else
 begin
  setreg($01,00);          {Waveforms aus}
 end;
end;

procedure rhythm(value:boolean);
begin
   set_bit(OPLReg[$BD], 5, value);
   setreg($BD,OPLReg[$BD]);
end;

procedure bass_drum(value:boolean);
begin
   set_bit(OPLReg[$BD], 4, value);
   setreg($BD,OPLReg[$BD]);
end;

procedure snare_drum(value:boolean);
begin
   set_bit(OPLReg[$BD], 3, value);
   setreg($BD,OPLReg[$BD]);
end;

procedure Tom_tom(value:boolean);
begin
   set_bit(OPLReg[$BD], 2, value);
   setreg($BD,OPLReg[$BD]);
end;

procedure cymbal(value:boolean);
begin
   set_bit(OPLReg[$BD], 1, value);
   setreg($BD,OPLReg[$BD]);
end;

procedure Hi_hat(value:boolean);
begin
   set_bit(OPLReg[$BD], 0, value);
   setreg($BD,OPLReg[$BD]);
end;




Procedure InitOPL;
{Initalisiert Soundkarte und setzt alle Register auf 0}
var bd    : byte;
    dport : word;

begin
dport := oplport+1;
asm
        mov     al, 1
@zeroing_loop:
        push    ax
        mov     dx, oplport
        out     dx, al          {schreibe in Adress-Port}
        call addrdelay
        mov     al, 0           {l”sche Daten-Register}
        mov     dx, dport
        out     dx, al
        call datadelay
        pop     ax
        inc     al
                               {L”sche alle 254-Register (01h-F5h)}
        cmp     al, 0F5h
        jbe     @zeroing_loop      {01-F5h, wiederhohle  }
end;
setreg($08,$00);          {FM-Musikmodus an}
{Waveselect(true);}

end;


Procedure SetFnumTable(fn : array of word);
begin
 move(fn,Fnum,sizeof(Fnum));
end;



function nFreq(note : Byte) : Word;
  {Gibt richtige Frequenz fr Note}
assembler;
asm
        mov     al,note
        xor     ah,ah
        cmp     ax,12*8
        jae     @@1
        push    ax
        mov     bl,12
        div     bl
        mov     bl,ah
        xor     bh,bh
        shl     bx,1
        pop     ax
        mov     cl,12
        div     cl
        xor     ah,ah
        shl     ax,10
        add     ax,word ptr [Fnum+bx]
        jmp     @@2
@@1:    mov     ax,$1ed9
        jmp     @@2

@@2:
end;


Function GetFreq(chan : byte) : word;
var pitch : word;
    b1,b2    : byte;

begin
{liefert die aktueller Frequenz eines Channels in Hz}
  b1 := OPLReg[$B0+chan];
  set_bit(b1, 5, false);    {Keyon Bit}
  b2 := OPLReg[$A0+chan];

   asm
    mov cl,b2
    mov ch,b1
    and ch,3                        { h”here Frequenz bits }
    sub cx,FreqStart
    mov al,b1
    shr al,2
    and ax,7                        { oktave   }
    mov dx,FreqRange
    mul dx
    add ax,cx
    mov pitch,ax
  end;


  if pitch > 2751 then pitch := 0;

  getfreq := pitch;
end;




Function toHz(note,octave : byte) : word;
{Wandelt Note+Oktave in Hz-Frequenz um}
var
   highpitch,
   lowpitch,boo,bot :byte;
   pitch            :word;
begin
   pitch        := nfreq(note);
   lowpitch     := pitch and $00FF;
   highpitch    := (pitch and $FF00) shr 8;
   boo          := (octave shl 2) + highpitch;
   bot          := lowpitch;
   set_bit(boo, 5, true);    {Keyon Bit}

   {boo = B0}
   {bot = a0}

  asm
    mov cl,bot
    mov ch,boo
    and ch,3                        { Frequenz }
    sub cx,FreqStart
    mov al,boo
    shr al,2
    and ax,7                        { Oktave   }
    mov dx,FreqRange
    mul dx
    add ax,cx

    mov pitch,ax
  end;



  toHZ := pitch;

end;





Function DetectOPL2 : boolean;
var test1,test2,cnt : byte;
begin
 setreg(4,$60);       {Ist eine OPL-2 kompatible Soundkarte vorhanden ?}
 setreg(4,$80);
 test1 := port[oplport];
 setreg(2,$FF);
 setreg(4,$21);
 for cnt := 1 to 4 do
 begin
  datadelay;   {80 msec}
 end;
 test2 := port[oplport];
 setreg(4,$60);
 setreg(4,$80);
 test1 := test1 and $E0;
 test2 := test2 and $E0;

 if (test1 <> $00) or (test2 <> $0C0) then   {leider nicht...}
 begin
  detectOPL2 := false;
 end
else
 begin
  detectOPL2 := true;
 end;
end;


Function DetectOPL3 : boolean;
{Ist ein OPL-3 Chipset vorhanden ?}
var test : byte;
begin

 if detectOPL2 then
 begin

  test := port[oplport];
  test := test and $06;

  if test = 0 then
  begin
    detectOPL3 := true;
  end
  else
  begin
    detectOPL3 := false;
  end;

 end
else
 begin
   detectOPL3 := false;
 end;

end;





{Volume Funktionen : }

procedure SetOutput(chan, op : byte; value:byte);
var d1 : byte;
begin
   d1 := OPLReg[offsets[op,chan]+$40];
   d1 := d1 and 192;
   d1 := d1 xor value;
   setreg(offsets[op,chan]+$40, d1);
end;

Procedure SetMVolume(chan,value : byte);
{Setzt Lautst„rke des Modulators
Bedenke:
0 = Laut, 63 = Leise. }
begin

     if Value > 63 then Value := 63;
     volumeM[chan] := value;       {Lautst„rke speichern}

     SetOutput(chan,0,value);

end;


Procedure SetCVolume(chan,value : byte);
{Setzt Lautst„rke des Carrier
Bedenke:
0 = Laut, 63 = Leise. }
begin
   if Value > 63 then Value := 63;
   volumeC[chan] := value;       {Lautst„rke des Channels speichern}
   SetOutput(chan,1,value);
end;




{Frequenz : }



Procedure KeyOn(chan,octave : byte;pitch : word);
var
   highpitch,
   lowpitch,boo,bot,a,b :byte;
begin
   lowpitch:= pitch and $00FF;
   highpitch:= (pitch and $FF00) shr 8;
   boo := (octave shl 2) + highpitch;
   bot := lowpitch;
   set_bit(boo, 5, true);
   setreg($B0+chan,boo);
   setreg($A0+chan,bot);
end;



Procedure Setfreq(chan : byte; freq : integer);
var
  octave,pitch : word;

begin

  asm
    mov AX,Freq
    mov CX,FreqRange
    xor DX,DX
    div CX                          {Oktave und richtige Frequenz errechnen}
    add DX,FreqStart
    mov octave,AX
    mov pitch,DX
   end;

  keyon(chan,octave,pitch);

end;



 Procedure ResetOPL;
 var ch : byte;
 begin
  for ch := 0 to 8 do
  begin
   keyon(ch,0,0);
  end;
 end;


 Procedure switchOFF(ch : byte);
 begin
   keyon(ch,0,0);
   keyoff(ch);
 end;


 Procedure ClearOPL;
 var z,z1 : byte;
 begin
  for z := 0 to 8 do
  begin
   switchoff(z);
  end;
  for z := 0 to 8 do
  begin
  for z1 := 1 to 11 do
  begin
   setreg(regs[z][z1],0);
  end;
  end;
 end;



Function GetCvolume(chan : byte) : byte;
{Liefert die aktuelle Lautstr„rke des Channels
 (aus "Old43"}
 var data,bc : byte;
begin
    {Carrier Amplitude holen}
    data := 0;
    data := OPLReg[offsets[1,chan]+$40] xor 192;
    GetCVolume := data;
end;

Function GetMvolume(chan : byte) : byte;
{Liefert die aktuelle Lautstr„rke des Channels}
 var data,bc : byte;
begin

  data := 0;
  data := 0;
  data := OPLReg[offsets[0,chan]+$40] xor 192;
  GetMVolume := data;

 GetMVolume := data;
end;




procedure SetAM(chan, op : byte; bit, amd:boolean);
begin
   set_bit(OPLReg[offsets[op,chan]+$20], 7, bit);
   {Apply amplitude modulation when set; AM depth is
    controlled by the AM-Depth flag in address BD.}

   set_bit(OPLReg[$BD], 7, amd);
{   Set:    AM depth is 4.8dB
    Clear:  AM depth is 1 dB}

   setreg(offsets[op,chan]+$20, OPLReg[offsets[op,chan]+$20]);
   setreg($BD, OPLReg[$BD]);
end;

procedure SetVib(chan, op : byte; bit, amd:boolean);
begin
   set_bit(OPLReg[offsets[op,chan]+$20], 6, bit);
{Apply vibrato when set;  vibrato depth is controlled
 by the Vib-Depth flag in address BD. }
   set_bit(OPLReg[$BD], 6, amd);
{Set:    Vibrato depth is 14 cent
 Clear:  Vibrato depth is 7 cent}
   setreg(offsets[op,chan]+$20, OPLReg[offsets[op,chan]+$20]);
   setreg($BD, OPLReg[$BD]);
end;


procedure SetEG(chan, op : byte; bit:boolean);
begin
{When set, the sustain level of the voice is maintained
                  until released; when clear, the sound begins to decay
                  immediately after hitting the SUSTAIN phase.}
   set_bit(OPLReg[offsets[op,chan]+$20], 5, bit);
   setreg(offsets[op,chan]+$20, OPLReg[offsets[op,chan]+$20]);
end;

procedure SetKSR(chan, op : byte; bit:boolean);
begin
{Keyboard scaling rate.
 This is another incomprehensible bit in the Sound Blaster manual.
 From experience, if this bit is set, the sound's envelope is foreshortened as
 it rises in pitch.}
   set_bit(OPLReg[offsets[op,chan]+$20], 4, bit);
   setreg(offsets[op,chan]+$20, OPLReg[offsets[op,chan]+$20]);
end;



procedure SetHarmonic(chan, op : byte; value:byte);
begin

{These bits indicate which harmonic the operator will
                  produce sound (or modulation) in relation to the voice's
                  specified frequency:

                      0 - one octave below
                      1 - at the voice's specified frequency
                      2 - one octave above
                      3 - an octave and a fifth above
                      4 - two octaves above
                      5 - two octaves and a major third above
                      6 - two octaves and a fifth above
                      7 - two octaves and a minor seventh above
                      8 - three octaves above
                      9 - three octaves and a major second above
                      A - three octaves and a major third above
                      B -  "       "     "  "   "     "     "
                      C - three octaves and a fifth above
                      D -   "      "     "  "   "     "
                      E - three octaves and a major seventh above
                      F -   "      "     "  "   "      "      "  }
   OPLReg[offsets[op,chan]+$20] := OPLReg[offsets[op,chan]+$20] and 240;
   OPLReg[offsets[op,chan]+$20] := OPLReg[offsets[op,chan]+$20] + value;
   setreg(offsets[op,chan]+$20, OPLReg[offsets[op,chan]+$20]);
end;


procedure SetAttack(chan, op : byte; value:byte);
var
   temp:byte;
begin
{  Reg $60:
 bits 7-4 - Attack rate.  0 is the slowest, F is the fastest.
 bits 3-0 - Decay rate.  0 is the slowest, F is the fastest.}
   temp:= OPLReg[offsets[op,chan]+$60] and 15;
   OPLReg[offsets[op,chan]+$60]:= (value shl 4) + temp;
   setreg(offsets[op,chan]+$60, OPLReg[offsets[op,chan]+$60]);
end;

procedure SetDecay(chan, op : byte; value:byte);
begin
{  Reg $60:
 bits 7-4 - Attack rate.  0 is the slowest, F is the fastest.
 bits 3-0 - Decay rate.  0 is the slowest, F is the fastest.}
   OPLReg[offsets[op,chan]+$60] := (OPLReg[offsets[op,chan]+$60] and 240) + value;
   setreg(offsets[op,chan]+$60, OPLReg[offsets[op,chan]+$60]);
end;

procedure SetSustain(chan, op : byte; value:byte);
var
   temp:byte;
begin
   temp:= OPLReg[offsets[op,chan]+$80] and 15;
   OPLReg[offsets[op,chan]+$80]:= (value shl 4) + temp;
   setreg(offsets[op,chan]+$80, OPLReg[offsets[op,chan]+$80]);
end;

procedure SetRelease(chan, op : byte; value:byte);
begin
   OPLReg[offsets[op,chan]+$80]:= (OPLReg[offsets[op,chan]+$80] and 240) + value;
   setreg(offsets[op,chan]+$80, OPLReg[offsets[op,chan]+$80]);
end;

procedure SetWaveform(chan, op : byte; value:byte);
begin
   OPLReg[offsets[op,chan]+$E0] := value;
   setreg(offsets[op,chan]+$E0, OPLReg[offsets[op,chan]+$E0]);
end;

procedure SetKSL(chan, op : byte; value:byte);
var
   temp:byte;
begin
   temp:= OPLReg[offsets[op,chan]+$40] and 63;
   OPLReg[offsets[op,chan]+$40] := (value shl 6) + temp;
   setreg(offsets[op,chan]+$40, OPLReg[offsets[op,chan]+$40]);
end;



procedure SetFeedback(channel:word; value:byte);
begin
   OPLReg[channel+$C0]:= (OPLReg[channel+$C0] and 241) + (value shl 1);
   setreg(channel+$C0,OPLReg[channel+$C0]);
end;

procedure SetFM(channel:word; value:boolean);
begin
   set_bit(OPLReg[channel+$C0], 0, value);
   setreg(channel+$C0, OPLReg[channel+$C0]);
end;




begin
 SetFnumTable(StandartFnum);
 fillchar(OPLReg,sizeof(OPLReg),0);
 oplport := adlibport;
end.

