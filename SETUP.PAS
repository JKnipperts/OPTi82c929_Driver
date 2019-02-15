{*****************************************************************************
   Setup for my OPTi 82C929 Soundcard low level driver
*****************************************************************************
Version:    1.2
Date   :    10.02.2019
Author :    Jan Knipperts
*****************************************************************************}


Program Opti929Setup;

uses opti929,mpu,oplfm,opl4,sbpro,ad1848,
     dos,textmode,misc;
type

 volumes = record
  DACL,
  DACR,
  AUX1L,
  AUX1R,
  AUX2L,
  AUX2R,
  inp,
  micgain,
  gain : byte;
  dmix : boolean;
 end;

 Freqconfig = record
  freq,
  bits,
  chan      : byte;
 end;

 freqdata  = record
  xtal     : byte;
  rate     : string;
 end;

 SBAdress  = record
 Port,
 IRQ,
 DMA        : byte;
 end;

 WSSAdress  = record
 Port,
 IRQ,
 DMA,
 DMA2        : byte;
 end;

 CDAdress  = record
 Port,
 IRQ,
 DMA,
 Typ        : byte;
 end;

 MPUAdress  = record
 Port,
 IRQ,
 DMA,
 Typ        : byte;
 end;

const
 title          : string = 'OPTi 82C929 Configuration v1.2 (c) 2019 by Jan Knipperts';
 cfgfile        : string = 'SOUND.CFG';
 autoexec       : string = 'AUTOEXEC.BAT';

 CFIX           : array[0..1] of string = ('AD18xx','CS42xx');
 FM_chip        : array[3..4] of string = ('OPL3','OPL4');
 FM_CLK         : array[2..3] of string = ('OPL2','OPL3');
 DSP            : array[1..4] of string = ('1.5','2.1','3.2','4.4');
 SB_Port        : array[1..2] of string = ('220h','240h');
 SB_IRQ         : array[1..4] of string = ('5','7','10','Disable');
 SB_DMA         : array[1..4] of string = ('0','1','3','Disable');
 WSS_Port       : array[1..4] of string = ('530h','E80h','F40h','604h');
 WSS_IRQ        : array[1..5] of string = ('7','9','10','11','Auto');
 WSS_DMA        : array[1..4] of string = ('0','1','3','Disable');
 WSS_DMA2       : array[1..3] of string = ('0','1','Disable');
 CD_PORT        : array[1..4] of string = ('320h','330h','340h','360h');
 CD_DMA         : array[1..4] of string = ('0','1','3','Disable');
 CD_IRQ         : array[1..6] of string = ('5','7','9','10','11','Disable');
 CD_TYP         : array[1..4] of string = ('Sony','Mitsumi','Panasonic','IDE');
 MPU_PORT       : array[1..4] of string = ('300h','310h','320h','330h');
 MPU_IRQ        : array[1..4] of string = ('5','7','9/2','10');
 ONOFF          : array[0..1] of string = ('Disable','Enable');
 FMap           : array[0..1] of string = ('16+24 MHz','16 MHz');
 GPMode         : array[0..1] of string = ('External','Internal');
 OUTMX          : array[0..1] of string = ('OUT0','OPL3SCN');

 Frequency      : array[0..13] of freqdata = (
 (xtal : 2; rate : ' 5.5 kHz'),
 (xtal : 2; rate : ' 6.6 kHz'),
 (xtal : 1; rate : ' 8.0 kHz'),
 (xtal : 1; rate : ' 9.6 kHz'),
 (xtal : 2; rate : '11.0 kHz'),
 (xtal : 1; rate : '16.0 kHz'),
 (xtal : 2; rate : '18.9 kHz'),
 (xtal : 2; rate : '22.0 kHz'),
 (xtal : 1; rate : '27.4 kHz'),
 (xtal : 1; rate : '32.0 kHz'),
 (xtal : 2; rate : '33.0 kHz'),
 (xtal : 2; rate : '37.8 kHz'),
 (xtal : 2; rate : '44.1 kHz'),
 (xtal : 1; rate : '48.0 kHz'));


 Bits         :  array[0..1] of string = (' 8-bit','16-bit');
 MS           :  array[0..1] of string = (' Mono ','Stereo');




