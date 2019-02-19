{
******************************************************************************
Low Level initialization of Sound Cards with OPTi 82C929 Controller
******************************************************************************
Version:    1.2
Author :    Jan Knipperts
******************************************************************************


Program OPTI929_AD1848_Driver;
uses opti929,mpu,oplfm,opl4,sbpro,ad1848,
     dos,textmode,misc;


type

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

const

 Title : string = 'Optimized MAD16 PRO soundcard initialisation Version 1.2';
 Copyright : string = ' (c) 2019 by Jan Knipperts';

 error : array[1..11] of string =
        ('ERROR: Timeout. Codec is not responding!',
         'ERROR: Configuration file not found! Please run Setup.',
         'ERROR: An I/O error occured while reading the configuration file!',
         'ERROR: Unsupported WSS I/O address. Please run Setup.',
         'ERROR: Invalid IRQ address! Please run Setup.',
         'ERROR: Failed to initialize the MPU-401 interface. Please run Setup.',
         'ERROR: Faild to initialize the Sound Blaster DSP. Please run Setup.',
         'ERROR: Invalid volumes in the configuration file. Please run the Mixer to correct them.',
         'ERROR: No compatible CODEC found on your soundcard!',
         'ERROR: No compatible Soundcontroller found! This program requires the OPTi 82c929 soundcontroller.',
         'ERROR: Faild to initialize the Windows Sound System. Please run setup.');

 DSPver  : array[1..4] of string = ('1.5','2.1','3.2','4.4');

 NumInits = 5;

var
cfg                             : OPTi929config;
SBFreq,
WSSFreq                         : Freqconfig;
Volumes                         : codecvolumes;

v1,v2,d,cmd,fmt                 : byte;
init,sb,wss,info,stereo         : boolean;

f                               : file;
num,z,freq                      : word;
quiet,mode,newchip              : boolean;
s,dir,cfgfile                   : string;
serror                          : integer;


{=================== Drawing stuff =======================     }

Procedure PrintTitle;
var xc : word;
begin
  textcolor(7);
  textbackground(0);
  writeln('');
  write('Ú');
  for xc := 2 to 79 do
  begin
    gotoxy(xc,gety);
    write('Ä');
  end;
  write('¿');
  write('³');
  gotoxy(40-(length(title) div 2),gety);
  write(title);
  gotoxy(80,gety);
  write('³');
  write('³');
  gotoxy(40-(length(copyright) div 2),gety);
  write(copyright);
  gotoxy(80,gety);
  write('³');
  write('À');
  for xc := 2 to 79 do
  begin
    gotoxy(xc,gety);
    write('Ä');
  end;
  write('Ù');
end;




{====================================== Setup AD1848 ===============}



   Procedure SetVolumes;
   {Writes the userdefined volumes to the codec}
   begin
      AD1848_SetVolume(DAC,Left,volumes.dacl);
      waitforcodec;
      AD1848_SetVolume(DAC,Right,volumes.dacr);
      waitforcodec;
      AD1848_SetVolume(AUX1,Left,volumes.aux1l);
      waitforcodec;
      AD1848_SetVolume(AUX1,Right,volumes.aux1r);
      waitforcodec;
      AD1848_SetVolume(AUX2,Left,volumes.aux2l);
      waitforcodec;
      AD1848_SetVolume(AUX2,Right,volumes.aux2r);
      waitforcodec;

      if (AD1848_GetVolume(DAC,Left) <> volumes.dacl) or
         (AD1848_GetVolume(AUX1,Right) <> volumes.aux1r) or
         (AD1848_GetVolume(AUX2,Left) <> volumes.aux2l) then
      begin
        writeln('');
        writeln(error[8]);
        writeln('');
        halt(1);
      end;

      if (volumes.inp = LINE)  then
      begin
       SetInput(LINE,LEFTANDRIGHT,volumes.gain,false);
      end;

      if (volumes.inp = AUX1i)  then
      begin
       SetInput(AUX1i,LEFTANDRIGHT,volumes.gain,false);
      end;

      if (volumes.inp = POSTMX) then
      begin
        SetInput(POSTMX,LEFTANDRIGHT,volumes.gain,false);
      end;

      if (volumes.inp = MIC) then
      begin
        if volumes.micgain = 1 then
        begin
          SetInput(MIC,LEFTANDRIGHT,volumes.gain,true);
        end
        else
        begin
         SetInput(MIC,LEFTANDRIGHT,volumes.gain,false);
        end;
      end;

      SetDigitalMix(volumes.dmix,volumes.gain);
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

        Setvolumes;
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

        Setvolumes;
        Calibrate_AD1848;  {Recalibrate codec o new samplerate}
        WaitForCodec;  {Wait for the codec to be ready again}

     asm
      sti
     end;
   end;










{================================ Configuration Stuff ======================}

Procedure Setcfg;
{Reads the config file, checks settings and set up of some variables}
begin
  if not quiet then write('Reading configuration  - ');

  if not fileexist(cfgfile) then   {File not found!}
  begin
    writeln('');
    writeln(error[2]);
    writeln('');
    halt(1);
  end;

 fillchar(cfg,sizeof(cfg),0);

 assign(f,cfgfile);
 reset(f,1);

 {$I-}
     blockread(f,cfg,sizeof(cfg));
     blockread(f,sbfreq,sizeof(freqconfig));
     blockread(f,wssfreq,sizeof(freqconfig));
     blockread(f,volumes,sizeof(codecvolumes));
 {$I+}

 if IOResult <> 0 then                    {Diskerror?}
 begin
  writeln('');
  writeln(error[3]);
  close(f);
  writeln('');
  halt(1);
 end;

 close(f);


  if (cfg.WSSBase <> $530) and
     (cfg.WSSBase <> $E80) and
     (cfg.WSSBase <> $F40) and
     (cfg.WSSBase <> $604) then                {Unsupported settings for WSS-Port in config file?!?}
  begin
   writeln('');
   writeln(error[4]);
   writeln('');
   halt(1);
  end;

  if (cfg.WSSIRQ <> 7) and
     (cfg.WSSIRQ <> 9) and
     (cfg.WSSIRQ <> 10) and
     (cfg.WSSIRQ <> 11) and
     (cfg.WSSIRQ <> $FF) then                  {Unsupported WSS-IRQ in config file...}
  begin
   writeln('');
   writeln(error[5]);
   writeln('');
   halt(1);
  end;

  SBPort := cfg.SBBase;
  CODEC.WSSPort := cfg.WSSBase;
  CODEC.ADDR    := cfg.WSSBase+4;
  CODEC.DATA    := cfg.WSSBase+5;
  CODEC.STATUS  := cfg.WSSBase+6;
  CODEC.PIO     := cfg.WSSBase+7;

  if not quiet then writeln('OK');

end;


{==================================== Main chip detection ==========================}

Procedure DetectCodec;
var sb : boolean;
begin

if not quiet then write('Detecting AD1848 compatible CODEC on port '+hexw(CODEC.WSSPort)+'h - ');

sb := SBmode; {Save the state of the controller}

SetWSSMode(cfg);   {set controller to WSS mode}
Protect_Shadowregs(false); {Enable full access to the codec}

CODEC.WSSPort := cfg.WSSBase;      {Set up some variables to interatc with the codec}
CODEC.ADDR    := cfg.WSSBase+4;
CODEC.DATA    := cfg.WSSBase+5;
CODEC.STATUS  := cfg.WSSBase+6;
CODEC.PIO     := cfg.WSSBase+7;

if detectAD1848 then
begin
 if not quiet then writeln('OK');
 newchip := DetectNewChip;
end
else
begin
 writeln('NOT FOUND!');
 writeln('');
 if SB then
 begin
  SetSBMode(cfg);   {set controller back to SB Mode}
 end;
 halt(1);
end;

 if SB then
 begin
  SetSBMode(cfg);   {set controller back to SB Mode}
 end;

end;

Procedure DetectController;
begin

if not quiet then write('Detecting OPTi 82C929A Soundcontroller - ');

if detect929 then
begin
 if not quiet then writeln('OK');
end
else
begin
 writeln('NOT FOUND!');
 writeln('');
 halt(1);
end;
end;

{==================================== Initialization ==========================}

Procedure InitSoundcard;
begin
{Init OPTi 82C929}
if not quiet then write('Initialize the Controller - ');

  SetWSSMode(cfg);   {...in WSS Mode}
  Protect_Shadowregs(false); {Enable full access to the codec}

  CODEC.WSSPort := cfg.WSSBase;
  CODEC.ADDR    := cfg.WSSBase+4;
  CODEC.DATA    := cfg.WSSBase+5;
  CODEC.STATUS  := cfg.WSSBase+6;
  CODEC.PIO     := cfg.WSSBase+7;


if not quiet then writeln('OK');


{Ok, and now let's init the codec...}

if not quiet then write('Initialize the Codec - ');

Waitforcodec;   {Wait for codec to be ready...}

if not Init_AD1848 then   {Codec initialisation failed!}
begin
  writeln('');
  writeln(error[1]);
  writeln('');
  halt(1);
end;

for z := 1 to num do   {Errata....}
begin
 Waitforcodec;
 Init_AD1848;
 Waitforcodec;
end;

if (detectWSS) and not timeout then
begin
if not quiet then  writeln('OK');
end
else
begin
 writeln('');
 writeln(error[1]);
 writeln('');
 halt(1);
end;

{Init OPL3/OPL4}

if cfg.opl = 4 then  {Do we assume an OPL4?}
begin
  if not OPL4_detect then   {The config says OPL4 but we don't find one...}
  begin
   cfg.opl := 3;     {Set OPL3 instead}
   SetWSSMode(cfg);   {Reset controller to new configuration}
  end
  else
  begin
   opl4_pcm(false); {Init OPL4 in FM mode}
  end;
end;

if DetectOPL3 then    {Check if OPL3 is present..}
begin
  InitOPL;            {Found it. So we can initialize it..}
  ClearOPL;           {Mute all channels and clear registers}
end;

if cfg.initmode = 0 then
begin
 SB := TRUE;
 WSS := FALSE;
end
else
begin
 WSS := TRUE;
 SB  := FALSE;
end;

end;

{========================== Finding files =================}
Procedure GetPath;
begin
  {Looks up its own directory to access the configuration file.  
   This way we don't have to set an environment variable like the original driver}
  cfgfile := paramstr(0);
  while (cfgfile[Length(cfgfile)] <> '\') and (Length(cfgfile) <> 0) do
    Delete(cfgfile,Length(cfgfile),1);
  if cfgfile = '' then
    cfgfile := FExpand('');
  cfgfile := cfgfile+'SOUND.CFG';
end;

{================= Handle command line options ========================}

Function FindOption(lookup : string) : boolean;  {Searches for a string in all parameters}
var cnt : byte;
    s   : string;
begin
 FindOption := false;
 for cnt := 1 to paramcount do
 begin
  if length(paramstr(cnt)) > length(lookup) then
  s := copy(uppercase(paramstr(cnt)),1,length(lookup))
  else
  s := uppercase(paramstr(cnt)); {Make all chars uppercase}

  if s = uppercase(lookup) then
  begin
   FindOption := true;
   cmd := cnt;
   break;
  end;

 end;
end;




{============================= Main program ============================}

begin
 GetPath;         {Get path to config file}

 {Handle commandline:}
 if FindOption('/INIT') then INIT := true;
 if FindOption('/SB') then SB := true;
 if FindOption('/WSS')  then WSS := true;
 if FindOption('/INFO') then INFO := true;
 if FindOption('/Q') then quiet := true;

 num := numinits;

 if FindOption('/N') then
 begin
     s := uppercase(paramstr(cmd));
     if s[3] in ['1'..'9'] then
     begin
       s := copy(uppercase(paramstr(cmd)),3,length(uppercase(paramstr(cmd))));
       val(s,num,serror);
       if serror <> 0 then
       begin
        num := numinits;
       end;
     end;
 end;


  if not quiet then
  begin
    asm
     mov ax,03h                       {Set 80x25 Textmode}
     int 10h
    end;
  end;

  PrintTitle;

  if (init = false) and (wss = false) and
     (sb = false) and (info = false) then
  begin
    writeln(' Please add a commandline parameter: 929INIT.EXE <Parameter> {Option} ');
    writeln('');
    writeln(' Parameters: ');
    writeln(' /INIT     Initializes the soundcard ');
    writeln(' /SB       Sets the soundcard to Sound Blaster mode');
    writeln(' /WSS      Sets the soundcard to Windows Sound System mode ');
    writeln(' /INFO     Shows you the actual configuration of your soundcard');
    writeln('');
    writeln(' Additional options: ');
    writeln(' /Q        Quiet mode with reduced textoutput');
    writeln(' /N[xxx]   Number of initialisations for the codec ');
    writeln('           (some codecs need more than one...)');
    writeln('');
    writeln(' Options can be combined. For example:');
    writeln(' 929INIT.EXE /INIT /Q /N3');
    writeln('');
    halt(0);
  end;

  SetCFG;

  if not quiet then writeln('');

  if init then
  begin
   DetectController;
   InitSoundcard;
  end
  else
  begin
    DetectController;
    DetectCodec;
  end;

  if wss then
  begin
     if not quiet then write('Configure controller for WSS mode - ');
      SetWSSMode(cfg);           {Set OPTi 929 to WSS Mode}
      Protect_Shadowregs(false); {Enable full access to the codec}
      Prepare_AD1848_for_WSS;    {Set up AD1848 for use as WSS}

      if detectWSS then          {And try to detect a valid WSS System}
      begin
        if not quiet then      writeln('OK');
      end
      else
      begin
        writeln('');
        writeln(error[11]);     {Something went wrong...}
        writeln('');
        halt(1);
      end;

     if cfg.mpu401 = 1 then         {Set up MPU401 if it's enabled}
     begin
       DATAPORT := cfg.mpubase;
       COMDPORT := cfg.mpubase+1;
       STATPORT := cfg.mpubase+1;

       ResetMPU(0);    {First reset MPU to default mode (if only UART is supported this will already be UART)}
       xdelay(50);     {Wait a little bit}
       if not ResetMPU(1) then   {Then try to reset ist to UART}
       begin
         writeln('');
         writeln(error[6]);
         writeln('');
         halt(1);
       end;

     end;

      if quiet then writeln('Sound card successfully initialized (WSS mode).');
   end;



   if sb then
   begin
     if stereo then sbfreq.chan := 1;
     if mono then sbfreq.chan := 0;
     if not quiet then
     write('Configure controller for Sound Blaster mode - ');
     SetWSSMode(cfg);  {First reset WSS configuration, this solves some issues....}
     SetupWSSPort(cfg); {Make sure there is a valid WSS-Port. }
     {Don't ask me why resettung WSS first is necessary but some games detect the Sound Blaster much easier, if we do this first...} 
     
     Prepare_AD1848_for_SB; {Set up AD1848 for use as a Sound Blaster}
     Protect_Shadowregs(true); {Write protect the shadowed registers}
     SetSBMode(cfg); {Set OPTi Controller to SB Mode}
 
     {Now should be able to handle the SOundcard like a Sound Blaster Pro}
     if (DSP_Reset(cfg.SBbase) = true) and (hi(SB_GetDSPVersion) = cfg.SBver) then {OK! We can reset the DSP and get the valid DSP version}
     begin
      if not quiet then writeln('OK');
     end
     else
     begin                    {Something went wrong....}
      writeln('');
      writeln(error[7]);
      writeln('');
      halt(1);
     end;


     
     DSP_Reset(cfg.SBBase); {Reset DSP again}
     SB_Speaker(false); {Mute outputs}
     SB_ResetMixer; {Reset Mixerchip}

     SB_Setvolume(DAC,left,round((volumes.dacl / 4.28)));  {Now we set the codecs volumes again in SB Mixer}
     SB_Setvolume(DAC,right,round((volumes.dacr / 4.28))); {Just to be save...}
     SB_Setvolume(CD,left,round((volumes.aux1l / 4.28)));   {Volumes must be divided by 4.28 to mach SB mixer}
     SB_Setvolume(CD,right,round((volumes.aux1r / 4.28)));
     SB_Setvolume(FM,left,round((volumes.aux2l / 4.28)));
     SB_Setvolume(FM,right,round((volumes.aux2r / 4.28)));

     case sbfreq.chan of
      0: SB_SetOutput(false,true);  {Set Mono output}
      1: SB_SetOutput(true,true);   {Set Stereo output}
     end;
     
     If cfg.sbmix = 0 then SBMixer(false); {Disable the SB Mixer support, if it is configured like that}

     if cfg.mpu401 = 1 then         {Set up MPU401 if it's enabled}
     begin
       DATAPORT := cfg.mpubase;
       COMDPORT := cfg.mpubase+1;
       STATPORT := cfg.mpubase+1;

       ResetMPU(0);    {First reset MPU to default mode (if only UART is supported, this will already be UART)}
       xdelay(50);     {Wait a little bit}

       if not ResetMPU(1) then   {Now try to set MPU to UART}
       begin
         writeln('');
         writeln(error[6]);
         writeln('');
         halt(1);
       end;

     end;

     DSP_Reset(cfg.SBBase); {And again a DSP reset, jutst to bring it to a known save state for other applications}
     if quiet then
     writeln('Sound card successfully initialized (Sound Blaster mode).');


   end;


   if info then
   begin

    {Get Controller info}
    Getcfg(cfg);
    writeln('');


    if SBMode = false then             {Are we in SB or WSS Mode?}
    begin
      writeln('Controller is in WSS mode:');
      writeln('');
      writeln('Port   : '+hexw(cfg.WSSbase)+'h');

      if cfg.WSSirq < $FF then
      writeln('IRQ    : '+addspace(cfg.WSSirq))
      else
      writeln('IRQ    : Auto');

      if cfg.WSSdma < $FF then
      writeln('DMA    : '+addspace(cfg.WSSdma))
      else
      writeln('DMA    : Disabled');

      write('FM     : ');
      case cfg.opl of
       3: writeln('Yamaha OPL3 FM synthesis');
       4: writeln('Yamaha OPL4 FM and Wavetable synthesis');
      end;
      write('MPU 401: ');
      if cfg.mpu401 = 1 then writeln('Enabled,  Port: '+hexw(cfg.MPUbase)+'h ') else writeln('Disabled');
      write('Gamport: ');
      if cfg.gpen = 1 then writeln('Enabled') else writeln('Disabled');
      writeln('');
      AD1848_GetOutputFormat(freq,fmt,mode);
      writeln('Actual audio output format: ');
      str(freq,s);
      write(s+' Hz,  ');
      case fmt of
       COMP_U_LAW: write('8 Bit U-law companded');
       COMP_A_LAW: write('8 Bit A-law companded');
       PCM_U_8BIT: write('8 Bit unsigned PCM');
       PCM_COMPL_16BIT: write('16 Bit Twos-Complement PCM');
      end;
      if mode = true then writeln(', Stereo') else writeln(', Mono');
    end
    else
    begin
      SetWSSMode(cfg);        {Switch to WSS Mode for full access to the codec}
      writeln('Controller is in Sound Blaster mode.');
      writeln('');
      writeln('Port   : '+hexw(cfg.SBbase)+'h ');
      if cfg.SBirq < $FF then
      writeln('IRQ    : '+addspace(cfg.SBirq))
      else
      writeln('IRQ    : Disabled');

      if cfg.SBdma < $FF then
      writeln('DMA    : '+addspace(cfg.SBdma))
      else
      writeln('DMA    : Disabled');

      writeln('DSP    :  '+dspver[cfg.SBver]);
        write('FM     : ');
      case cfg.opl of
       3: writeln('Yamaha OPL3 FM synthesis');
       4: writeln('Yamaha OPL4 FM and Wavetable synthesis');
      end;
      write('MPU 401: ');
      if cfg.mpu401 = 1 then writeln('Enabled,  Port: '+hexw(cfg.MPUbase)+'h ') else writeln('Disabled');
      write('Gamport: ');
      if cfg.gpen = 1 then writeln('Enabled') else writeln('Disbaled');
      writeln('');
      AD1848_GetOutputFormat(freq,fmt,mode);
      writeln('Actual audio output format: ');
      str(freq,s);
      write(s+' Hz,  ');
      case fmt of
       COMP_U_LAW: write('8 Bit U-law companded');
       COMP_A_LAW: write('8 Bit A-law companded');
       PCM_U_8BIT: write('8 Bit unsigned PCM');
       PCM_COMPL_16BIT: write('16 Bit Twos-Complement PCM');
      end;
      if mode = true then writeln(', Stereo') else writeln(', Mono');
      SetSBMode(cfg);  {Switch Back to SB}
      DSP_Reset(cfg.SBBase); {Reset DSP to be ready}
    end;
  end;

  writeln('');
end.
