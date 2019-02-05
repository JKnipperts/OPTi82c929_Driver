{*****************************************************************************
   Mixer for my Low Level Driver for OPTi 82C929 Soundcards
*****************************************************************************
Version:    1.1
Date   :    01.02.2019
Author :    Jan Knipperts
*****************************************************************************}
{Changelist 0.8 - 0.9:
 Kleiner Bugfix - OPL Volume kann nun auf 100% gestezt werden
 Mauszeiger verschwindet nicht mehr, wenn Button angeklickt wird
 Nur eigene Textfunktionen, Unit CRT wird nicht mehr verwendet
 Bezeichnungen etwas angepasst
 Eingangspegel fÅr Input wÑhlbar

 0.9 - 0.9b
 Nutzt SB Pro unit

 0.9 - 0.9c
 - Komplette umgestaltung. Nutzt jetzt nur WSS und
   SB Volume wird erst am Ende gesetzt.
 - PostMix und Digital Mixing hinzugefÅgt
 - Nutzt jetzt eigene BMF-Unit fÅr FM-Sound
 - Kleiner Bugfix beim MPU-Soundcheck
 - Einige grafische Verbesserungen
 - Mousesteuerung optimiert

 1.0
 - AUX1 als Input hinzugefÅgt
 - Darstellung angepasst
 - Kleine grafische Verbesserungen und bugfixes

 1.1
 - Tastatursteuerung
 - Parameter K und ?
 - Bugfix zum Setzen von Mono/Stereo}


Program AD1848_Mixer;
uses ad1848,opti929,mpu,sbpro,opl,bmf,
     textmode,dos,misc;

type
  slider = record
   x  : byte;
  end;

  SBcfg  = record
  Base     : word;
  irq, dma : byte;
  end;

 codecvolumes = record
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



{$L SONG.OBJ}
Procedure INTRO8; external;   {includes the FM song}
{$L TEST8.OBJ}
Procedure SOUND8BIT; external;   {includes the sample}



const
     title          : string = 'MAD16 Pro Mixer v.1.1 (c) 2019 Jan Knipperts';
     footer         : string = 'F1 = Load last settings, ESC = Save and quit';
     kfooter        : string = 'Up/Down = Select; +/- = Set Volume; Space/Enter = Toggle; F,S,W = Soundcheck';
     cfgfile        : string = 'sound.cfg';

     samplesize = 27382;
          F1    = #59;
          F2    = #60;

       textcol = 15;
       headings = 14;
       background = 1;

    DmaChannel      : Array [0..3,1..3] of Byte =
    (($87,$0,$1),($83,$2,$3),($81,$2,$3),($82,$6,$7));