var
 cnt,
 xp,
 yp,
 menu,
 mselect,
 aselect             : byte;
 quit,
 mpuoff,
 cdoff,
 irqcalled           : boolean;
 p                   : pointer;
 key                 : char;

 WSStext             : WSSAdress;
 SBtext              : SBAdress;
 MPUtext             : MPUAdress;
 CDtext              : CDAdress;

 cfg                 : OPTI929config;
 SBFreq,
 WSSFreq             : Freqconfig;
 CodecVolumes        : Volumes;
 f                   : file;

 ocnt,
 size,
 bpos,
 cpos                : word;
 s,
 newblaster,
 dir,
 initstr,
 backup              : string;
 found               : boolean;
 DirInfo             : SearchRec;
 Error               : word;
 keyboardmode        : boolean;
 apage               : byte;


 Procedure DrawSelector(xp,yp : byte; s : string);
 begin
  if not keyboardmode then
  begin
   putchar(xp+9,yp,#24,0,7);
   putchar(xp+10,yp,#25,0,7);
  end;
  fastwrite(xp,yp,14,1,'         ');
  fastwrite(xp+(4-(length(s) div 2)),yp,14,1,s);
 end;

 Procedure Mark(x,y,l : byte);
 var c : byte;
 begin
  if keyboardmode then
  begin
    for c := x to x+(l-1) do
    begin
      changeattr(c,y,14,4);
    end;
  end;
 end;

 Procedure UnMark(x,y,l : byte);
 var c : byte;
 begin
  if keyboardmode then
  begin
    for c := x to x+(l-1) do
    begin
      changeattr(c,y,14,1);
    end;
  end;
 end;


 Procedure UnSelectItem(sel : byte);
 var x,y,l : byte;
 begin
  if keyboardmode then
  begin

    if menu = 1 then
    begin
      case sel of
         1: begin y := 6;  x := 21; l := 9; end;
         2: begin y := 7;  x := 21; l := 9; end;
         3: begin y := 8;  x := 21; l := 9; end;
         4: begin y := 11; x := 28; l := 1; end;
         5: begin y := 6; x :=  58; l := 9; end;
         6: begin y := 7; x :=  58; l := 9; end;
         7: begin y := 8; x :=  58; l := 9; end;
         8: begin y := 11; x :=  64; l := 1; end;
         9: begin y := 15; x :=  24; l := 1; end;
         10: begin y := 16; x :=  21; l := 9; end;
         11: begin y := 17; x :=  21; l := 9; end;
         12: begin y := 19; x :=  26; l := 1; end;
         13: begin y := 15; x :=  67; l := 1; end;
         14: begin y := 16; x :=  56; l := 9; end;
         15: begin y := 17; x :=  56; l := 9; end;
         16: begin y := 18; x :=  56; l := 9; end;
         17: begin y := 19; x :=  56; l := 9; end;
         18: begin y := 21; x :=  13; l := 16; end;
         19: begin y := 21; x :=  34; l := 13; end;
         20: begin y := 21; x :=  52; l := 13; end;
      end;
       if y < 21 then unmark(x,y,l);
    end;

  if menu = 2 then
   begin
    if apage = 0 then
    begin
     case sel of
         1: begin y := 6;  x := 44; l := 9; end;
         2: begin y := 7;  x := 44; l := 9; end;
         3: begin y := 8;  x := 44; l := 9; end;
         4: begin y := 9;  x := 44; l := 9; end;
         5: begin y := 9;  x := 55; l := 9; end;
         6: begin y := 9;  x := 66; l := 9; end;
         7: begin y := 10;  x := 44; l := 9; end;
         8: begin y := 10;  x := 55; l := 9; end;
         9: begin y := 10;  x := 66; l := 9; end;
         10: begin y := 11;  x := 44; l := 9; end;
         11: begin y := 12;  x := 44; l := 9; end;
         12: begin y := 13;  x := 44; l := 9; end;
         13: begin y := 14;  x := 44; l := 9; end;
         14: begin y := 15;  x := 44; l := 9; end;
         15: begin y := 16;  x := 44; l := 9; end;
         16: begin y := 17;  x := 44; l := 9; end;
         17: begin y := 18;  x := 44; l := 9; end;
         18: begin y := 19;  x := 44; l := 9; end;
         19: begin y := 20;  x := 44; l := 9; end;
         20: begin y := 22;  x := 9;  l := 6; end;
         21: begin y := 22;  x := 44; l := 11; end;
      end;
       if y < 22 then unmark(x,y,l);
   end
   else
   begin
      case sel of
         1: begin y := 6;  x := 44; l := 9; end;
         2: begin y := 7;  x := 44; l := 9; end;
         3: begin y := 8;  x := 44; l := 9; end;
         4: begin y := 9;  x := 44; l := 9; end;
         5: begin y := 10;  x := 44; l := 9; end;
         6: begin y := 11;  x := 44; l := 9; end;
         7: begin y := 22;  x := 9;  l := 6; end;
         8: begin y := 22;  x := 44; l := 11; end;
      end;
      if y < 22 then unmark(x,y,l);
   end;
  end;
 end;
 end;



 Procedure SelectItem(sel : byte);
 var x,y,l : byte;
 begin

 if keyboardmode then
  begin

    if menu = 1 then
    begin
      case sel of
         1: begin y := 6;  x := 21; l := 9; end;
         2: begin y := 7;  x := 21; l := 9; end;
         3: begin y := 8;  x := 21; l := 9; end;
         4: begin y := 11; x := 28; l := 1; end;
         5: begin y := 6; x :=  58; l := 9; end;
         6: begin y := 7; x :=  58; l := 9; end;
         7: begin y := 8; x :=  58; l := 9; end;
         8: begin y := 11; x :=  64; l := 1; end;
         9: begin y := 15; x :=  24; l := 1; end;
         10: begin y := 16; x :=  21; l := 9; end;
         11: begin y := 17; x :=  21; l := 9; end;
         12: begin y := 19; x :=  26; l := 1; end;
         13: begin y := 15; x :=  67; l := 1; end;
         14: begin y := 16; x :=  56; l := 9; end;
         15: begin y := 17; x :=  56; l := 9; end;
         16: begin y := 18; x :=  56; l := 9; end;
         17: begin y := 19; x :=  56; l := 9; end;
         18: begin y := 21; x :=  13; l := 16; end;
         19: begin y := 21; x :=  34; l := 13; end;
         20: begin y := 21; x :=  52; l := 13; end;
      end;
    end;

  if menu = 2 then
   begin
    if apage = 0 then
    begin
     case sel of
         1: begin y := 6;  x := 44; l := 9; end;
         2: begin y := 7;  x := 44; l := 9; end;
         3: begin y := 8;  x := 44; l := 9; end;
         4: begin y := 9;  x := 44; l := 9; end;
         5: begin y := 9;  x := 55; l := 9; end;
         6: begin y := 9;  x := 66; l := 9; end;
         7: begin y := 10;  x := 44; l := 9; end;
         8: begin y := 10;  x := 55; l := 9; end;
         9: begin y := 10;  x := 66; l := 9; end;
         10: begin y := 11;  x := 44; l := 9; end;
         11: begin y := 12;  x := 44; l := 9; end;
         12: begin y := 13;  x := 44; l := 9; end;
         13: begin y := 14;  x := 44; l := 9; end;
         14: begin y := 15;  x := 44; l := 9; end;
         15: begin y := 16;  x := 44; l := 9; end;
         16: begin y := 17;  x := 44; l := 9; end;
         17: begin y := 18;  x := 44; l := 9; end;
         18: begin y := 19;  x := 44; l := 9; end;
         19: begin y := 20;  x := 44; l := 9; end;
         20: begin y := 22;  x := 9;  l := 6; end;
         21: begin y := 22;  x := 44; l := 11; end;
      end;
   end
   else
   begin
      case sel of
         1: begin y := 6;  x := 44; l := 9; end;
         2: begin y := 7;  x := 44; l := 9; end;
         3: begin y := 8;  x := 44; l := 9; end;
         4: begin y := 9;  x := 44; l := 9; end;
         5: begin y := 10;  x := 44; l := 9; end;
         6: begin y := 11;  x := 44; l := 9; end;
         7: begin y := 22;  x := 9;  l := 6; end;
         8: begin y := 22;  x := 44; l := 11; end;
      end;
   end;
  end;

  mark(x,y,l);
 end;
end;


Procedure HLine(y : byte);
 begin
  putchar(4,y,#199,15,1);
  for cnt := 5 to 77 do
  putchar(cnt,y,#196,15,1);
  putchar(77,y,#182,15,1);
 end;

Procedure Button(x,y : byte; name : string; pressed : boolean);
 var col,c : byte;
 begin
  if pressed then col := 1 else col := 0;
  fastwrite(x,y,0,7,name);
  c := 1;
  while (name[c] = ' ') and (c <= length(name)) do inc(c);
  putchar(x+(c-1),y,name[c],4,7);
  for c := x+1 to x+length(name) do fastwrite(c,y+1,col,1, 'ß');
  fastwrite(x+length(name),y,col,1, 'Ü');
 end;

 Procedure Wait_for_Mousebutton;
 begin
     repeat
         Mouse_Read;
         while iskeypressed do getkey;
     until mouse.b = 0;
     key := #0;
     case menu of
     1: selectitem(mselect);
     2: selectitem(aselect);
     3: selectitem(aselect);
     end;
 end;


 Procedure MapCFGtoText;
 begin

  if cfg.sbbase = $220 then sbtext.port := 1 else sbtext.port := 2;

  case cfg.sbIRQ of
     5: sbtext.irq := 1;
     7: sbtext.irq := 2;
    10: sbtext.irq := 3;
   $FF: sbtext.irq := 4;
  end;

  case cfg.sbdma of
     0: sbtext.dma := 1;
     1: sbtext.dma := 2;
     3: sbtext.dma := 3;
   $FF: sbtext.dma := 4;
  end;

  case cfg.wssbase of
   $530: wsstext.port := 1;
   $E80: wsstext.port := 2;
   $F40: wsstext.port := 3;
   $604: wsstext.port := 4;
  end;

  case cfg.wssIRQ of
     7: wsstext.irq := 1;
     9: wsstext.irq := 2;
    10: wsstext.irq := 3;
    11: wsstext.irq := 4;
   $FF: wsstext.irq := 5;
  end;

  case cfg.wssDMA of
    0: wsstext.dma := 1;
    1: wsstext.dma := 2;
    3: wsstext.dma := 3;
   $FF: wsstext.dma := 4;
  end;

  case cfg.mpubase of
    $300: mputext.port := 1;
    $310: mputext.port := 2;
    $320: mputext.port := 3;
    $330: mputext.port := 4;
  end;

  case cfg.mpuirq of
    5: mputext.irq := 1;
    7: mputext.irq := 2;
    9: mputext.irq := 3;
    10: mputext.irq := 4;
  end;

  cdtext.typ := cfg.cdtype;

  case cfg.cdbase of
    $320: cdtext.port := 1;
    $330: cdtext.port := 2;
    $340: cdtext.port := 3;
    $360: cdtext.port := 4;
  end;
  case cfg.cddma of
     0: cdtext.dma := 1;
     1: cdtext.dma := 2;
     3: cdtext.dma := 3;
   $FF: cdtext.dma := 4;
  end;

  case cfg.cdirq of
      5: cdtext.irq := 1;
      7: cdtext.irq := 2;
      9: cdtext.irq := 3;
     10: cdtext.irq := 4;
     11: cdtext.irq := 5;
    $FF: cdtext.irq := 6;
  end;

 end;

Procedure SetStandardcfg;
begin
 with cfg do
 begin
  initmode    := 0;   {Set SB or WSS mode?}
  powerdwn    := 0;   {Enable/Disable Powerdown mode}
  silence     := 0;   {Enable/Disable silence mode}
  Cfix        := 0;   {We assume an Analog Devices codec}
  shprotect   := 0;   {Shadow Register protection off}
  access      := 0;   {No access to codec in SB Mode}
  wave        := 1;

  CDTYPE      := $FF;  {FF = disable CD-ROM }
  CDBASE      := $340; {Port for CD-ROM}
  CDIRQ       := $FF; {IRQ for CD-ROM}
  CDDMA       := 3;   {DMA channel for CD-ROM}

  SBBASE      := $220;   {SB Port}
  SBIRQ       := 5;   {SB IRQ}
  SBDMA       := 1;   {SB DMA}
  SBVER       := 3;   {SB Version}
  FMAP        := 0;   {Simple SB Frequencymapping}
  FIFO        := 0;   {Disable command FiFo in SB Mode}
  SBMIX       := 1;   {Enable Sound Blaser Mixer chip emulation}
  AUTOVOL     := 0;   {Disabel Automatic volume control}
  ADPCM       := 1;   {Enable ADPCM support}
  TIMEOUT     := 1;   {Enable timeout acknowledge
  DMAWD       := 0;   {Disable DMA watch dog}
  ATTN        := 1;   {Enable Attenuation }

  WSSBase     := $530; {WSS Port}
  WSSDMA      := 1;    {WSS DMA channel 1}
  WSSIRQ      := $FF;  {Auto IRQ selection for WSS}

  GPEN        := 1;   {GamePort enabled}
  GPMODE      := 1;   {Select internal Game Port Timer}
  OUTMX       := 0;   {.. and timing mode OPL3SCn}
  GPOUT       := 0;   {General Purpose outputs disabled}
  OPL         := 3;   {OPL 3 FM}
  FMCLK       := 3;   {OPL 3 clock}

  MPU401      := 1;   {MPU-401 enabled}
  MPUBASE     := $330; {MPU401 Port}
  MPUIRQ      := 9;   {MPU401 IRQ}
 end;

 fillchar(codecvolumes,sizeof(codecvolumes),15); {middle all volumes}
 codecvolumes.inp := Postmx;  {Post mix input}
 codecvolumes.micgain := 0; {disable +20 db mic gain}
 codecvolumes.gain := 0; {set gain to 0, mute input}
 codecvolumes.dmix := true; {digital mix enabled}

 SBFreq.freq := 7;  {22050 Hz, 8 Bit, Stereo}
 SBFreq.bits := 0;
 SBFreq.chan := 1;
 WSSFreq.freq := 12; {44100 Hz, 16 Bit, Stereo}
 WSSFreq.bits := 1;
 WSSFreq.chan := 1;

end;



Procedure LoadCfg;
begin

 write('Loading configuration...');

  assign(f,cfgfile);
  reset(f,1);

   if filesize(f) <> (sizeof(cfg)+(2*sizeof(freqconfig))+sizeof(volumes)) then
   begin
     writeln('ERROR!');
     writeln('');
     writeln('Configuration file is damaged!');
     writeln('Creating a new file with default settings.');
     writeln('');
     writeln('Press any key to continue....');
     waitkey;
     setstandardcfg;
     close(f);
   end
   else
   begin
     {$I-}
     blockread(f,cfg,sizeof(cfg));
     blockread(f,sbfreq,sizeof(freqconfig));
     blockread(f,wssfreq,sizeof(freqconfig));
     blockread(f,codecvolumes,sizeof(codecvolumes));

     if IOResult <> 0 then
     begin
       writeln('ERROR!');
       writeln('');
       writeln('Settings could not be read!');
       writeln('Using default settings.');
       writeln('');
       writeln('Press any key to continue....');
       waitkey;
       setstandardcfg;
     end;

     close(f);
     writeln('');
   end;

  MapCFGtoText;
end;


Procedure SaveCfg;
begin
  assign(f,cfgfile);
  {$I-}
  rewrite(f,1);
  {$I+}
     if IOResult <> 0 then
     begin
      clrscr;
      writeln('ERROR!');
      writeln('');
      writeln('Configuration file could not be written! ');
      writeln('Settings were not saved!');
      writeln('');
      close(f);
      cursor(true);
      halt(1);
     end;

    {$I-}
     blockwrite(f,cfg,sizeof(cfg));
     blockwrite(f,sbfreq,sizeof(freqconfig));
     blockwrite(f,wssfreq,sizeof(freqconfig));
     blockwrite(f,codecvolumes,sizeof(codecvolumes));
    {$I+}

     if IOResult <> 0 then
     begin
      clrscr;
      writeln('ERROR!');
      writeln('');
      writeln('Configuration file could not be written! ');
      writeln('Settings were not saved!');
      writeln('');
      close(f);
      cursor(true);
      halt(1);
     end;
  close(f);
  writeln('Settings have been saved.');
end;



Procedure CenteredText(y,c : byte; s : string);
begin
 fastwrite(40-(length(s) div 2),y,c,1,s);
end;

Procedure DelChars(x,y,c : byte);
var cnt : byte;
begin
 for cnt := x to x+c do
 putchar(cnt,y,' ',15,1);
end;


Procedure Draw_Main_Menu;
var c : byte;
begin
 MapCFGtoText;
 fillchar(p^,4000,0);
 writeto(p);

 InitMenuScreen(title);
 Window(4,3,77,23,15,1,true);
 putchar(40,3,'Ñ',15,1);
 for cnt := 4 to 19 do
 putchar(40,cnt,'³',15,1);

 fastwrite(9,4,14,1,'Sound Blaster configuration');
 fastwrite(9,6,15,1,'Address:');
 fastwrite(9,7,15,1,'Interrupt:');
 fastwrite(9,8,15,1,'DMA:');

 Drawselector(21,6,SB_Port[sbtext.port]);
 Drawselector(21,7,SB_IRQ[sbtext.irq]);
 Drawselector(21,8,SB_DMA[sbtext.dma]);


 fastwrite(9,11,14,1,'Set SB as default [ ]');


 fastwrite(44,4,14,1,'WSS configuration');
 fastwrite(44,6,15,1,'Address:');
 fastwrite(44,7,15,1,'Interrupt:');
 fastwrite(44,8,15,1,'Playback DMA:');
 fastwrite(44,11,14,1,'Set WSS as default [ ]');


 Drawselector(58,6,WSS_Port[wsstext.port]);
 Drawselector(58,7,WSS_IRQ[wsstext.irq]);
 Drawselector(58,8,WSS_DMA[wsstext.dma]);

 HLine(12);
 putchar(40,12,'Å',15,1);

 fastwrite(9,13,14,1,'MPU401 configuration');
 fastwrite(9,15,15,1,'Enable MPU401 [ ]');

 if cfg.mpu401 = 1 then
 begin
  fastwrite(9,16,15,1,'Address:');
  fastwrite(9,17,15,1,'Interrupt:');
  Drawselector(21,16,MPU_Port[mputext.port]);
  Drawselector(21,17,MPU_IRQ[mputext.irq]);
 end;

 fastwrite(9,19,15,1,'Enable gameport [ ]');

 fastwrite(44,13,14,1,'CD-ROM configuration');
 fastwrite(44,15,15,1,'Enable CD-ROM support [ ]');


 if ((cfg.CDTYPE <> $FF) and (cfg.CDIRQ <> $FF)) then
 begin
   putchar(67,15,'x',15,1);
   fastwrite(44,16,15,1,'Type:');
   fastwrite(44,17,15,1,'Address:');
   fastwrite(44,18,15,1,'Interrupt:');
   fastwrite(44,19,15,1,'DMA:');
   Drawselector(56,16,CD_TYP[cdtext.typ]);
   Drawselector(56,17,CD_PORT[cdtext.port]);
   Drawselector(56,18,CD_IRQ[cdtext.irq]);
   Drawselector(56,19,CD_DMA[cdtext.dma]);
   cdoff := false;
 end
 else
 begin
  cdoff := true;
 end;


 HLine(20);
 putchar(40,20,'Å',15,1);
 putchar(40,20,'Á',15,1);
 Button(13,21,'Advanced Options',false);
 Button(34,21,'Test Settings',false);
 Button(52,21,'Save and quit',false);

 if cfg.gpen = 1 then putchar(26,19,'x',14,1);
 if cfg.mpu401 = 1 then putchar(24,15,'x',14,1);

 if cfg.initmode = 0 then
    putchar(28,11,'x',15,1)
 else
    putchar(64,11,'x',15,1);

 ViewBuffer(p);
 writeto(ptr(segB800,0));
 SelectItem(mselect);

end;


Procedure Draw_Advanced_Menu;
begin
  fillchar(p^,4000,0);
  writeto(p);
  InitMenuScreen(title);
  Window(4,3,77,24,15,1,true);
  centeredtext(4,14,'Advanced Options');
  HLine(5);

  if apage = 0 then
  begin
    fastwrite(9,6,15,1,'Codec selection:');
    fastwrite(9,7,15,1,'Yamaha Synthesis Chip selection: ');
    fastwrite(9,8,15,1,'FM Timer Mode: ');
    fastwrite(9,9,15,1,'Frequency for WSS mode:');
    fastwrite(9,10,15,1,'Frequency for SB mode:');
    fastwrite(9,11,15,1,'Crystals used for SB frequencies:');
    fastwrite(9,12,15,1,'Sound Blaster DSP Version:');
    fastwrite(9,13,15,1,'Automatic Volume Control:');
    fastwrite(9,14,15,1,'Sound Blaster ADPCM support:');
    fastwrite(9,15,15,1,'Command FIFO in Sound Blaster mode: ');
    fastwrite(9,16,15,1,'Game Port Timer Mode:');
    fastwrite(9,17,15,1,'Internal GP Timer Mode:');
    fastwrite(9,18,15,1,'General Purpose Outputs:');
    fastwrite(9,19,15,1,'SB mixer voice volume emulation:');
    fastwrite(9,20,15,1,'Writeprotect shadow registers:');

    Drawselector(44,6,CFIX[cfg.cfix]);
    Drawselector(44,7,FM_chip[cfg.opl]);
    Drawselector(44,8,FM_CLK[cfg.fmclk]);
    Drawselector(44,9,Frequency[WSSFreq.freq].rate);
    Drawselector(55,9,Bits[WSSFreq.bits]);
    Drawselector(66,9,MS[WSSFreq.chan]);

    if (cfg.fmap = 1) and (Frequency[SBFreq.freq].xtal = 1) then
    begin
      repeat;
        if SBfreq.freq = 0 then SBfreq.freq := 13 else dec(SBfreq.freq);
      until Frequency[SBFreq.freq].xtal = 2;
    end;

    Drawselector(44,10,Frequency[SBFreq.freq].rate);
    Drawselector(55,10,Bits[SBFreq.bits]);
    Drawselector(66,10,MS[SBFreq.chan]);
    Drawselector(44,11,FMAP[cfg.fmap]);
    Drawselector(44,12,DSP[cfg.sbver]);
    Drawselector(44,13,ONOFF[cfg.autovol]);
    Drawselector(44,14,ONOFF[cfg.adpcm]);
    Drawselector(44,15,ONOFF[cfg.fifo]);
    Drawselector(44,16,GPMODE[cfg.gpmode]);
    Drawselector(44,17,OUTMX[cfg.outmx]);
    Drawselector(44,18,ONOFF[cfg.gpout]);
    Drawselector(44,19,ONOFF[cfg.sbmix]);
    Drawselector(44,20,ONOFF[cfg.shprotect]);
  end
  else
  begin
    fastwrite(9,6,15,1,'Attenuation:');
    fastwrite(9,7,15,1,'DMA watch dog: ');
    fastwrite(9,8,15,1,'Use CDOE cmd:');
    fastwrite(9,9,15,1,'Disable host access to FM,SB/WSS: ');
    fastwrite(9,10,15,1,'Acknowledge chip timeout: ');
    fastwrite(9,11,15,1,'Allow access to codec in SB mode: ');
    Drawselector(44,6,ONOFF[cfg.attn]);
    Drawselector(44,7,ONOFF[cfg.dmawd]);
    Drawselector(44,8,ONOFF[cfg.wave]);
    Drawselector(44,9,ONOFF[cfg.silence]);
    Drawselector(44,10,ONOFF[cfg.timeout]);
    Drawselector(44,11,ONOFF[cfg.access]);
  end;



  HLine(21);

  if apage > 0 then
   Button(9,22,' Back ',false)
  else
   Button(9,22,' Next ',false);

  Button(44,22,' Main menu ',false);
  ViewBuffer(p);
  writeto(ptr(segB800,0));
  SelectItem(aselect);
end;



Procedure Prepare_AD1848_for_SB;
  {Configure the codec to a propper format and frequency for Sound Blaster compatibility}
  var dummy : byte;
  begin

     asm
      cli
     end;
        WaitForCodec;  {Just to be sure the codec is ready}


        case sbfreq.bits of
        0:  dummy := PCM_U_8BIT;
        1:  dummy := PCM_COMPL_16BIT;
        end;

        AD1848_SetOutputFormat(codec_rates[SBFreq.freq+1].freq,
                               dummy,boolean(sbfreq.chan)); {Set format and frequency}

        Calibrate_AD1848;  {Recalibrate codec o new samplerate}
        WaitForCodec;  {Wait for the codec to be ready again}
     asm
      sti
     end;
   end;

Procedure Prepare_AD1848_for_WSS;
  {Sets the codec to a propper format and frequency for WSS output and
   performs a full autocalibration of the codec}
  var dummy : byte;
  begin

     asm
      cli
     end;
        WaitForCodec;  {Just to be sure the codec is ready}


        case wssfreq.bits of  {8 or 16 bit sound?}
        0:  dummy := PCM_U_8BIT;
        1:  dummy := PCM_COMPL_16BIT;
        end;

        AD1848_SetOutputFormat(codec_rates[SBFreq.freq+1].freq,
                               dummy,boolean(wssfreq.chan)); {Set format and frequency}

        Calibrate_AD1848;  {Recalibrate codec o new samplerate}
        WaitForCodec;  {Wait for the codec to be ready again}

     asm
      sti
     end;
   end;


Function TestSBDMA : Boolean;
{Lets the Sound Blaster DSP request a DMA transfer and checks if the right channel is requested}
var
  Before, After : Byte;
  Count : Word;

begin
  DSP_Reset(cfg.sbbase);
  SB_ResetMixer;
  SB_SetDataformat(PCM_8Bit);


  DSP_Write($D1);            {DSP-command D1h - Enable speaker, required
                                on older SB's}

  DSP_Write($40);             {DSP-command 40h - Set sample frequency}
  DSP_Write(165);             {Write time constant for 11025Hz}

  DSP_Write($14);             {DSP-command 14h - 8bit playback}
  DSP_Write($03);             {Set the block length to 3 = 1 DWORD}

  Count := 0;

  {Disable interrupts}
  asm
    cli
  end;

  {Look at the current state of the DMA requests}
  Before := Port [8] and $E0;

  {Start playback}
  DSP_Write($00);

  repeat
    {Check them again until there is a change or it takes too long}
    After := Port [8] and $E0;
    inc (Count);
  until (Before <> After) or (Count > 60000);

  {Reenable interrupts}
  asm
    sti
  end;
  SB_HaltDMA;

  {Is there a change?}
  if Before <> After then
  begin
    Count := 0;
    After := After xor Before;
    {If yes, which bit is set?}

    while (After > 0) do
    begin
      inc (Count);
      After := After shr 1;
    end;

    if (Count - 5) = cfg.sbdma then TestSBDMA := true;
    DSP_reset(cfg.sbbase);
    exit;
  end;
  {No DMA transfer occured?}

  TestSBDMA := false;
  DSP_reset(cfg.sbbase);

end;


Function TestWSSDMA : Boolean;
{Lets the codec request a DMA transfer and checks if the right channel is requested}
var
  Before, After : Byte;
  Count : Word;

begin
  {Set the block length to 3}
  WriteCODECReg($0E,3);
  WriteCODECReg($0F,0);

  Count := 0;

  {Disable interrupts}
  asm
    cli
  end;

  {Look at the current state of the DMA requests}
  Before := Port [8] and $E0;

  writeCODECreg($0A,$02);   {enable interrupt and pin control}
  Playback(true);           {start playback}

  repeat
    {Check them again until there is a change or it takes too long}
    After := Port [8] and $E0;
    inc (Count);
  until (Before <> After) or (Count > 60000);

  {Reenable interrupts}
  asm
    sti
  end;

  {Reset DSP}
  Playback(false);

  {Is there a change?}
  if Before <> After then
  begin
    Count := 0;
    After := After xor Before;
    {If yes, which bit is set?}

    while (After > 0) do
    begin
      inc (Count);
      After := After shr 1;
    end;

     if (Count - 5) = cfg.wssdma then TestWSSDMA := true;
     Exit;
  end;

  {No DMA???}
  TestWSSDMA := false;


end;

{$F+,S-,W-}
Procedure ServiceIRQ; interrupt;
{Pur little interrupt routine. Just to check if an interrupt occured}
var
  Temp : Byte;

begin
  irqcalled := true;
  Temp := Port[cfg.sbbase + $E];
  Port[$20] := $20;
end;
{$F-,S+}



Function TestSBIRQ(irq : byte) : boolean;
{Lets the SB DSP do a DMA transfer and checks if the right interrupt is called}
var  count : word;
begin
  DSP_reset(cfg.sbbase);
  IRQcalled := false;
  SB_Install_IRQ(irq,Addr (ServiceIRQ));

  DSP_Write($D1);                {DSP-command D1h - Enable speaker, required
                                on older SB's}
  DSP_Write($40);                {DSP-command 40h - Set sample frequency}
  DSP_Write(165);                {Write time constant for 11025Hz}

  Port[$0A] := 4 + cfg.SBDMA;      {Mask DMA channel}
  Port[$0C] := 0;               {Clear byte pointer}
  Port[$0B] := $49;             {Set mode}

  Port[1 + cfg.SBDMA shl 1] := $01; {Set the block length to 1 = 1 byte}
  Port[1 + cfg.SBDMA shl 1] := $00;

  Port[$0A] := cfg.SBDMA;           {Unmask DMA channel}

  DSP_Write($14);                {DSP-command 14h - Single cycle playback}
  DSP_Write($01);                {Set the block length to 1 = 1 byte}
  DSP_Write($00);

  Count := 0;
  repeat
    {Wait until either the IRQ service routines has been called
    or it takes too long}
    inc (Count);

  until (IRQcalled = true) or (Count = $FFFF);
  SB_Uninstall_IRQ;
  DSP_reset(cfg.sbbase);


  TestSBIRQ := IRQcalled;

end;



Procedure TestSB;
{Tests if basic Soud Blaster functions are working with the acutal configuration}
var testdma : byte;
begin
    mouse_hide;
    centeredtext(12,15,'Please wait...');
      mouse_show;

    Waitforcodec;
    Prepare_AD1848_for_SB;
    SetSBMode(cfg);

  if (DSP_Reset(cfg.sbbase) = false) or
     (hi(SB_GetDSPVersion) <> cfg.sbver) or
     (SBerror <> 0) then
  begin
    centeredtext(11,12,'Sound Blaster DSP '+DSP[cfg.sbver]+' at port '+hexw(cfg.sbbase)+'h - FAILED!');
    delchars(20,12,30);
    exit;
  end
  else
  begin
    centeredtext(11,15,'Sound Blaster DSP '+DSP[cfg.sbver]+' at port '+hexw(cfg.sbbase)+'h - OK');
  end;


  if cfg.sbdma <> $FF then
  begin

    if (cdoff = false) and (cfg.SBDMA = cfg.CDDMA) then
    begin
      centeredtext(12,12,'DMA channel conflicts with CD-ROM!')
    end
    else
    begin

      if  (SBerror <> 0) or (testSBdma = false) then
      begin
       centeredtext(12,12,'Testing DMA transfer - FAILED!');
      end
      else
      begin
        centeredtext(12,15,'Testing DMA transfer -  OK');
      end;

    end;
   end;

  if cfg.sbirq <> $FF then
  begin

    if cfg.sbirq = cfg.cdirq then
    begin
      centeredtext(13,12,'IRQ conflicts with CD-ROM settings!');
      exit;
    end;

    TestSBIRQ(cfg.sbirq);

    if (TestSBIRQ(cfg.sbirq) = false) or (SBerror > 0) then
    begin
      centeredtext(13,12,'Testing IRQ '+hexb(cfg.sbirq)+' - FAILED!');
      exit;
    end
    else
    begin
      centeredtext(13,15,'Testing IRQ '+hexb(cfg.sbirq)+' - OK');
    end;

  end;

  DSP_Reset(cfg.sbbase);
  SB_Speaker(false);
    mouse_show;
end;

Procedure TestWSS;
{Tests if basic Windows Sound System functions are working with the acutal configuration}
var c,testdma : byte;
begin
  mouse_hide;
  centeredtext(7,15,'Please wait...');
    mouse_show;
  CODEC.WSSPort := cfg.WSSBase;
  CODEC.ADDR    := cfg.WSSBase+4;
  CODEC.DATA    := cfg.WSSBase+5;
  CODEC.STATUS  := cfg.WSSBase+6;
  CODEC.PIO     := cfg.WSSBase+7;


  SetWSSMode(cfg);
  Init_AD1848;
  Waitforcodec;
  MuteDAC(LeftAndRight,true);
  MuteAUX1(LeftAndRight,true);
  MuteAUX2(LeftAndRight,true);
  Waitforcodec;
  Prepare_AD1848_for_WSS;
  Waitforcodec;

  mouse_hide;

  if (DetectAD1848 = false) or (detectWSS = false) or (timeout = true) then
  begin
    centeredtext(7,12,'WSS at port '+hexw(cfg.wssbase)+'h - NOT FOUND!');
  end
  else
  begin
    centeredtext(7,15,'WSS at port '+hexw(cfg.wssbase)+'h - OK');
  end;

  if cfg.wssdma <> $FF then
  begin

    if (cdoff = false) and (cfg.WSSDMA = cfg.CDDMA) then {conflict with cd-rom?}
    begin
      centeredtext(8,12,'DMA channel conflicts with CD-ROM!')
    end
    else
    begin

      if testWSSdma = false then
      begin
       centeredtext(8,12,'Testing DMA transfer - FAILED!');
      end
      else
      begin
        centeredtext(8,15,'Testing DMA transfer - OK');
      end;

    end;
  end;

     mouse_show;


end;


Procedure TestMPU;
{Tests if basic MPU-401 functionality is working with the acutal configuration}
begin
  DATAPORT := cfg.mpubase;
  COMDPORT := cfg.mpubase+1;
  STATPORT := cfg.mpubase+1;

  mouse_hide;

  ResetMPU(0);
  xdelay(50);

  if not ResetMPU(0) then
  begin
    centeredtext(16,12,'MPU-401 FAILED!')
  end
  else
  begin
    if not ResetMPU(1) then
    begin
      centeredtext(16,12,'MPU-401 UART mode - FAILED!')
    end
    else
    begin
      centeredtext(16,15,'MPU-401 UART mode - OK');
    end;
  end;

    mouse_show;
  ResetMPU(0);
end;

Procedure TestFM;
{Tests if an OPL3 is present at port $388}
begin
   InitOPL;
   mouse_hide;
   if detectOPL3 then
   begin
     if OPL4_detect then
     begin
      centeredtext(20,15,'Yamaha OPL4 Wavetable synthesis chip at ports '+hexw(OPL4_PCM_PORT)+'h, '+hexw(OPL4_FM_PORT)+'h');
      if OPL4ML then
      begin
        centeredtext(21,15,'OPL4-ML with 1 MB internal ROM');
      end
      else
      begin
        if OPL4_YRW801_detect then
        centeredtext(21,15,'OPL4 with Yamaha YRW801 2 MB Wavetable ROM');
        if OPL4_SRAM then
        centeredtext(21,15,'OPL4 with SRAM for Wavetable');
      end;
    end
    else
    begin
       centeredtext(20,15,'Yamaha OPL3 FM synthesis chip at port '+hexw(oplport)+'h');
    end;

      ClearOPL; {Reset OPL-Chip and mute all channels}
   end
   else
   begin
     centeredtext(20,12,'No Yamaha synthesis chip found!');
   end;




     mouse_show;
end;

Procedure TestSettings;
begin
  fillchar(p^,4000,0);
  writeto(p);
  InitMenuScreen(title);
  Window(4,3,77,24,15,1,true);
  centeredtext(4,14,'Test settings');
  HLine(5);
  centeredtext(6,14,'Testing Windows Sound System:');
  centeredtext(10,14,'Testing Sound Blaster:');
  centeredtext(15,14,'Testing MPU 401:');
  centeredtext(19,14,'Testing FM synthesis chip:');
  Button(39,22,' OK ',false);
  mouse_hide;
  ViewBuffer(p);
  writeto(ptr(segB800,0));
    mouse_show;
  menu := 3;

  TestWSS;
  TestSB;

  if cfg.mpu401 = 1 then
    TestMPU
  else
    centeredtext(16,7,'MIDI Processing Unit is disabled.');

  TestFM;


end;


{========================= Autoexec.bat =================================}

Function UpperCase(low : string) : string;
{Converts a string to uppercase chars}
var up : string;
    sz  : byte;
begin
  up := '';
  for sz := 1 to length(low) do
  begin
   up := up+upcase(low[sz]);
  end;
   UpperCase := up;
end;


Function readcmd : string;
var
b   : byte;
out : string;
begin
 out := '';
 repeat;
  b := mem[seg(p^):ofs(p^)+ocnt];
  out := out+chr(b);
  inc(ocnt);
 until (ocnt = size) or
       (length(out) = 255) or
       (b = 10);
 readcmd := out;
end;




Procedure Load_to_mem;
begin
 if not fileexist(autoexec) then
 begin
  writeln('');
  writeln('ERROR: Can''t find Autoexec.bat!');
  writeln('');
  cursor(true);
  halt(1);
 end;
 assign(f,autoexec);
 reset(f,1);
  if filesize(f) > 65535 then
  begin
   writeln('');
   writeln('ERROR: The filesize of Autoexec.bat is too large!');
   writeln('');
   close(f);
   cursor(true);
   halt(1);
  end;
  size := filesize(f);
  getmem(p,65535);
  {$I-}
  blockread(f,p^,size);
  {$I+}
 If IOResult <> 0 then
 begin
  close(f);
  writeln('');
  writeln('ERROR: Error reading AUTOEXEC.BAT!');
  writeln('');
  halt(1);
 end;

 close(f);

 assign(f,BACKUP);
 {$I-}
 rewrite(f,1);
 {$I+}
 If IOResult <> 0 then
 begin
  writeln('');
  writeln('ERROR: Cannot create backup of AUTOEXEC.BAT');
  writeln('');
  halt(1);
 end;
 {$I-}
  blockwrite(f,p^,size);
 {$I+}
 If IOResult <> 0 then
 begin
  writeln('');
  writeln('ERROR: Cannot write to backup file!');
  writeln('');
  close(f);
  halt(1);
 end;

  close(f);

end;

Procedure Write_Mem_back;
begin
 assign(f,autoexec);
 {$I-}
 rewrite(f,1);
  blockwrite(f,p^,size);
 close(f);
 {$I+}

 freemem(p,65535);

  if IOREsult <> 0 then
  begin
   writeln('');
   writeln('ERROR: Error writing to AUTOEXEC.BAT!');
   writeln('');
   halt(1);
  end;
end;


Procedure Update_BLASTER;
var dummy : byte;

begin
 ocnt := 0;
 found := false;
 repeat;
  bpos := ocnt;
  s := readcmd;
  s := Uppercase(s);

  if pos('BLASTER',s) > 0 then
  begin
   found := true;
   cpos := bpos;

   if length(s) >= length(newblaster) then
   begin
    for dummy := 1 to length(s) do       {Alten Eintrag lschen}
    begin
     mem[seg(p^):ofs(p^)+bpos+(dummy-1)] := 0;
    end;
    for dummy := 1 to length(newblaster) do       {Neuen Eintrag einfgen}
    begin
     mem[seg(p^):ofs(p^)+bpos+(dummy-1)] := ord(newblaster[dummy]);
    end;

    move(ptr(seg(p^),ofs(p^)+(bpos+length(s)))^,
         ptr(seg(p^),ofs(p^)+(bpos+length(newblaster)))^,
         size-(bpos+length(s)));
    size := size - (length(s)-length(newblaster));
   end
   else
   begin
     move(ptr(seg(p^),ofs(p^)+bpos+length(s))^,ptr(seg(p^),ofs(p^)+bpos+length(newblaster))^,size-(bpos+length(s)));
     for dummy := 1 to length(newblaster) do       {Neuen Eintrag einfgen}
     begin
      mem[seg(p^):ofs(p^)+bpos+(dummy-1)] := ord(newblaster[dummy]);
     end;
     size := size + (length(newblaster)-length(s));
   end;

  end;

 until ocnt >= size;
end;


Procedure Create_Blaster;
var dummy : byte;
begin
   ocnt := 0;
   repeat
   s := readcmd;
   s := Uppercase(s);
   until (pos('ECHO',s) = 0) and
         (pos('CLS',s) = 0);
   bpos := ocnt-length(s);

   move(ptr(seg(p^),ofs(p^)+(bpos))^,
        ptr(seg(p^),ofs(p^)+(bpos+length(newblaster)))^,
        size-bpos);

   for dummy := 1 to length(newblaster) do       {Neuen Eintrag einfgen}
   begin
     mem[seg(p^):ofs(p^)+bpos+(dummy-1)] := ord(newblaster[dummy]);
   end;

   size := size + length(newblaster);
   cpos := bpos;
end;

Procedure Find_INIT929;
begin
 ocnt := 0;
 found := false;
 repeat;
  s := readcmd;
  s := Uppercase(s);
  if pos('929INIT.EXE',s) > 0 then
  begin
   found := true;
  end;
 until ocnt >= size;
end;

Procedure Create_INIT;
var dummy : byte;
begin
   cpos := cpos+length(newblaster);
   move(ptr(seg(p^),ofs(p^)+cpos)^,
        ptr(seg(p^),ofs(p^)+(cpos+length(initstr)))^,
        size-cpos);

   for dummy := 1 to length(initstr) do       {Neuen Eintrag einfgen}
   begin
     mem[seg(p^):ofs(p^)+cpos+(dummy-1)] := ord(initstr[dummy]);
   end;
   size := size + length(initstr);
end;















{============================== Menu controlling ==========================}


Procedure Control_Mainmenu;
begin

      {Handle keypresses}

    if keyboardmode then
    begin
      if ((key = #80) or (key = #77) and (sys_key = true)) then
      begin
       unselectitem(mselect);
       if mselect >= 18 then
       begin
        Button(13,21,'Advanced Options',false);
        Button(34,21,'Test Settings',false);
        Button(52,21,'Save and quit',false);
       end;
       if mselect < 20 then inc(mselect);
       if (mselect = 10) and (cfg.mpu401 = 0) then mselect := 12;
       if (mselect = 14) and (cdoff = true) then mselect := 18;
       selectitem(mselect);
      end;

      if ((key = #72) or (key = #75)) and (sys_key = true) then
      begin
       unselectitem(mselect);
       if mselect >= 18 then
       begin
        Button(13,21,'Advanced Options',false);
        Button(34,21,'Test Settings',false);
        Button(52,21,'Save and quit',false);
       end;
       if mselect > 1 then dec(mselect);
       if (mselect = 11) and (cfg.mpu401 = 0) then mselect := 9;
       if (mselect = 17) and (cdoff = true) then mselect := 13;
       selectitem(mselect);
      end;
    end;


   {   if (key = 'D') then
      begin
        assign(f,'MAIN.SCR');
        rewrite(f,1);
        blockwrite(f,ptr(segB800,0)^,4000);
        close(f);
      end;   }



      {Checkboxes}
      if ((mouse.b = 1) and (((xp = 64) or (xp = 28)) and (yp = 11))) or
         ((keyboardmode = true) and ((mselect = 4) or (mselect = 8)) and ((key = #32) or (key = #13)))  then
      begin
         mouse_hide;
        if cfg.initmode = 0 then
        begin
         putchar(28,11,' ',15,1);
         putchar(64,11,'x',15,1);
         cfg.initmode := 1;
        end
        else
        begin
         putchar(28,11,'x',15,1);
         putchar(64,11,' ',15,1);
         cfg.initmode := 0;
        end;
          mouse_show;
        Wait_for_Mousebutton;
      end;

       if ((mouse.b = 1) and (xp = 24) and (yp = 15)) or
        ((keyboardmode = true) and ((mselect = 9) and
        ((key = #32) or (key = #13))))  then
       begin
         mouse_hide;
        if cfg.mpu401 = 0 then
        begin
         putchar(24,15,'x',14,1);
         cfg.mpu401 := 1;
         fastwrite(9,16,15,1,'Address:');
         fastwrite(9,17,15,1,'Interrupt:');
         cfg.MPUBASE     := $330; {default MPU401 Port}
         cfg.MPUIRQ      := $9;   {default MPU401 IRQ}
         MAPcfgtoText;
         Drawselector(21,16,MPU_Port[mputext.port]);
         Drawselector(21,17,MPU_IRQ[mputext.irq]);
        end
        else
        begin
         putchar(24,15,' ',15,1);
         cfg.mpu401 := 0;
         delchars(9,16,30);
         delchars(9,17,30);
        end;
          mouse_show;
        Wait_for_Mousebutton;
       end;


     if ((mouse.b = 1) and (xp = 26) and (yp = 19)) or
        ((keyboardmode = true) and
        ((mselect = 12) and ((key = #32) or (key = #13))))  then
     {Gameport enable/disable}
      begin
         mouse_hide;
        if cfg.gpen = 0 then
        begin
         putchar(26,19,'x',14,1);
         cfg.gpen := 1;
        end
        else
        begin
         putchar(26,19,' ',14,1);
         cfg.gpen := 0;
        end;
          mouse_show;
        Wait_for_Mousebutton;
      end;

     if ((mouse.b = 1) and (xp = 67) and (yp = 15)) or
        ((keyboardmode = true) and
        ((mselect = 13) and ((key = #32) or (key = #13))))  then
     {CD-ROM enable/disable}
     begin
       mouse_hide;
      if not cdoff then
      begin
        cdoff := true;
        putchar(67,15,' ',15,1);
        delchars(44,16,30);
        delchars(44,17,30);
        delchars(44,18,30);
        delchars(44,19,30);
        cfg.CDTYPE  := $FF; {CD-ROM disabled}
        cfg.CDBASE  := $340;
        cfg.CDIRQ   := $FF;
        cfg.CDDMA   := 3;
      end
      else
      begin
        cdoff := false;
        cfg.CDTYPE := IDE;
        cfg.CDBASE := $340;
        cfg.CDDMA := 3;
        cfg.CDIRQ := 9;
        MapCFGtoText;
        putchar(67,15,'x',14,1);
        fastwrite(44,16,15,1,'Type:');
        fastwrite(44,17,15,1,'Address:');
        fastwrite(44,18,15,1,'Interrupt:');
        fastwrite(44,19,15,1,'DMA:');
        Drawselector(56,16,CD_TYP[cdtext.typ]);
        Drawselector(56,17,CD_PORT[cdtext.port]);
        Drawselector(56,18,CD_IRQ[cdtext.irq]);
        Drawselector(56,19,CD_DMA[cdtext.dma]);
      end;
        mouse_show;
      Wait_for_Mousebutton;
     end;

      {Handle selectors}

      {SB config}

      if ((mouse.b = 1) and (yp = 6) and ((xp = 30) or (xp = 31))) or
         ((keyboardmode = true) and ((mselect = 1) and
         ((key = '+') or (key = #32) or (key = #13)))) then
      {      {SB Port}
      begin
        if cfg.sbbase = $220 then
           cfg.sbbase := $240
        else
           cfg.sbbase := $220;
        MapCFGtoText;
         mouse_hide;
        Drawselector(21,6,SB_Port[sbtext.port]);
          mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and ((xp = 30) and (yp = 7))) or
         ((keyboardmode = true) and
         ((mselect = 2) and ((key = '+') or (key = #32) or (key = #13)))) then
      {Increase SB IRQ}
      begin
        case cfg.sbirq of
          5: cfg.sbirq := 7;
          7: cfg.sbirq := 10;
         10: cfg.sbirq := $FF;
         $FF: cfg.sbirq := 5;
        end;
        MapCFGtoText;
         mouse_hide;
        Drawselector(21,7,SB_IRQ[sbtext.irq]);
          mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and (xp = 31 ) and (yp = 7)) or
         ((keyboardmode = true) and ((mselect = 2) and (key = '-'))) then
      {Decrease SB IRQ}
      begin
        case cfg.sbirq of
          5: cfg.sbirq := $FF;
          7: cfg.sbirq := 5;
         10: cfg.sbirq := 7;
         $FF: cfg.sbirq := 10;
        end;
        MapCFGtoText;
         mouse_hide;
        Drawselector(21,7,SB_IRQ[sbtext.irq]);
          mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and (xp = 30 ) and (yp = 8)) or
         ((keyboardmode = true) and
         ((mselect = 3) and ((key = '+') or (key = #32) or (key = #13))))  then
      {Increase SB DMA}
      begin
        case cfg.sbdma of
          0: cfg.sbdma := 1;
          1: cfg.sbdma := 3;
          3: cfg.sbdma := $FF;
         $FF: cfg.sbdma := 0;
        end;
         MapCFGtoText;
         mouse_hide;
        Drawselector(21,8,SB_DMA[sbtext.dma]);
          mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and (xp = 31) and (yp = 8) ) or
         ((keyboardmode = true) and ((mselect = 3) and (key = '-'))) then
      {Decrease SB DMA}
      begin
        case cfg.sbdma of
          0: cfg.sbdma := $FF;
          1: cfg.sbdma := 0;
          3: cfg.sbdma := 1;
         $FF: cfg.sbdma := 3;
        end;
         MapCFGtoText;
         mouse_hide;
         Drawselector(21,8,SB_DMA[sbtext.dma]);
         mouse_show;
         Wait_for_Mousebutton;
      end;

      {WSS config}

      if ((mouse.b = 1) and (xp = 67 ) and (yp = 6)) or
         ((keyboardmode = true) and
         ((mselect = 5) and ((key = '+') or (key = #32) or (key = #13)))) then
      {increase WSS Port}
      begin
        case cfg.wssbase of
         $F40: cfg.wssbase := $530;
         $E80: cfg.wssbase := $F40;
         $604: cfg.wssbase := $E80;
         $530: cfg.wssbase := $604;

        end;
        MapCFGtoText;
        mouse_hide;
        Drawselector(58,6,WSS_Port[wsstext.port]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 68 ) and (yp = 6)) or
         ((keyboardmode = true) and ((mselect = 5) and (key = '-'))) then
      {decrease WSS Port}
      begin
        case cfg.wssbase of
         $530: cfg.wssbase := $F40;
         $F40: cfg.wssbase := $E80;
         $E80: cfg.wssbase := $604;
         $604: cfg.wssbase := $530;
        end;
        MapCFGtoText;
        mouse_hide;
        Drawselector(58,6,WSS_Port[wsstext.port]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

     if ((mouse.b = 1) and(xp = 67 ) and (yp = 7)) or
        ((keyboardmode = true) and
        ((mselect = 6) and ((key = '+') or (key = #32) or (key = #13)))) then
      {increase WSS IRQ}
      begin
        case cfg.wssirq of
         7: cfg.wssirq := 9;
         9: cfg.wssirq := 10;
         10: cfg.wssirq := 11;
         11: cfg.wssirq := $FF;
         $FF: cfg.wssirq := 7;
        end;

        MapCFGtoText;
        mouse_hide;
        Drawselector(58,7,WSS_IRQ[wsstext.irq]);
        mouse_show;
        Wait_for_Mousebutton;
      end;


      if ((mouse.b = 1) and(xp = 68 ) and (yp = 7)) or
         ((keyboardmode = true) and ((mselect = 6) and (key = '-'))) then
      {decrease WSS IRQ}
      begin
        case cfg.wssirq of
         $FF: cfg.wssirq := 11;
         11: cfg.wssirq := 10;
         10: cfg.wssirq := 9;
          9: cfg.wssirq := 7;
          7: cfg.wssirq := $FF;
        end;

        MapCFGtoText;
        mouse_hide;
        Drawselector(58,7,WSS_IRQ[wsstext.irq]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 67 ) and (yp = 8)) or
         ((keyboardmode = true) and
         ((mselect = 7) and ((key = '+') or (key = #32) or (key = #13)))) then
      {increase WSS DMA 1}
      begin
        case cfg.wssdma of
         0: cfg.wssdma := 1;
         1: cfg.wssdma := 3;
         3: cfg.wssdma := $FF;
         $FF: cfg.wssdma := 0;
        end;

        MapCFGtoText;
        mouse_hide;
        Drawselector(58,8,WSS_DMA[wsstext.dma]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 68 ) and (yp = 8)) or
         ((keyboardmode = true) and ((mselect = 7) and (key = '-'))) then

      {decrease WSS DMA 1}
      begin
        case cfg.wssdma of
         $FF: cfg.wssdma := 3;
         3: cfg.wssdma := 1;
         1: cfg.wssdma := 0;
         0: cfg.wssdma := $FF;
        end;

        MapCFGtoText;
         mouse_hide;
        Drawselector(58,8,WSS_DMA[wsstext.dma]);
          mouse_show;
        Wait_for_Mousebutton;
      end;

      {MPU config}

      if ((mouse.b = 1) and((xp = 30)  and (yp = 16))) or
         ((keyboardmode = true) and
         ((mselect = 10) and ((key = '+') or (key = #32) or (key = #13)))) then

      {increase MPU port}
      begin
       if cfg.mpu401 = 1 then
       begin
        if cfg.mpubase < $330 then inc(cfg.mpubase,$10) else cfg.mpubase := $300;
        MapCFGtoText;
         mouse_hide;
        Drawselector(21,16,MPU_port[mputext.port]);
          mouse_show;
        Wait_for_Mousebutton;
       end;
      end;

      if ((mouse.b = 1) and((xp = 31)  and (yp = 16))) or
         ((keyboardmode = true) and ((mselect = 10) and (key = '-'))) then
      {decrease MPU port}
      begin
       if cfg.mpu401 = 1 then
       begin
        if cfg.mpubase > $300 then dec(cfg.mpubase,$10) else cfg.mpubase := $330;
        MapCFGtoText;
         mouse_hide;
        Drawselector(21,16,MPU_port[mputext.port]);
          mouse_show;
        Wait_for_Mousebutton;
       end;
      end;

      if ((mouse.b = 1) and(xp = 30 ) and (yp = 17)) or
         ((keyboardmode = true) and ((mselect = 11) and
         ((key = '+') or (key = #32) or (key = #13)))) then
      {increase MPU IRQ}
      begin
       if cfg.mpu401 = 1 then
       begin
        case cfg.mpuirq of
         5: cfg.mpuirq := 7;
         7: cfg.mpuirq := 9;
         9: cfg.mpuirq := 10;
         10: cfg.mpuirq := 5;
        end;

        MapCFGtoText;
         mouse_hide;
        Drawselector(21,17,MPU_irq[mputext.irq]);
          mouse_show;
        Wait_for_Mousebutton;
       end;
      end;

      if ((mouse.b = 1) and(xp = 31 ) and (yp = 17)) or
         ((keyboardmode = true) and ((mselect = 11) and (key = '-'))) then
      {decrease MPU IRQ}
      begin
       if cfg.mpu401 = 1 then
       begin
        case cfg.mpuirq of
         10: cfg.mpuirq := 9;
         9: cfg.mpuirq := 7;
         7: cfg.mpuirq := 5;
         5: cfg.mpuirq := 10;
        end;

        MapCFGtoText;
         mouse_hide;
        Drawselector(21,17,MPU_irq[mputext.irq]);
          mouse_show;
        Wait_for_Mousebutton;
       end;
      end;

      {CD-ROM config}

     if ((mouse.b = 1) and(xp = 65 ) and (yp = 16)) or
        ((keyboardmode = true) and
        ((mselect = 14) and ((key = '+') or (key = #32) or (key = #13)))) then

      {increase cd-type}
     begin
       if cdoff = false then
       begin
         if cfg.cdtype < 4 then inc(cfg.cdtype) else cfg.cdtype := 1;
         MapCFGtoText;
          mouse_hide;
         Drawselector(56,16,CD_TYP[cfg.cdtype]);
           mouse_show;
         Wait_for_Mousebutton;
       end;
      end;

     if ((mouse.b = 1) and(xp = 66 ) and (yp = 16)) or
        ((keyboardmode = true) and ((mselect = 14) and (key = '-'))) then

      {decrease cd-type}
     begin
       if cdoff = false then
       begin
         if cfg.cdtype > 1 then dec(cfg.cdtype) else cfg.cdtype := 4;
         MapCFGtoText;
          mouse_hide;
         Drawselector(56,16,CD_TYP[cfg.cdtype]);
           mouse_show;
         Wait_for_Mousebutton;
       end;
      end;

     if ((mouse.b = 1) and(xp = 65 ) and (yp = 17)) or
        ((keyboardmode = true) and ((mselect = 15) and
        ((key = '+') or (key = #32) or (key = #13)))) then
      {increase CD-Port}
      begin
        if cdoff = false then
        begin
         case cfg.cdbase of
         $320: cfg.cdbase := $330;
         $330: cfg.cdbase := $340;
         $340: cfg.cdbase := $360;
         $360: cfg.cdbase := $320;
         end;
         MapCFGtoText;
          mouse_hide;
         Drawselector(56,17,CD_PORT[cdtext.port]);
           mouse_show;
         Wait_for_Mousebutton;
        end;
     end;

      if ((mouse.b = 1) and(xp = 66 ) and (yp = 17)) or
         ((keyboardmode = true) and ((mselect = 15) and (key = '-'))) then

      {decrease CD-Port}
      begin
        if cdoff = false then
        begin

        case cfg.cdbase of
         $360: cfg.cdbase := $340;
         $340: cfg.cdbase := $330;
         $330: cfg.cdbase := $320;
         $320: cfg.cdbase := $360;
        end;

        MapCFGtoText;
         mouse_hide;
        Drawselector(56,17,CD_PORT[cdtext.port]);
          mouse_show;
        Wait_for_Mousebutton;
      end;
     end;



      if ((mouse.b = 1) and(xp = 65 ) and (yp = 18)) or
         ((keyboardmode = true) and ((mselect = 16) and
         ((key = '+') or (key = #32) or (key = #13)))) then

      {increase CD IRQ}
      begin
        if cdoff = false then
        begin

        case cfg.cdirq of
         5: cfg.cdirq := 7;
         7: cfg.cdirq := 9;
         9: cfg.cdirq := 10;
         10: cfg.cdirq := 11;
         11: cfg.cdirq := $FF;
         $FF: cfg.cdirq := 5;
        end;

        MapCFGtoText;
         mouse_hide;
        Drawselector(56,18,CD_IRQ[cdtext.irq]);
          mouse_show;
        Wait_for_Mousebutton;
      end;
     end;

      if ((mouse.b = 1) and(xp = 66 ) and (yp = 18)) or
         ((keyboardmode = true) and ((mselect = 16) and (key = '-'))) then

      {decrease CD IRQ}
      begin
        if cdoff = false then
        begin

        case cfg.cdirq of
         $FF: cfg.cdirq := 11;
         11: cfg.cdirq := 10;
         10: cfg.cdirq := 9;
         9: cfg.cdirq := 7;
         7: cfg.cdirq := 5;
         5: cfg.cdirq := $FF;
        end;

        MapCFGtoText;
         mouse_hide;
        Drawselector(56,18,CD_IRQ[cdtext.irq]);
          mouse_show;
        Wait_for_Mousebutton;
      end;
     end;

      if ((mouse.b = 1) and(xp = 65 ) and (yp = 19)) or
         ((keyboardmode = true) and ((mselect = 17) and
         ((key = '+') or (key = #32) or (key = #13)))) then

      {increase CD DMA}
      begin
        if cdoff = false then
        begin

        case cfg.cddma of
         0: cfg.cddma := 1;
         1: cfg.cddma := 3;
         3: cfg.cddma := $FF;
         $FF: cfg.cddma := 0;
        end;

        MapCFGtoText;
         mouse_hide;
        Drawselector(56,19,CD_DMA[cdtext.dma]);
          mouse_show;
        Wait_for_Mousebutton;
      end;
     end;

      if ((mouse.b = 1) and(xp = 66 ) and (yp = 19)) or
         ((keyboardmode = true) and ((mselect = 17) and (key = '-'))) then
      {decrease CD DMA}
      begin
        if cdoff = false then
        begin

        case cfg.cddma of
         $FF: cfg.cddma := 3;
         3: cfg.cddma := 1;
         1: cfg.cddma := 0;
         0: cfg.cddma := $FF;
        end;

        MapCFGtoText;
        mouse_hide;
        Drawselector(56,19,CD_DMA[cdtext.dma]);
        mouse_show;
        Wait_for_Mousebutton;
      end;
     end;




      {Handle Buttons:}

      {Advanced Options}
      if ((upcase(key) = 'A') or (key = #30) and (sys_key = false)) or
         ((mouse.b = 1) and ((xp >= 13) and (xp <= 28) and (yp = 21))) or
         ((mselect = 18) and ((key = #32) or (key = #13))) then
      begin
        mouse_hide;
        Button(13,21,'Advanced Options',true);
        mouse_show;
        Wait_for_Mousebutton;
        mouse_hide;
        aselect := 1;
        menu := 2;
        Draw_Advanced_Menu;
        mouse_show;
      end;

      {Test Settings}
      if ((upcase(key) = 'T') or (key = #20) and (sys_key = false)) or
         ((mouse.b = 1) and ((xp >= 34) and (xp <= 46) and (yp = 21))) or
         ((mselect = 19) and ((key = #32) or (key = #13))) then
      begin
        mouse_hide;
        Button(34,21,'Test Settings',true);
        mouse_show;
        Wait_for_Mousebutton;
        TestSettings;
      end;

      {Quit}
      if ((upcase(key) = 'S') or (upcase(key) = 'Q') or (key = #16) and (sys_key = false)) or
         ((mouse.b = 1) and ((xp >= 52) and (xp <= 64) and (yp = 21))) or
         ((mselect = 20) and ((key = #32) or (key = #13))) then
      begin
        mouse_hide;
        Button(52,21,'Save and quit',true);
        mouse_show;
        Wait_for_Mousebutton;
        quit := true;
      end;
end;



Procedure Control_Advancedmenu;
begin


    if keyboardmode then
    begin

      if (key = #80) or (key = #77) and (sys_key = true) then
      begin
       unselectitem(aselect);
       if apage = 0 then
       begin
         if aselect < 21 then inc(aselect);
         if aselect > 19 then
         begin
          Button(9,22,' Next ',false);
          Button(44,22,' Main menu ',false);
         end;
       end
       else
       begin
         if aselect < 8 then inc(aselect);
         if aselect > 6 then
         begin
          Button(9,22,' Back ',false);
          Button(44,22,' Main menu ',false);
         end;
       end;
       selectitem(aselect);
     end;

      if (key = #72) or (key = #75) and (sys_key =  true) then
      begin
       if apage = 0 then
       begin
        if aselect > 19 then
        begin
         Button(9,22,' Next ',false);
         Button(44,22,' Main menu ',false);
        end;
       end
       else
       begin
        if aselect > 6 then
        begin
         Button(9,22,' Back ',true);
         Button(44,22,' Main menu ',false);
        end;
       end;
       unselectitem(aselect);
       if aselect > 1 then dec(aselect);
       selectitem(aselect);
     end;

    end;

{      if (key = 'D') then
      begin
        assign(f,'ADV.SCR');
        rewrite(f,1);
        blockwrite(f,ptr(segB800,0)^,4000);
        close(f);
      end;}


      {Handle Buttons:}

      {Back to main menu}

       if(((upcase(key) = 'M') and (sys_key = false)) or (key = #24) or (key = #27)) or
         ((mouse.b = 1) and ((xp >= 44) and (xp <= 55) and (yp = 22))) or
         ((apage = 0) and (aselect = 21) and ((key = #32) or (key = #13)) or
         ((apage = 1) and (aselect = 8) and ((key = #32) or (key = #13)))) then
      begin
        mouse_hide;
        Button(44,22,' Main menu ',true);
        mouse_show;
        Wait_for_Mousebutton;
        mouse_hide;
        key := #0;
        while iskeypressed do getkey;
        menu := 1;
        apage := 0;
        Draw_Main_Menu;
        mouse_show;
      end;

      if apage = 0 then
      begin

      if (((upcase(key) = 'N') and (sys_key = false)) or (key = #24) or (key = #27)) or
         ((mouse.b = 1) and ((xp >= 9) and (xp <= 15) and (yp = 22))) or
         ((aselect = 20) and ((key = #32) or (key = #13))) then
      begin
        mouse_hide;
        Button(9,22,' Next ',true);
        mouse_show;
        Wait_for_Mousebutton;
        mouse_hide;
        key := #0;
        while iskeypressed do getkey;
        apage := 1;
        aselect := 1;
        Draw_Advanced_Menu;
        mouse_show;
      end;

      {Selectors}

      if ((mouse.b = 1) and ((xp = 53 ) or (xp = 54)) and (yp = 6)) or
         ((keyboardmode = true) and
         ((aselect = 1) and ((key = '+') or (key = #32) or (key = #13))))  then
      begin
        if cfg.cfix = 1 then cfg.cfix := 0 else cfg.cfix := 1;
        mouse_hide;
        Drawselector(44,6,CFIX[cfg.cfix]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 7)) or
         ((keyboardmode = true) and
         ((aselect = 2) and ((key = '+') or (key = '-') or
                             (key = #32) or (key = #13))))  then
      begin
        if cfg.opl = 4 then cfg.opl := 3 else cfg.opl := 4;
        mouse_hide;
        Drawselector(44,7,FM_chip[cfg.opl]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 8)) or
         ((keyboardmode = true) and
         ((aselect = 3) and ((key = '+') or (key = '-') or
                             (key = #32) or (key = #13))))  then
      begin
        if cfg.fmclk = 3 then cfg.fmclk := 2 else cfg.fmclk := 3;
         mouse_hide;
        Drawselector(44,8,FM_CLK[cfg.fmclk]);
          mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 53 ) and (yp = 9)) or
         ((keyboardmode = true) and
         ((aselect = 4) and ((key = '+') or
          (key = #32) or (key = #13)))) then
      begin
        if WSSFreq.freq < 13 then
        begin
         inc(WSSFreq.freq);
        end
        else
        begin
         WSSFreq.freq := 0;
        end;
         mouse_hide;
        Drawselector(44,9,Frequency[WSSFreq.freq].rate);
          mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 54 ) and (yp = 9)) or
         ((keyboardmode = true) and
         ((aselect = 4) and (key = '-'))) then
      begin
        if WSSFreq.freq > 0 then
        begin
         dec(WSSFreq.freq);
        end
        else
        begin
         WSSFreq.freq := 13;
        end;
         mouse_hide;
        Drawselector(44,9,Frequency[WSSFreq.freq].rate);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 64 ) or (xp = 65)) and (yp = 9)) or
         ((keyboardmode = true) and
          ((aselect = 5) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if WSSFreq.bits = 1 then WSSFreq.bits := 0 else WSSFreq.bits := 1;
         mouse_hide;
        Drawselector(55,9,Bits[WSSFreq.bits]);
         mouse_show;
        Wait_for_Mousebutton;
      end;


      if ((mouse.b = 1) and((xp = 75 ) or (xp = 76)) and (yp = 9)) or
         ((keyboardmode = true) and
           ((aselect = 6) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if WSSFreq.chan = 1 then WSSFreq.chan := 0 else WSSFreq.chan := 1;
         mouse_hide;
        Drawselector(66,9,MS[WSSFreq.chan]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 53 ) and (yp = 10)) or
         ((keyboardmode = true) and
         ((aselect = 7) and ((key = '+') or
          (key = #32) or (key = #13)))) then
      begin
         if SBfreq.freq = 13 then SBfreq.freq := 0 else inc(SBfreq.freq);

         if (cfg.fmap = 1) and (Frequency[SBFreq.freq].xtal = 1) then
         begin
           repeat;
            if SBfreq.freq = 13 then SBfreq.freq := 0 else inc(SBfreq.freq);
           until Frequency[SBFreq.freq].xtal = 2;
         end;

         mouse_hide;
        Drawselector(44,10,Frequency[SBFreq.freq].rate);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 54 ) and (yp = 10)) or
         ((keyboardmode = true) and
          ((aselect = 7) and (key = '-'))) then
      begin
        if SBFreq.freq = 0 then SBfreq.freq := 13 else dec(SBfreq.freq);

        if (cfg.fmap = 1) and (Frequency[SBFreq.freq].xtal = 1) then
        begin
          repeat;
           if SBFreq.freq = 0 then SBfreq.freq := 13 else dec(SBfreq.freq);
          until Frequency[SBFreq.freq].xtal = 2;
        end;

         mouse_hide;
        Drawselector(44,10,Frequency[SBFreq.freq].rate);
         mouse_show;
        Wait_for_Mousebutton;
      end;



      if ((mouse.b = 1) and((xp = 64 ) or (xp = 65)) and (yp = 10)) or
         ((keyboardmode = true) and
          ((aselect = 8) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if SBFreq.bits = 1 then SBFreq.bits := 0 else SBFreq.bits := 1;
         mouse_hide;
        Drawselector(55,10,Bits[SBFreq.bits]);
         mouse_show;
        Wait_for_Mousebutton;
      end;


      if ((mouse.b = 1) and((xp = 75) or (xp = 76)) and (yp = 10)) or
         ((keyboardmode = true) and
          ((aselect = 9) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if SBFreq.chan = 1 then SBFreq.chan := 0 else SBFreq.chan := 1;
         mouse_hide;
        Drawselector(66,10,MS[SBFreq.chan]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 11)) or
         ((keyboardmode = true) and
         ((aselect = 10) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
            begin
        if cfg.fmap = 1 then cfg.fmap := 0 else cfg.fmap := 1;
         mouse_hide;
        Drawselector(44,11,FMAP[cfg.fmap]);

        if (cfg.fmap = 1) and (Frequency[SBFreq.freq].xtal = 1) then
        begin
         repeat;
          if SBfreq.freq = 0 then SBfreq.freq := 13 else dec(SBfreq.freq);
         until Frequency[SBFreq.freq].xtal = 2;
         Drawselector(44,10,Frequency[SBFreq.freq].rate);
        end;

         mouse_show;
        Wait_for_Mousebutton;
      end;


      if ((mouse.b = 1) and(xp = 53 ) and (yp = 12)) or
         ((keyboardmode = true) and
         ((aselect = 11) and ((key = '+') or
         (key = #32) or (key = #13))))  then
      begin
        if cfg.sbver < 4 then
        begin
         inc(cfg.sbver);
        end
        else
        begin
         cfg.sbver := 1;
        end;
         mouse_hide;
        Drawselector(44,12,DSP[cfg.sbver]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and (xp = 54 ) and (yp = 12)) or
         ((keyboardmode = true) and
         ((aselect = 11) and (key = '-'))) then
      begin
        if cfg.sbver > 1 then
        begin
         dec(cfg.sbver);
        end
        else
        begin
         cfg.sbver := 4;
        end;
         mouse_hide;
        Drawselector(44,12,DSP[cfg.sbver]);
         mouse_show;
        Wait_for_Mousebutton;
      end;


      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 13)) or
         ((keyboardmode = true) and
          ((aselect = 12) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.autovol = 1 then cfg.autovol := 0 else cfg.autovol := 1;
         mouse_hide;
         Drawselector(44,13,ONOFF[cfg.autovol]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 14)) or
         ((keyboardmode = true) and
          ((aselect = 13) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.adpcm = 1 then cfg.adpcm := 0 else cfg.adpcm := 1;
        mouse_hide;
        Drawselector(44,14,ONOFF[cfg.adpcm]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 15)) or
         ((keyboardmode = true) and
          ((aselect = 14) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.fifo = 1 then cfg.fifo := 0 else cfg.fifo := 1;
         mouse_hide;
        Drawselector(44,15,ONOFF[cfg.fifo]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and(xp = 53 ) or (xp = 54)) and (yp = 16) or
         ((keyboardmode = true) and
         ((aselect = 15) and ((key = '+') or (key = '-') or
          (key = #32) or (key = #13))))  then
      begin
        if cfg.gpmode = 1 then cfg.gpmode := 0 else cfg.gpmode := 1;
         mouse_hide;
        Drawselector(44,16,GPMODE[cfg.gpmode]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 17)) or
         ((keyboardmode = true) and
          ((aselect = 16) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.outmx = 1 then cfg.outmx := 0 else cfg.outmx := 1;
         mouse_hide;
        Drawselector(44,17,OUTMX[cfg.outmx]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 18)) or
         ((keyboardmode = true) and
          ( (aselect = 17) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.gpout = 1 then cfg.gpout := 0 else cfg.gpout := 1;
         mouse_hide;
        Drawselector(44,18,ONOFF[cfg.gpout]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

     if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 19)) or
         ((keyboardmode = true) and
          ((aselect = 18) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
         if cfg.sbmix = 1 then cfg.sbmix := 0 else cfg.sbmix := 1;
         mouse_hide;
         Drawselector(44,19,ONOFF[cfg.sbmix]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

     if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 20)) or
         ((keyboardmode = true) and
          ((aselect = 19) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
         if cfg.shprotect = 1 then cfg.shprotect := 0 else cfg.shprotect := 1;
         mouse_hide;
         Drawselector(44,20,ONOFF[cfg.shprotect]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

     end
     else   {Page 1}
     begin

      if ((upcase(key) = 'B') or (key = #24) or (key = #27)) or
         ((mouse.b = 1) and ((xp >= 9) and (xp <= 15) and (yp = 22))) or
         ((aselect = 7) and ((key = #32) or (key = #13))) then
      begin
        mouse_hide;
        Button(9,22,' Back ',true);
        mouse_show;
        Wait_for_Mousebutton;
        mouse_hide;
        key := #0;
        while iskeypressed do getkey;
        apage := 0;
        aselect := 1;
        Draw_Advanced_Menu;
        mouse_show;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 6)) or
         ((keyboardmode = true) and
          ((aselect = 1) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.attn = 1 then cfg.attn := 0 else cfg.attn := 1;
        mouse_hide;
        Drawselector(44,6,ONOFF[cfg.attn]);
        mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 7)) or
         ((keyboardmode = true) and
          ((aselect = 2) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.dmawd = 1 then cfg.dmawd := 0 else cfg.dmawd := 1;
         mouse_hide;
         Drawselector(44,7,ONOFF[cfg.dmawd]);
         mouse_show;
         Wait_for_Mousebutton;
      end;

       if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 8)) or
         ((keyboardmode = true) and
          ((aselect = 3) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
         if cfg.wave = 1 then cfg.wave := 0 else cfg.wave := 1;
         mouse_hide;
         Drawselector(44,8,ONOFF[cfg.wave]);
         mouse_show;
         Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 9)) or
         ((keyboardmode = true) and
          ((aselect = 4) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
         if cfg.silence = 1 then cfg.silence := 0 else cfg.silence := 1;
         mouse_hide;
         Drawselector(44,9,ONOFF[cfg.silence]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

      if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 10)) or
         ((keyboardmode = true) and
          ((aselect = 5) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.timeout = 1 then cfg.timeout := 0 else cfg.timeout := 1;
         mouse_hide;
         Drawselector(44,10,ONOFF[cfg.timeout]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

       if ((mouse.b = 1) and((xp = 53 ) or (xp = 54)) and (yp = 11)) or
         ((keyboardmode = true) and
          ((aselect = 6) and ((key = '+') or (key = '-') or
           (key = #32) or (key = #13))))  then
      begin
        if cfg.access = 1 then cfg.access := 0 else cfg.access := 1;
         mouse_hide;
         Drawselector(44,11,ONOFF[cfg.access]);
         mouse_show;
        Wait_for_Mousebutton;
      end;

   end;


end;



Procedure UpdateAutoexec;
begin
 writeln('');
 write('Updating AUTOEXEC.BAT....');
 autoexec := copy(GetEnv('COMSPEC'),1,pos('\',GetEnv('COMSPEC')))+autoexec;
 backup := copy(autoexec,1,pos('.',autoexec));
 backup := backup + 'BAK';

 if not fileexist('929INIT.EXE') then
 begin
  writeln('');
  writeln('ERROR! 929INIT.EXE not found!');
  writeln('');
  halt(1);
 end;

 initstr  := FExpand('')+'929INIT.EXE /INIT /Q'+#13+#10;
 newBlaster := 'SET BLASTER=A'+removezeros(hexw(cfg.sbbase))+
                          ' I'+removezeros(hexb(cfg.sbirq))+
                          ' D'+removezeros(hexb(cfg.sbdma));

 if cfg.mpu401 > 0 then
 begin
   newblaster := newblaster + ' P'+ removezeros(hexw(cfg.mpubase));
 end;
 case cfg.SBver of
   1: newblaster := newblaster + ' T1';
   2: newblaster := newblaster + ' T2';
   3: newblaster := newblaster + ' T4';
   4: newblaster := newblaster + ' T6';
 end;
 newblaster := newblaster +#13+#10;
 Load_to_Mem;
 Update_Blaster;
 if not found then
 begin
  Create_Blaster;
 end;
 Find_INIT929;
 if not found then
 begin
  Create_INIT;
 end;
 Write_mem_back;
 writeln('OK');
end;

{====================================== Execute init929 ====================}

Procedure DosShell(command : string);
var
 OldHeapEnd,
 NewHeapEnd     : Word;
begin
 Error:=0;
 If MemAvail < $1000 then Error := 8;

 If Error = 0 then
 begin
   NewHeapEnd:=Seg(HeapPtr^)-PrefixSeg;
   OldHeapEnd:=Seg(HeapEnd^)-PrefixSeg;
   asm
    mov ah,4Ah
    mov bx,NewHeapEnd
    mov es,PrefixSeg
    Int 21h
    jnc @EXIT
    mov Error,ax
    @EXIT:
   end;

  If Error=0 then
  begin
   SwapVectors;
   Exec(GetEnv('COMSPEC'),command);
   SwapVectors;
    asm
     mov ah,4Ah
     mov bx,OldHeapEnd
     mov es,PrefixSeg
     Int 21h
     jnc @EXIT
     mov Error,ax
     @EXIT:
    end;
  end;
 end;
end;


Procedure Reinit;
begin
 writeln('');
 writeln('New settings are applied and the sound card is reinitialized.');
 DosShell('/C 929INIT.EXE /INIT /Q /N10');
 if error <> 0 then
 begin
   writeln('');
   writeln('Error ('+addzero(error)+') during execution of 929INIT.EXE');
   writeln('');
   halt(1);
 end;
end;







{====================================== Main program ========================}

begin
asm
 mov ax,03h
 int 10h
end;
writeln(title);
writeln('');

if not fileexist('929INIT.EXE') then
begin
  writeln('File 929INIT.EXE not found!');
  writeln('');
  halt(1);
end;

write('Checking hardware.... ');

if not Detect929 then
begin

 SetInitValues;  {Set default values and try again}

 if not Detect929 then
 begin
   writeln('');
   writeln('OPTi 82c929 sound controller chip not found!');
   writeln('');
   halt(1);
 end;

end;

if not DetectAD1848 then
begin
  writeln('');
  writeln('WSS codec not found! ');
  writeln('');
  halt(1);
end;

if (mouse_there = false) or (mouse_init = false) or (uppercase(paramstr(1)) = '/K') then
begin
 keyboardmode := true;
 mouse_there := false;
end
else
begin
 keyboardmode := false;
end;


if maxavail < 4000 then
begin
 writeln(' Not enough memory! ');
 writeln('');
 halt(1);
end;

 writeln('OK');


 if not fileexist(cfgfile) then
 begin
  writeln('');
  writeln('Can''t find the configuration file!');
  writeln('Creating a new file with default settings.');
  writeln('');
  writeln('Press any key to continue....');
  waitkey;
  setstandardcfg;
 end
 else
 begin
  LoadCfg;
 end;

 getmem(p,4000); {Alloc additional screen buffer}

 menu := 1;    {Main menu}
 mselect := 1;
 Draw_Main_Menu;

 mouse_show;
 quit := false;
 repeat;           {Main loop}
    if not keyboardmode then
    begin
      Mouse_Read;
      xp := (mouse.x div 8)+1;
      yp := (mouse.y div 8)+1;
    end;

    if (mouse.b = 1) or (iskeypressed = true) then
    begin
      if iskeypressed then  key := getkey;
      while iskeypressed do getkey;


      if menu = 1 then Control_Mainmenu;
      if menu = 2 then Control_Advancedmenu;
      if menu = 3 then
      begin
       mark(39,22,4);
       if ((upcase(key) = 'O') or (key = #16) or (key = #27) or
           (key = #32) or (key = #13)) or
       ((mouse.b = 1) and ((xp >= 39) and (xp <= 42) and (yp = 22))) then
       begin
         mouse_hide;
        Button(39,22,' OK ',true);
         mouse_show;
        Wait_for_Mousebutton;
         mouse_hide;
        menu := 1;
        Draw_Main_Menu;
         mouse_show;

        key := #0;
        while iskeypressed do getkey;   {clear keyboard buffer}
      end;
    end;
   end;




    if key = #27 then       {ESC pressed?}
    begin
      move(ptr(segB800,0)^,p^,4000);   {Move actual screen to buffer}
      writeto(p);                    {write operations go to buffer}
      ShadowScreen;                  {makes the screen black and white}
      window(10,7,70,17,14,1,true);
      centeredtext(10,15,'Quit without saving?');
      Button(33,13,' Yes ',false);
      Button(42,13,' No ',false);
      while iskeypressed do getkey;   {clear keyboard buffer}
       mouse_hide;
      ViewBuffer(p);               {show buffer}
      writeto(ptr(segB800,0));     {write to video mem}
      mark(33,13,5);
       mouse_show;
      aselect := 1;

     repeat;
        if not keyboardmode then
       begin
         Mouse_Read;                   {Get mouse buttons and coordinates}
         xp := (mouse.x div 8)+1;
         yp := (mouse.y div 8)+1;
       end;

       key := #0;
       if iskeypressed then key := getkey;   {register keypress}

       if (key = #77) or (key = #75) and (keyboardmode) then
       begin
         if aselect = 1 then
         begin
          Button(33,13,' Yes ',false);
          mark(42,13,4);
          aselect := 2;
         end
         else
         begin
          Button(42,13,' No ',false);
          mark(33,13,5);
          aselect := 1;
         end;
         while iskeypressed do getkey;   {clear keyboard buffer}
         key := #0;
       end;

       if ((xp >= 33) and (xp <= 37) and (yp = 13) and (mouse.b = 1) ) or
          (upcase(key) = 'Y') or ((aselect = 1) and (key = #13)) then
       begin
          mouse_hide;
         Button(33,13,' Yes ',true);
          mouse_show;
         Wait_for_Mousebutton;
          mouse_hide;
         clrscr;
         freemem(p,4000);

         halt(0);
       end;

     until (upcase(key) = 'N') or (key = #27) or ((aselect = 2) and (key = #13)) or
           ((xp >= 42) and (xp <= 45) and (mouse.b = 1));
         mouse_hide;
        Button(42,13,' No ',true);
         mouse_show;
        Wait_for_Mousebutton;
         mouse_hide;
        menu := 1;
        Draw_Main_Menu;
         mouse_show;
        key := #0;
        while iskeypressed do getkey;   {clear keyboard buffer}
    end;


 until quit;
 move(ptr(segB800,0)^,p^,4000);   {Move actual screen to buffer}
 writeto(p);                    {write operations go to buffer}
 ShadowScreen;                  {makes the screen black and white}
 window(10,7,70,17,14,1,true);
 centeredtext(10,15,'Update AUTOEXEC.BAT ?');
 Button(33,13,' Yes ',false);
 Button(42,13,' No ',false);
 while iskeypressed do getkey;   {clear keyboard buffer}
  mouse_hide;
 ViewBuffer(p);               {show buffer}
 writeto(ptr(segB800,0));     {write to video mem}
 mark(33,13,5);
  mouse_show;
 aselect := 1;

 repeat;
    Mouse_Read;                   {Get mouse buttons and coordinates}
    xp := (mouse.x div 8)+1;
    yp := (mouse.y div 8)+1;
    if iskeypressed then key := getkey;   {register keypress}

       if (key = #77) or (key = #75) then
       begin
         if aselect = 1 then
         begin
          Button(33,13,' Yes ',false);
          mark(42,13,4);
          aselect := 2;
         end
         else
         begin
          Button(42,13,' No ',false);
          mark(33,13,5);
          aselect := 1;
         end;
         key := #0;
         while iskeypressed do getkey;   {clear keyboard buffer}
       end;





   if ((xp >= 33) and (xp <= 37) and (yp = 13) and (mouse.b = 1) ) or
          (upcase(key) = 'Y') or ((aselect = 1) and (key = #13)) then
    begin
       mouse_hide;
      Button(33,13,' Yes ',true);
       mouse_show;
      Wait_for_Mousebutton;
       mouse_hide;
      clrscr;
      freemem(p,4000);
      SaveCfg;
      UpdateAutoexec;
      Reinit;         {Execute init929.exe to apply new settings}
      halt(0);
    end;


  until (upcase(key) = 'N') or (key = #27) or ((aselect = 2) and (key = #13)) or
           ((xp >= 42) and (xp <= 45) and (mouse.b = 1));
 mouse_hide;
 Button(42,13,' No ',true);
 mouse_show;
 Wait_for_Mousebutton;
 mouse_hide;
 clrscr;
 writeln('No changes were made to AUTOEXEC.BAT');
 freemem(p,4000);
 SaveCfg;
 Reinit;         {Execute init929.exe to apply new settings}
 while iskeypressed do getkey;
 cursor(true);
end.