var
 dacl,dacr,aux1l,aux1r,aux2l,aux2r : slider;
 xp,yp                             : byte;
 cfg                               : OPTi929config;
 SBFreq,
 WSSFreq                           : Freqconfig;
 fmplaying, dacplaying             : boolean;
 fmbuffer,fmsongptr                : pointer;
 irqcalled                         : boolean;
 sb                                : sbcfg;
 index                             : word;
 timeout,SBm,dmix,keyboardmode     : boolean;
 volumes                           : codecvolumes;
 f                                 : file;
 key                               : char;
 dma,  Offset, Page                : Word;
 dl,dh                             : Byte;
 s                                 : string;
 vl,vr,input,mgain,select          : byte;
 c1,c2                             : integer;


 Procedure Prepare_AD1848_for_SB;
  {Configure the codec to a propper format and frequency for Sound Blaster compatibility}
  var dummy : byte;
  begin

     asm
      cli
     end;
        WaitForCodec;  {Just to be sure the codec is ready}

        {SetDMAMode(true); {Set codec to single DMA mode for SB}

        case sbfreq.bits of
        0:  dummy := PCM_U_8BIT;
        1:  dummy := PCM_COMPL_16BIT;
        end;

        {Set data format, frequency and mono/stereo}
        AD1848_SetOutputFormat(codec_rates[SBFreq.freq+1].freq,dummy,boolean(sbfreq.chan));

        Calibrate_AD1848;  {Recalibrate codec o new samplerate}
        WaitForCodec;  {Wait for the codec to be ready again}
     asm
      sti
     end;
   end;





function LoadSettings : Boolean;
begin
  if not fileexist(cfgfile) then
  begin
    Loadsettings := false;
  end
  else
  begin
    assign(f,cfgfile);
    reset(f,1);

    {$I-}
     blockread(f,cfg,sizeof(cfg));
     blockread(f,sbfreq,sizeof(freqconfig));
     blockread(f,wssfreq,sizeof(freqconfig));
     blockread(f,volumes,sizeof(codecvolumes));
     close(f);
    {$I+}
    if IOResult <> 0 then
    begin
      Loadsettings := false;
    end
    else
    begin
      Loadsettings := true;
      input := volumes.inp;
      mgain := volumes.micgain;
      dmix  := volumes.dmix;
    end;
  end;
end;

function SaveSettings : Boolean;
begin
  assign(f,cfgfile);
  {$I-}
   rewrite(f,1);
  {$I+}

  if IOResult <> 0 then
  begin
    Savesettings := false;
  end
  else
  begin
    volumes.inp := input;
    volumes.micgain := mgain;
    volumes.dmix    := dmix;
    {$I-}
     blockwrite(f,cfg,sizeof(cfg));
     blockwrite(f,sbfreq,sizeof(freqconfig));
     blockwrite(f,wssfreq,sizeof(freqconfig));
     blockwrite(f,volumes,sizeof(codecvolumes));
     close(f);
    {$I+}
    if IOResult <> 0 then
    begin
      Savesettings := false;
    end
    else
    begin
      Savesettings := true;
    end;
  end;
end;


Procedure Refresh_volumes;
begin
 fastwrite(51,7,headings,background,addspace(round((volumes.dacl / 31)*100)));
 fastwrite(54,7,headings,background,'%');
 fastwrite(51,8,headings,background,addspace(round((volumes.dacr / 31)*100)));
 fastwrite(54,8,headings,background,'%');
 fastwrite(51,13,headings,background,addspace(round((volumes.aux1l / 31)*100)));
 fastwrite(54,13,headings,background,'%');
 fastwrite(51,14,headings,background,addspace(round((volumes.aux1r / 31)*100)));
 fastwrite(54,14,headings,background,'%');
 fastwrite(51,19,headings,background,addspace(round((volumes.aux2l / 31)*100)));
 fastwrite(54,19,headings,background,'%');
 fastwrite(51,20,headings,background,addspace(round((volumes.aux2r / 31)*100)));
 fastwrite(54,20,headings,background,'%');
end;



Procedure Reset_Sliders;
begin
 putchar(dacl.x,7,'ƒ',textcol,background);
 putchar(dacr.x,8,'ƒ',textcol,background);
 putchar(aux1l.x,13,'ƒ',textcol,background);
 putchar(aux1r.x,14,'ƒ',textcol,background);
 putchar(aux2l.x,19,'ƒ',textcol,background);
 putchar(aux2r.x,20,'ƒ',textcol,background);

 dacl.x  := volumes.dacl+18;
 dacr.x  := volumes.dacr+18;
 aux1l.x := volumes.aux1l+18;
 aux1r.x := volumes.aux1r+18;
 aux2l.x := volumes.aux2l+18;
 aux2r.x := volumes.aux2r+18;

 putchar(dacl.x,7,'€',textcol,background);
 putchar(dacr.x,8,'€',textcol,background);
 putchar(aux1l.x,13,'€',textcol,background);
 putchar(aux1r.x,14,'€',textcol,background);
 putchar(aux2l.x,19,'€',textcol,background);
 putchar(aux2r.x,20,'€',textcol,background);
 fastwrite(69,22,15,0,addspace(round((volumes.gain / 15)*100))+'%');


 Refresh_Volumes;
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
      if select < 13 then changeattr(c,y,15,1)
      else changeattr(c,y,15,0);

    end;
  end;
 end;

 Procedure UnSelectItem(sel : byte);
 var x,y,l : byte;
 begin
  if keyboardmode then
  begin
      case sel of
         1: begin y := 7;  x := 10; l := 6; end;
         2: begin y := 8;  x := 10; l := 6; end;
         3: begin y := 13;  x := 10; l := 6; end;
         4: begin y := 14;  x := 10; l := 6; end;
         5: begin y := 19;  x := 10; l := 6; end;
         6: begin y := 20;  x := 10; l := 6; end;
         7: begin y := 15;  x := 63; l := 1; end;
         8: begin y := 16;  x := 63; l := 1; end;
         9: begin y := 17;  x := 66; l := 1; end;
         10: begin y := 18;  x := 63; l := 1; end;
         11: begin y := 19;  x := 63; l := 1; end;
         12: begin y := 21;  x := 63; l := 1; end;
         13: begin y := 22;  x := 69; l := 4; end;
      end;
     Unmark(x,y,l);
  end;
 end;


 Procedure SelectItem(sel : byte);
 var x,y,l : byte;
 begin
  if keyboardmode then
  begin
      case sel of
         1: begin y := 7;  x := 10; l := 6; end;
         2: begin y := 8;  x := 10; l := 6; end;
         3: begin y := 13;  x := 10; l := 6; end;
         4: begin y := 14;  x := 10; l := 6; end;
         5: begin y := 19;  x := 10; l := 6; end;
         6: begin y := 20;  x := 10; l := 6; end;
         7: begin y := 15;  x := 63; l := 1; end;
         8: begin y := 16;  x := 63; l := 1; end;
         9: begin y := 17;  x := 66; l := 1; end;
         10: begin y := 18;  x := 63; l := 1; end;
         11: begin y := 19;  x := 63; l := 1; end;
         12: begin y := 21;  x := 63; l := 1; end;
         13: begin y := 22;  x := 69; l := 4; end;
      end;
   mark(x,y,l);
 end;
end;


Procedure WSS_PlaySample(Sample : Pointer; Size : Word; DMACh : Byte);

{Play data from pointer sample through WSS:

 Size           Size of data block (Max. 64 Kb in one time!)
 DMACh          Number of DMA-channel (0-3)}

Begin
 Dec(Size);
 Offset := Seg(Sample^) Shl 4 + Ofs(Sample^);
 Page := (Seg(Sample^) + Ofs(Sample^) Shr 4) Shr 12;
 Port[$0A] := $4 + DMACh;
 Port[$0C] := 0; {Clear the internal DMA flip-flop}
 Port[$0B] := $48 + DMACh;
 Port[DMAChannel[1,2]] := Lo(Offset);
 Port[DMAChannel[1,2]] := Hi(Offset);
 Port[DMAChannel[1,1]] := Page;
 Port[DMAChannel[1,3]] := Lo(Size);
 Port[DMAChannel[1,3]] := Hi(Size);
 Port[$0A] := DMACh;
 WriteCODECReg($0E,lo(size - 1));
 WriteCODECReg($0F,hi(size - 1));
 writeCODECreg($0A,$02);   {enable interrupt and pin control}
 MuteDAC(LEFTANDRIGHT,false);
 Playback(true);
End;

Procedure EnterWSSMode;
var dummy : byte;
begin
   SetWSSMode(cfg);           {Set OPTi 929 to WSS Mode}
   Protect_Shadowregs(false); {Enable full access to the codec}
   WaitForCodec;  {Wait for the codec to be ready}
   AD1848_SetOutputFormat(11025,PCM_U_8BIT,STEREO); {Set audio format}
   Calibrate_AD1848;  {Recalibrate codec to new samplerate}
   WaitForCodec;  {Wait for the codec to be ready again}
end;

Procedure EnterSBMode;
begin
   Prepare_AD1848_for_SB;
   WaitForCodec;  {Wait for the codec to be ready}
   SetSBMode(cfg); {Set OPTi Controller to SB Mode}
   Protect_Shadowregs(true);   {Disable direct codec access}
   DSP_Reset(sb.base);   {Reset sound blaster dsp}
   SB_Speaker(false);        {Mute dac}
   SB_ResetMixer;       {Reset the SB mixer}
   SB_Setvolume(DAC,left,round((volumes.dacl / 4.28)));  {Set new volumes}
   SB_Setvolume(DAC,right,round((volumes.dacr / 4.28)));
   SB_Setvolume(CD,left,round((volumes.aux1l / 4.28)));
   SB_Setvolume(CD,right,round((volumes.aux1r / 4.28)));
   SB_Setvolume(FM,left,round((volumes.aux2l / 4.28)));
   SB_Setvolume(FM,right,round((volumes.aux2r / 4.28)));
   case sbfreq.chan of
      0: SB_SetOutput(false,true);  {Set Mono output}
      1: SB_SetOutput(true,true);   {Set Stereo output}
   end;
end;



Procedure Wait_for_Mousebutton;
begin
   if not keyboardmode then
   begin
     repeat
         Mouse_Read;
     until mouse.b = 0;
   end
   else
   begin
    while iskeypressed do getkey;
    key := #0;
   end;
end;


  Procedure PlayFM;
  begin
     if fmplaying then
     begin
       fastwrite(66,5,0,7,'FM Music');
       if keyboardmode then putchar(66,5,'F',4,7);
       fastwrite(67,6,0,background, 'ﬂﬂﬂﬂﬂﬂﬂﬂ');
       fastwrite(74,5,0,background, '‹');
       if not keyboardmode then mouse_show;
       ClearOPL;
       StopBMFPlayer;
       fmplaying := false;
       Wait_for_Mousebutton;
      end
     else
      begin
        fastwrite(66,5,0,7,'FM Music');
        fastwrite(67,6,background,background, 'ﬂﬂﬂﬂﬂﬂﬂﬂ');
        fastwrite(74,5,background,background, '‹');
        mouse_show;
        PlayBMFdata(@intro8,3797);
        fmplaying := true;
        Wait_for_Mousebutton;
     end;
  end;

  Procedure PlayDAC;
  begin
        if dacplaying then
        begin
         fastwrite(66,7,0,7,'Sample');
         if keyboardmode then putchar(66,7,'S',4,7);
         fastwrite(67,8,0,background, 'ﬂﬂﬂﬂﬂﬂ');
         fastwrite(72,7,0,background, '‹');
         mouse_show;
         Playback(false);
         mutedac(leftandright,true);
         Port[$0A] := $4 + cfg.wssdma;
         Port[$0C] := 0; {Clear the internal DMA flip-flop}
         dacplaying := false;
         Wait_for_Mousebutton;
        end
        else
        begin
         fastwrite(66,7,0,7,'Sample');
         fastwrite(67,8,background,background, 'ﬂﬂﬂﬂﬂﬂ');
         fastwrite(72,7,background,background, '‹');
         mouse_show;

         mutedac(leftandright,true);
         WSS_PlaySample(ptr(seg(SOUND8BIT),ofs(SOUND8BIT)),samplesize-100,cfg.wssdma);
         dacplaying := true;
         Wait_for_Mousebutton;
        end;
     end;


     Procedure PlayMidi;
     begin
        fastwrite(66,9,0,7,'Wavetable');
        fastwrite(67,10,background,background, 'ﬂﬂﬂﬂﬂﬂﬂﬂﬂ');
        fastwrite(75,9,background,background, '‹');
        mouse_show;
        NoteOff(1,48,127);
        SetPatch(1,1);
        NoteOn(1,48,127);
        Wait_for_Mousebutton;
        mouse_hide;
        fastwrite(66,9,0,7,'Wavetable');
        if keyboardmode then putchar(66,9,'W',4,7);
        fastwrite(67,10,0,background, 'ﬂﬂﬂﬂﬂﬂﬂﬂﬂ');
        fastwrite(75,9,0,background, '‹');
        mouse_show;
      end;




     Procedure SetMic;
     begin
      input := Mic;
      putchar(63,15,' ',textcol,background);
      putchar(63,16,'x',textcol,background);
      fastwrite(65,17,textcol,background,'( ) +20db');
      putchar(63,18,' ',textcol,background);
      putchar(63,19,' ',textcol,background);

      if mgain =  1 then
      begin
        putchar(66,17,'x',textcol,background);
        mouse_show;
        SetInput(MIC,LEFTANDRIGHT,volumes.gain,true);
      end
      else
      begin
        putchar(66,17,' ',textcol,background);
        mouse_show;
        SetInput(MIC,LEFTANDRIGHT,volumes.gain,false);
      end;
     end;

     Procedure SetLine;
     begin
      input := Line;
      putchar(63,15,'x',textcol,background);
      putchar(63,16,' ',textcol,background);
      fastwrite(65,17,8,background,'( ) +20db');
      putchar(63,18,' ',textcol,background);
      putchar(63,19,' ',textcol,background);
      mgain := 0;
      mouse_show;
      SetInput(LINE,LEFTANDRIGHT,volumes.gain,false);
     end;

     Procedure SetMicGain;
     begin
       if mgain = 1 then
       begin
        putchar(66,17,' ',textcol,background);
        mouse_show;
        mgain := 0;
        SetInput(MIC,LEFTANDRIGHT,volumes.gain,false);
      end
      else
      begin
        putchar(66,17,'x',textcol,background);
        mouse_show;
        SetInput(MIC,LEFTANDRIGHT,volumes.gain,true);
        mgain := 1;
      end;
     end;


     Procedure SetAUx;
     begin
      input := AUX1i;
      putchar(63,15,' ',textcol,background);
      putchar(63,16,' ',textcol,background);
      fastwrite(65,17,8,background,'( ) +20db');
      putchar(63,18,'x',textcol,background);
      putchar(63,19,' ',textcol,background);
      mgain := 0;
      mouse_show;
      SetInput(AUX1i,LEFTANDRIGHT,volumes.gain,false);
     end;


     Procedure SetPostMix;
     begin
      input := PostMx;
      putchar(63,15,' ',textcol,background);
      putchar(63,16,' ',textcol,background);
      fastwrite(65,17,8,background,'( ) +20db');
      putchar(63,18,' ',textcol,background);
      putchar(63,19,'x',textcol,background);
      mouse_show;
      SetInput(POSTMX,LEFTANDRIGHT,volumes.gain,false);
     end;

     Procedure SetDmix;
     begin
      if dmix = false then
      begin
       putchar(63,21,'x',textcol,background);
       mouse_show;
       SetDigitalMix(true,volumes.gain);
       dmix := true;
      end
      else
      begin
       putchar(63,21,' ',textcol,background);
       mouse_show;
       SetDigitalMix(false,volumes.gain);
       dmix := false;
      end;
     end;


     Procedure SetGain;
     begin
      fastwrite(69,22,15,0,addspace(round((volumes.gain / 15)*100))+'%');
     
      mouse_show;

      if input = mic then
      begin
        if mgain = 1 then
        begin
          SetInput(MIC,LEFTANDRIGHT,volumes.gain,true);
        end
        else
        begin
          SetInput(MIC,LEFTANDRIGHT,volumes.gain,false);
        end;
      end;

      if input = line then
      begin
        SetInput(LINE,LEFTANDRIGHT,volumes.gain,false);
      end;

      if input =  PostMx then
      begin
        SetInput(POSTMX,LEFTANDRIGHT,volumes.gain,false);
      end;

      if input =  AUX1i then
      begin
        SetInput(AUX1i,LEFTANDRIGHT,volumes.gain,false);
      end;

     end;









begin

   if (paramstr(1) = '/?') or (paramstr(1) = '?') then
   begin
     writeln('');
     writeln(' Command line parameters for the Mixer: ');
     writeln(' /K - Forces keyboard control of the program');
     writeln(' /? - Brings up this help');
     writeln('');
     writeln(' The desired volume can be set via command line:');
     writeln(' Mixer.exe <Device> <Left volume (%)> <Right volume (%)>');
     writeln(' Supported values for <Device> are AUX1, AUX2 and DAC');
     writeln('');
     halt(0);
   end;


 writeln('');
 write(' Reading configuration... ');
 if not loadsettings then
 begin
  writeln('');
  writeln('Config file not found! Please run SETUP first.');
  writeln('');
  halt(1);
 end;
 writeln('OK');


 if paramcount <> 3 then write(' Checking hardware....');

 if not Detect929 then
 begin
  writeln('');
  writeln(' No Soundcard with OPTi 82C929 Soundcontroller found! ');
  writeln('');
  halt(1);
 end;

 {Init some variables for codec access}
 CODEC.WSSPort := cfg.WSSBase;
 CODEC.ADDR    := cfg.WSSBase+4;
 CODEC.DATA    := cfg.WSSBase+5;
 CODEC.STATUS  := cfg.WSSBase+6;
 CODEC.PIO     := cfg.WSSBase+7;
 dacplaying := false;
 fmplaying := false;

 if not DetectAD1848 then
 begin
  writeln('');
  writeln(' No supported Codec found on soundcard! ');
  writeln(' Run SETUP to check the configuration. ');
  writeln('');
  halt(1);
 end;

 if SBMode then                        {Opti929 is in SB mode}
 begin
   if not DSP_Reset(cfg.SBBase) then   {Try to reset the DSP}
   begin
     writeln('');
     writeln(' Sound Blaster initialisation failed!');
     writeln(' Run SETUP to check the configuration. ');
     writeln('');
     halt(1);
   end;
   SB_resetMixer;       {Reset mixer}
   SBM := true;        {Save that we started in SB mode to restore it later}
 end;

 if cfg.opl = 3 then
 begin
   if not detectOPL3 then
   begin
     writeln('');
     writeln(' No Yamaha YMF262 (OPL3) compatible FM-Chip found!');
     writeln('');
     halt(1);
   end;
   InitOPL;
   ClearOPL;
 end;



 if cfg.mpu401 = 1 then
 begin
   COMDPORT := cfg.mpubase+1;
   STATPORT := cfg.mpubase+1;
   DATAPORT := cfg.mpubase;
   ResetMPU(0);                          {First try to reset MPU to default (intelligent) mode}
   if not ResetMPU(1) then               {Then try to set it to UART}
   begin
     writeln('');
     writeln(' Initalisation of MPU-401 interface failed!');
     writeln(' Run SETUP to check the configuration. ');
     writeln('');
     halt(1);
   end;
 end;

 if paramcount <> 3 then
 begin

   if (mouse_there = false) or (mouse_init = false) or (uppercase(paramstr(1)) = '/K') then
   begin
     keyboardmode := true;
     mouse_there := false;
   end
   else
   begin
     keyboardmode := false;
   end;


  writeln('OK');
 end
 else
 begin
  writeln('OK');
  writeln('');
  s := paramstr(1);
  for z := 1 to length(s) do s[z] := upcase(s[z]);

  if (s = 'DAC') or (s = 'AUX1') or (s = 'AUX2') then
  begin
    val(paramstr(2),vl,c1);
    val(paramstr(3),vr,c2);

    if (c1 <> 0) or (c2 <> 0) or (vl > 100) or (vr > 100) then
    begin
     writeln('Invalid value for volume! Valid volumes are 0 to 100.');
     writeln('');
     halt(1);
    end;
    vl := round(vl*0.3);
    vr := round(vr*0.3);

    EnterWSSMode;                  {switch controller to WSS mode for full codec access}

    if s = 'DAC'  then
    begin
     AD1848_SetVolume(DAC,Left,vl);
     AD1848_SetVolume(DAC,Right,vr);
    end;

    if s = 'AUX1' then
    begin
     AD1848_SetVolume(AUX1,Left,vl);
     AD1848_SetVolume(AUX1,Right,vr);
    end;

    if s = 'AUX2' then
    begin
     AD1848_SetVolume(AUX2,Left,vl);
     AD1848_SetVolume(AUX2,Right,vr);
    end;

    if sbm then EnterSBMode;
    halt(0);
  end
  else
  begin
     writeln(' Invalid parameter!');
     writeln(' Mixer.exe <Device> <Left volume (%)> <Right volume (%)>');
     writeln(' Supported values for <Device> are AUX1, AUX2 and DAC');
     writeln('');
     halt(1);
  end;

end;

 asm
  mov ax,3h
  int 10h
 end;

 cursor(false);
 randomize;

 EnterWSSMode;


 InitMenuScreen(title);
 if not keyboardmode then
 begin
  Centeredline(25,14,1,footer);
 end
 else
 begin
  Centeredline(24,14,1,kfooter);
  Centeredline(25,14,1,footer);
 end;

 window(4,3,57,23,textcol,background,true);
 fastwrite(23,3,headings,background,'Actual volumes:');
 fastwrite(8, 5,headings,background,'DAC Output');
 fastwrite(10, 7,textcol,background,'Left:   ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ');
 fastwrite(10, 8,textcol,background,'Right:  ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ');
 fastwrite(8,11,headings,background,'Auxiliary 1 (CD and ext. Midi)  ');
 fastwrite(10,13,textcol,background,'Left:   ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ');
 fastwrite(10,14,textcol,background,'Right:  ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ');
 fastwrite(8,17,headings,background,'Auxiliary 2 (FM and Wavetableheader) ');
 fastwrite(10,19,textcol,background,'Left:   ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ');
 fastwrite(10,20,textcol,background,'Right:  ƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒƒ');


 volumes.dacl  := AD1848_GetVolume(DAC,Left);
 volumes.dacr  := AD1848_GetVolume(DAC,Right);
 volumes.aux1l := AD1848_GetVolume(AUX1,Left);
 volumes.aux1r := AD1848_GetVolume(AUX1,Right);
 volumes.aux2l := AD1848_GetVolume(AUX2,Left);
 volumes.aux2r := AD1848_GetVolume(AUX2,Right);
 volumes.gain  := AD1848_GetGain(LeftANDRight);

 dacl.x  := volumes.dacl+18;
 dacr.x  := volumes.dacr+18;
 aux1l.x := volumes.aux1l+18;
 aux1r.x := volumes.aux1r+18;
 aux2l.x := volumes.aux2l+18;
 aux2r.x := volumes.aux2r+18;

 putchar(dacl.x,7,'€',textcol,background);
 putchar(dacr.x,8,'€',textcol,background);
 putchar(aux1l.x,13,'€',textcol,background);
 putchar(aux1r.x,14,'€',textcol,background);
 putchar(aux2l.x,19,'€',textcol,background);
 putchar(aux2r.x,20,'€',textcol,background);



 window(60,13,79,23,textcol,background,true);
 fastwrite(63,13,headings,background,'Input Control:');
 fastwrite(62,15,textcol,background,'( ) Line in');
 fastwrite(62,16,textcol,background,'( ) Microphone');
 fastwrite(65,17,8,background,'( ) +20db');
 if mgain = 1 then putchar(66,17,'x',8,15);
 fastwrite(62,18,textcol,background,'( ) AUX1');
 fastwrite(62,19,textcol,background,'( ) Post-Mixed');
 fastwrite(62,21,textcol,background,'( ) Mix ADC/DAC');


 fastwrite(62,22,textcol,background,'Gain:');

 if not keyboardmode then
 begin
  putchar(68,22,#24,0,7);
  putchar(73,22,#25,0,7);
 end;

 fastwrite(69,22,15,0,addspace(round((volumes.gain / 15)*100))+'%');


 if input = line then putchar(63,15,'x',textcol,background);

 if input = mic then
 begin
  putchar(63,16,'x',textcol,background);
  fastwrite(65,17,textcol,background,'( ) +20db');
  if mgain = 1 then putchar(66,17,'x',textcol,background);
 end;

 if input = aux1i then putchar(63,18,'x',textcol,background);

 if input = postmx then putchar(63,19,'x',textcol,background);

 if dmix then putchar(63,21,'x',textcol,background);

 window(64,3,78,11,textcol,background,true);
 fastwrite(66,3,headings,background,'Soundcheck:');

 fastwrite(66,5,0,7,'FM Musik');
 if keyboardmode then putchar(66,5,'F',4,7);
 fastwrite(67,6,0,background, 'ﬂﬂﬂﬂﬂﬂﬂﬂ');
 fastwrite(74,5,0,background, '‹');

 fastwrite(66,7,0,7,'Sample');
 if keyboardmode then putchar(66,7,'S',4,7);
 fastwrite(67,8,0,background, 'ﬂﬂﬂﬂﬂﬂ');
 fastwrite(72,7,0,background, '‹');

 if cfg.mpu401 = 0 then
 begin
  fastwrite(66,9,0,7,'Wavetable');
 end
 else
 begin
  fastwrite(66,9,0,7,'Wavetable');
  if keyboardmode then putchar(66,9,'W',4,7);
  fastwrite(67,10,0,background, 'ﬂﬂﬂﬂﬂﬂﬂﬂﬂ');
  fastwrite(75,9,0,background, '‹');
 end;

 fmplaying := false;
 dacplaying := false;

 Refresh_volumes;


 if not keyboardmode then
 begin
  mouse_show;
 end
 else
 begin
   select := 1;
   selectitem(select);
 end;

 while iskeypressed do getkey;
 (*
 assign(f,'MIX.SCR');
 rewrite(f,1);
 blockwrite(f,ptr(segB800,0)^,4000);
 close(f);
   *)

repeat;
 if not keyboardmode then Mouse_Read;

 if (getbit(ReadCODECReg($B),6) = 1) and (dacplaying = true) then
 begin
    Playback(false);
    mutedac(leftandright,true);
    Port[$0A] := $4 + cfg.wssdma;
    Port[$0C] := 0; {Clear the internal DMA flip-flop}
    mouse_hide;
    fastwrite(66,7,0,7,'Sample');
    if keyboardmode then putchar(66,7,'S',4,7);
    fastwrite(67,8,0,background, 'ﬂﬂﬂﬂﬂﬂ');
    fastwrite(72,7,0,background, '‹');
    mouse_show;
    dacplaying := false;
 end;


if (keyboardmode = false) and (mouse.b = 1) then
begin
    mouse_hide;
    xp := (mouse.x div 8)+1;
    yp := (mouse.y div 8)+1;


  if (xp >= 69) and (xp <= 75) and (yp = 25) then break;

  if (xp >= 66) and (xp <= 73) and (yp = 5) then
  begin
   PlayFM;
  end;

   if (xp >= 66) and (xp <= 73) and (yp = 7) then
   begin
    PlayDAC;
   end;

   if (xp >= 66) and (xp <= 73) and (yp = 9) and (cfg.mpu401 > 0) then
   begin
    PlayMidi;
   end;


    if (xp >= 18) and (xp <= 49) then
    begin
      case yp of

       7:
       begin
        putchar(dacl.x,7,'ƒ',textcol,background);
        dacl.x := xp;
        putchar(dacl.x,7,'€',textcol,background);
        volumes.dacl := xp - 18;
        AD1848_SetVolume(DAC,Left,volumes.dacl);
       end;

       8:
       begin
        putchar(dacr.x,8,'ƒ',textcol,background);
        dacr.x := xp;
        putchar(dacr.x,8,'€',textcol,background);
        volumes.dacr := xp - 18;
        AD1848_SetVolume(DAC,Right,volumes.dacr);
       end;

      13:
       begin
        putchar(aux1l.x,13,'ƒ',textcol,background);
        aux1l.x := xp;
        putchar(aux1l.x,13,'€',textcol,background);
        volumes.aux1l := xp - 18;
        AD1848_SetVolume(AUX1,Left,volumes.aux1l);
       end;

      14:
       begin
        putchar(aux1r.x,14,'ƒ',textcol,background);
        aux1r.x := xp;
        putchar(aux1r.x,14,'€',textcol,background);
        volumes.aux1r := xp - 18;
        AD1848_SetVolume(AUX1,Right,volumes.aux1r);
       end;

      19:
       begin
        putchar(aux2l.x,19,'ƒ',textcol,background);
        aux2l.x := xp;
        putchar(aux2l.x,19,'€',textcol,background);
        volumes.aux2l := xp - 18;
        AD1848_SetVolume(AUX2,Left,volumes.aux2l);
        end;

      20:
       begin
        putchar(aux2r.x,20,'ƒ',textcol,background);
        aux2r.x := xp;
        putchar(aux2r.x,20,'€',textcol,background);
        volumes.aux2r := xp - 18;
        AD1848_SetVolume(AUX2,Right,volumes.aux2r);
       end;
    end;
    Refresh_volumes
   end;

    if (xp = 63) and (yp = 15) then
    begin
     SetLine;
    end;

    if (xp = 63) and (yp = 16) then
    begin
     SetMic;
    end;

    if (xp = 66) and (yp = 17) and (input = mic) then
    begin
     setMicGain;
     xdelay(300);
    end;

    if (xp = 63) and (yp = 18) then
    begin
     SetAux;
     xdelay(300);
    end;

    if (xp = 63) and (yp = 19) then
    begin
     SetPostMix;
     xdelay(300);
    end;

    if (xp = 63) and (yp = 21) then
    begin
     SetDmix;
     xdelay(300);
    end;


    if (xp = 68) and (yp = 22) then
    begin
      if volumes.gain < 15 then inc(volumes.gain);
      SetGain;
      xdelay(200);
    end;

    if (xp = 73) and (yp = 22) then
    begin
      if volumes.gain > 0 then dec(volumes.gain);
      SetGain;
      xdelay(200);
    end;

    mouse.b := 0;
    mouse_show;
end;


 if iskeypressed then key := getkey;


if keyboardmode = true then
begin
 selectitem(select);
 if key = #80 then
 begin
   unselectitem(select);
   if select < 13 then  inc(select);
   if (select = 9) and (input <> mic) then inc(select);
   selectitem(select);
   key := #0;
   while iskeypressed do getkey;
 end;

 if key = #72 then
 begin
   unselectitem(select);
   if select > 1 then  dec(select);
   if (select = 9) and (input <> mic) then dec(select);
   selectitem(select);
   key := #0;
   while iskeypressed do getkey;
 end;

 if key = '+' then
 begin
  case select of
   1: begin
        if volumes.dacl < 31 then inc(volumes.dacl);
        AD1848_SetVolume(DAC,Left,volumes.dacl);
       end;
   2: begin
        if volumes.dacr < 31 then inc(volumes.dacr);
        AD1848_SetVolume(DAC,Right,volumes.dacr);
       end;
   3: begin
        if volumes.aux1l < 31 then inc(volumes.aux1l);
        AD1848_SetVolume(AUX1,LEFT,volumes.aux1l);
       end;
   4: begin
        if volumes.aux1r < 31 then inc(volumes.aux1r);
        AD1848_SetVolume(AUX1,Right,volumes.aux1r);
       end;
   5: begin
        if volumes.aux2l < 31 then inc(volumes.aux2l);
        AD1848_SetVolume(AUX2,LEFT,volumes.aux2l);
       end;
   6: begin
        if volumes.aux2r < 31 then inc(volumes.aux2r);
        AD1848_SetVolume(AUX2,Right,volumes.aux2r);
       end;
   13: begin
         if volumes.gain < 15 then inc(volumes.gain);
         SetGain;
        end;

    end;
   Reset_Sliders;
   key := #0;
   while iskeypressed do getkey;
 end;

 if key = '-' then
 begin
  case select of
   1: begin
        if volumes.dacl > 0 then dec(volumes.dacl);
        AD1848_SetVolume(DAC,Left,volumes.dacl);
       end;
   2: begin
        if volumes.dacr > 0 then dec(volumes.dacr);
        AD1848_SetVolume(DAC,Right,volumes.dacr);
       end;
   3: begin
        if volumes.aux1l > 0 then dec(volumes.aux1l);
        AD1848_SetVolume(AUX1,LEFT,volumes.aux1l);
       end;
   4: begin
        if volumes.aux1r > 0 then dec(volumes.aux1r);
        AD1848_SetVolume(AUX1,Right,volumes.aux1r);
       end;
   5: begin
        if volumes.aux2l > 0 then dec(volumes.aux2l);
        AD1848_SetVolume(AUX2,LEFT,volumes.aux2l);
       end;
   6: begin
        if volumes.aux2r > 0 then dec(volumes.aux2r);
        AD1848_SetVolume(AUX2,Right,volumes.aux2r);
       end;
   13: begin
        if volumes.gain > 0 then dec(volumes.gain);
        SetGain;
       end;

    end;

   Reset_Sliders;
   selectitem(select);
   key := #0;
   while iskeypressed do getkey;
 end;


 if (key = #32) or (key = #13) then
 begin
   unselectitem(select);
   case select of
    7: SetLine;
    8: SetMic;
    9: SetMicGain;
   10: SetAux;
   11: SetPostMix;
   12: SetDmix;
   end;
   selectitem(select);
   key := #0;
   while iskeypressed do getkey;
 end;




 if upcase(key) = 'F' then
 begin
  PlayFM;
 end;
 if upcase(key) = 'W' then
 begin
  PlayMidi;
 end;
 if upcase(key) = 'S' then
 begin
  PlayDAC;
 end;





end;

 if key = F1 then
 begin
   fastwrite(15,22,textcol,background,'                               ');
   if not LoadSettings then
   begin
     fastwrite(15,22,4,15,'Error reading the saved volumes!');
   end
  else
   begin
     Reset_Sliders;
   end;
   key := #0;
 end;



until (key =  #27);
 if dacplaying then
  begin
    Playback(false);
    mutedac(leftandright,true);
    Port[$0A] := $4 + cfg.wssdma;
    Port[$0C] := 0; {Clear the internal DMA flip-flop}
    dacplaying := false;
  end;

  if fmplaying then
  begin
   StopBMFPlayer;
  end;

 if cfg.mpu401 = 1 then
 begin
  NoteOff(1,48,127);
  ResetMPU(1);    {Reset UART Mode}
  ResetMPU(0);    {Reset back to default mode}
 end;


  MuteDAC(LeftANDRight,true);
  ClearOPL;



  mouse_hide;
  textbackground(0);
  textcolor(7);
  clrscr;
  cursor(true);
  writeln(Title);
  writeln('FM tune: "Intro #8" by The Brain / Razor 1911');
  writeln('');

  if not  SaveSettings then
  begin
   writeln('Saving failed! ');
  end
  else
  begin
   writeln('Volumes successfully saved!');
  end;

  if SBm then
  begin
    EnterSBMode;
  end;
  writeln('');
end.
