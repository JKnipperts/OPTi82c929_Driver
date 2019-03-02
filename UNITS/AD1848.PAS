{Low level driver for Analog Devices AD1848 Soundport codec
 V 1.0 (c) 2019 by Jan Knipperts}




Unit AD1848;

interface

type
AD1848cfg = record
     WSSPort   : word;
     ADDR      : word;
     DATA      : word;
     STATUS    : word;
     PIO       : word;
end;

codec_rate_struct = record
   freq           : word;
   divider, xtal  : byte;
end;



const

  AD1848_Initialization_values : array[0..15] of byte =

  ($a8, $a8, $08, $08, $08, $08, $00, $00,
   $00, $0c, $02, $00, $8a, $01, $00, $00);


{List of supported rates}
 codec_rates : array[1..14] of codec_rate_struct =
(
   (freq:  5512; divider: 0; xtal: 2),
   (freq:  6620; divider: 7; xtal: 2),
   (freq:  8000; divider: 0; xtal: 1),
   (freq:  9600; divider: 7; xtal: 1),
   (freq: 11025; divider: 1; xtal: 2),
   (freq: 16000; divider: 1; xtal: 1),
   (freq: 18900; divider: 2; xtal: 2),
   (freq: 22050; divider: 3; xtal: 2),
   (freq: 27420; divider: 2; xtal: 1),
   (freq: 32000; divider: 3; xtal: 1),
   (freq: 33075; divider: 6; xtal: 2),
   (freq: 37800; divider: 4; xtal: 2),
   (freq: 44100; divider: 5; xtal: 2),
   (freq: 48000; divider: 6; xtal: 1)
);


        {Tries until timeout}
  timeoutvalue = 100000;

 { Codec Volume devices }
  DAC          = 6;
  AUX1         = 2;
  AUX2         = 4;

  {Coec Input Devices}
  LINE         = 0;
  MIC          = 1;
  POSTMX       = 2;
  AUX1i        = 3;

  {Indications for left, right or both channels }
  Left         = 0;
  Right        = 1;
  LeftAndRight = 2;

  {Audio format indicators}
  COMP_U_LAW      = 1;
  COMP_A_LAW      = 2;
  PCM_U_8BIT      = 3;
  PCM_COMPL_16BIT = 4;
  STEREO          = TRUE;
  MONO            = FALSE;





var
Codec                          : AD1848cfg;
codecver                       : byte;
z                              : word;
timeoutcnt                     : Longint;
timeout                        : Boolean;



Function DetectAD1848 : boolean;
{Detects an AD1848 compatible codec}

Function DetectNewChip : boolean;
{Detects newer codec like AD1845 or CS4231A}

Function Init_AD1848 : Boolean;
{Initialize the AD1848}

Function Wait_calibration : boolean;
{Waits for autocalibration to complete}

Procedure WaitforCodec;
{Waits until the chip becomes ready}

Procedure Calibrate_AD1848;
{Does the full Recalibration circle}

Procedure MCE(onoff : boolean);
 {Schaltet "Modechange" an/aus}

Procedure WriteCODECReg(reg : byte; data : byte);
{Writes one byte to the given register of the codec}

Function ReadCODECReg(reg : byte) : byte;
{Reads one byte from the given register of the codec}

Function DetectWSS : boolean;
{Detects Windows Sound System}

Procedure AD1848_SetVolume(VolumeType, Channel, Volume : Byte);

Function  AD1848_GetVolume(VolumeType, Channel : byte) : byte;

Procedure AD1848_SetOutputFormat(freq : word; format : byte; stereo : boolean);
Procedure AD1848_GetOutputFormat(var freq : word;var format : byte;var sm : boolean);

Procedure MuteDAC(Channel : byte; muteit : Boolean);
Procedure MuteAUX1(Channel : byte; muteit : Boolean);
Procedure MuteAUX2(Channel : byte; muteit : Boolean);

Function  GetInputDevice : byte;
Function  AD1848_GetGain(Channel : Byte) : byte;
Procedure SetInput(Device, Channel, Volume : byte; MicGain : Boolean);

Procedure Playback(startstop : Boolean);
Procedure Capture(startstop : Boolean);

Procedure SetDigitalMix(Enable : Boolean; Volume : byte);






implementation

procedure set_bit(var b:byte; bit:integer; value:boolean);
{Schnelle Funktion zum setzen eines einzelnen Bit}
begin
   if value then
      b:= b or (1 shl bit)
   else
      b:= b and not (1 shl bit);
end;


Function get_Bit(b, n : Byte) : boolean;
{liefert den Zustand eines Bit}
begin
  get_Bit := boolean(odd(b shr n));
end;


procedure XDelay(ms:word);
{Replacement fÅr Borlands Delay routine}
assembler;
asm
  mov ax,1000
  mul ms
  mov cx,dx
  mov dx,ax
  mov ah,86h
  int 15h
end;


Procedure WaitforCodec;
begin
        timeout := false;
        timeoutcnt := timeoutvalue;
	while (port[CODEC.ADDR] = $80) {initialisation bit set}
        and (timeoutcnt > 0) do dec(timeoutcnt);
        if timeoutcnt = 0 then timeout := true;
end;


Procedure WaitACI;              {Wait until ACI bit turns off}
begin
        port[CODEC.ADDR] := $B; {I11}
        timeoutcnt := timeoutvalue;
        while (timeoutcnt > 0) and ((port[CODEC.DATA] and $20) = 1) do
        begin
         dec(timeoutcnt);
        end;
        if timeoutcnt = 0 then timeout := true;
end;





Function Wait_calibration : boolean;
begin

        timeout := false; {We hope for the best}
        Waitforcodec; {Wait until the chip becomes ready (reads don't return 0x80)}

        {One last try...}
        if (port[CODEC.ADDR] = $80) then {Init bit still set...}
        begin
         Wait_calibration := false;      {so there is something wrong with the codec...}
         exit;
        end;



        {Wait until the ACI bit of I11 gets on...}
	port[CODEC.ADDR] := $B; {I11}

        timeoutcnt := timeoutvalue;
        while (timeoutcnt > 0) and ((port[CODEC.DATA] and $20) = 0) do
        begin
         dec(timeoutcnt);
        end;

        {One last try...}
        if ((port[CODEC.DATA] and $20) = 0) and (timeoutcnt = 0) then
        begin
         Wait_calibration := false; {Auto calibration timed out}
         timeout := true;
         exit;
        end;

        {Wait until the ACI bit of I11 gets off again}

        timeoutcnt := timeoutvalue;
        while (timeoutcnt > 0) and ((port[CODEC.DATA] and $20) = 1) do
        begin
         dec(timeoutcnt);
        end;

        {One last try...}
        if ((port[CODEC.DATA] and $20) = 1) then
        begin
         Wait_calibration := false; {Auto calibration timed out}
         timeout := true;
         exit;
        end;

        Wait_calibration := true;   {Auto calibration done}
end;






Procedure WriteCODECReg(reg : byte; data : byte);
{Writes one byte to the given register}
 var oldreg : byte;
   begin

        asm
         cli
        end;

       {Are we initalizing?}
        WaitforCodec;
        oldreg := port[CODEC.ADDR];

        if oldreg <> $80 then
        begin
	 port[CODEC.ADDR] := (oldreg and $F0) or (reg and $0F);
         xdelay(1);
         port[CODEC.DATA] := data;  {For some reason this has to be done at least twice...}
         port[CODEC.DATA] := data;
         port[CODEC.DATA] := data;
         xdelay(1);
         data := port[CODEC.DATA];
         data := port[CODEC.DATA];
         data := port[CODEC.DATA];
         port[CODEC.ADDR] := oldreg;
         xdelay(1);
        end;

        asm
         sti
        end;
   end;


Function ReadCODECReg(reg : byte) : byte;
{Reads one byte from the given register}
 var oldreg,retval : byte;
    begin

        asm
         cli
        end;

                 {Are we initalizing?}

        WaitforCodec;
        oldreg := port[CODEC.ADDR];

        if oldreg <> $80 then  {is the codec responding now?}
        begin
 	 port[CODEC.ADDR] := (oldreg and $F0) or (reg and $0F);
         xdelay(1);
         retval := port[CODEC.DATA];
         retval := port[CODEC.DATA];   {Errata for AD1848....}
         retval := port[CODEC.DATA];
         ReadCODECReg := retval;
         port[CODEC.ADDR] := oldreg;
         xdelay(1);
        end;


        asm
         sti
        end;
   end;




function DetectAD1848 : boolean;
{Detects AD1848}
var d1,d2 : byte;
   begin

    if port[CODEC.wssport] = $FF then     {Ist an dem Port Åberhaupt etwas?}
    begin
     DetectAD1848 := false;
    end
    else
    begin

        if port[CODEC.ADDR] = $80 then  {codec not ready?}
        begin
          Waitforcodec;               {lets wait...}

          if port[CODEC.ADDR] = $80 then   {still not ready?}
          begin
            Waitforcodec;                 {ok, we wait one last time...}

            if timeoutcnt = 0 then           {problem with codec or no AD1848}
            begin
              DetectAD1848 := false;
              exit;
            end;
          end;
        end;



      {Die letzten 4 bit sind beim AD1848 schreibgeschÅtzt (codec version)}
      d1 := ReadCODECReg($C);
      d2 := d1;

      {...mal sehen...}
      if get_bit(d2,0) then set_bit(d2,0,false) else set_bit(d2,0,true);
      WriteCODECReg($C,d2);
      d2 := 0;
      d2 := ReadCODECReg($C);

      if (d1 <> d2) then {Wir konnten ein bit Ñndern, also kein AD1848}
      begin
       DetectAD1848 := false;
      end
      else
      begin
       DetectAD1848 := true;
       codecver := d2 and 15; {Wir melden die letzten 4 Bit, die Codec-Revision zurÅck}
      end;

    end;

  end;



 Function DetectNewChip : boolean;
 {Detects newer codec like AD1845 or CS4231A}
 var dummy,d1,d16 : byte;
 begin
       dummy := readCODECreg($C);    {Read register 12}
       set_bit(dummy,6,true); {Enable Mode 2 on newer chips}
       writeCODECreg($C,dummy);
       waitforcodec;
       if readCODECreg(16) = readCODECreg(0) then {still in AD1848, AD1846 and CS4248 mode}
       begin
        DetectNewChip := false;
       end
       else
       begin                      {AD1845 enhanced feature mode}
         DetectNewChip := true;
         writeCODECreg($C,0);  {switch chip back to AD1848 compatibillity mode}
         waitforcodec;
       end;
  end;







  Function DetectWSS : boolean;
  {Looks for WSS ID}
  begin

   if (port[CODEC.wssport+3] and $3F = 4) or
      (port[CODEC.wssport+3] and $3F = $0F) or
      (port[CODEC.wssport+3] and $3F = 0) then
   begin
    DetectWSS := true;
   end
   else
   begin
    DetectWSS := false;
   end;
  end;


 Procedure MCE(onoff : boolean);
 {Schaltet "Modechange" an/aus}
  var dummy : byte;
      timer : word;
 begin
     timeout := false;
     dummy := port[codec.ADDR];
     set_bit(dummy,6,onoff);     {set Modechange bit}
     timer := $FFFF;
     while (port[codec.ADDR] <> dummy) and (timer > 0) do
     begin
      port[codec.ADDR] := dummy;
      dec(timer);
     end;

     if timer = 0 then timeout := true;

 end;




  Function Init_AD1848 : Boolean;
  {Initialize the AD1848}
  var dummy : byte;
  begin

    asm
     cli
    end;

        if port[CODEC.ADDR] = $80 then {Codec is not ready...}
        begin
          XDelay(1000); {Let's wait one Second}

          WaitforCodec; {Let's do the normal Wait}

          if port[CODEC.ADDR] = $80 then  {Still not ready... :(}
          begin
            Init_AD1848 := false;
            exit;
           end;
         end;


        MCE(true);         {Turn on Modechange bit}

        for z := 0 to 15 do        {Write initial values to the registers}
        begin
          writeCODECReg(z,AD1848_Initialization_values[z]);
          Waitforcodec;         {Wait after each write}
        end;

        MCE(false);        {Turn Modechange bit off}

        writeCODECreg($A,0); {write zero to pin control}

        dummy := readCODECreg(9);
        set_bit(dummy,3,true); {Enable full auto calibration}
        writeCODECreg(9,dummy);

        {Wait until the ACI bit of I11 gets on and then off}
        if not Wait_calibration then
        begin
         Init_AD1848 := false;
         exit;
        end;

        writeCODECreg($C,0);    {Disable Mode 2 on newer chips}

        asm
         sti
        end;
        Init_AD1848 := true;

  end;






 Procedure Calibrate_AD1848;
 var dummy : byte;
     cnt   : word;
 begin

     asm
      cli
     end;

     dummy := readCODECreg($0A); {external mute on}
     dummy := dummy or $40;
     writeCODECreg($0A,dummy);

     for cnt := 0 to $1200 do    {delay to prevent clicks. value from CODEC.ASM, ExtMute, WSS SDK 1.0)}
     begin
      dummy := port[$84];   {a "safe" I/O port}
     end;

     writeCODECreg($0A,0);  {Write zero to Pin Control (why?)}

     MCE(true);             {Enable Mode Change}
     dummy := 0;
     set_bit(dummy,2,true); {Single DMA channel mode}
     set_bit(dummy,3,true); {Enable full Autocalibration}
     writeCODECreg($09,dummy);

     readCODECreg($09);  {...}
     readCODECreg($09);

     {Wait until the ACI bit of I11 gets on and then off}
     if not Wait_calibration then
     begin
       timeout := true;
       exit;
     end;

     MCE(false);        {Disable the "Mode Change" mode}

     dummy := readCODECReg($0A); {external mute off}
     dummy := dummy AND NOT $40;
     writeCODECreg($0A,dummy);

     port[codec.STATUS] := 0;

     writeCODECreg($0F,$FF); {set the lower base count}
     writeCODECreg($0E,$FF); {set the higher base count}
     writeCODECreg($0A,$02); {enable interrupt and pin control}

     asm
      sti
     end;
 end;


Procedure AD1848_SetOutputFormat(freq : word; format : byte; stereo : boolean);
var n,r,fmt,dummy : byte;
    d, dold      : word;
begin
   dold := codec_rates[14].freq;                {suche die am besten passende frequenz}
   for n := 14 downto 0 do
   begin
        d := abs(codec_rates[N].freq-freq);

        if (d < dOld) then
        begin
            r := n;
            dold := d;
        end;
   end;


   fmt := 0;
   fmt := codec_rates[r].divider;
   fmt := fmt shl 1;

   {Select right Clock Source}
   if codec_rates[r].xtal = 2 then Set_bit(fmt,0,true);


   case format of

   COMP_U_LAW:
         begin
           Set_bit(fmt,5,true); {Companded data}
           Set_bit(fmt,6,false); {8 Bit U-law companded}
         end;

   COMP_A_LAW:
         begin
           Set_bit(fmt,5,true); {Companded data}
           Set_bit(fmt,6,true); {8 Bit A-law companded}
         end;

   PCM_U_8BIT:
         begin
           Set_bit(fmt,5,false); {Linear PCM data}
           Set_bit(fmt,6,false); {8 Bit unsigned PCM}
         end;

  PCM_COMPL_16BIT:
         begin
           Set_bit(fmt,5,false); {Linear PCM data}
           Set_bit(fmt,6,true); {16 Bit Twos-Complement PCM}
         end;
      end;

     if stereo then Set_bit(fmt,4,true);


     MCE(true);

     WriteCODECReg($8,fmt);

     {  Now according to GUS MAX SDK source we need to read from the CODEC
        data port twice. Don't ask me why, but I really hope this solves
        the problem in setting the sample rate...   }

     readCODECreg($08);  {...}
     readCODECreg($08);

     Waitforcodec;


     MCE(false);

     {Wait until the ACI bit of I11 gets on and then off}
     Calibrate_AD1848;
    end;


Procedure AD1848_GetOutputFormat(var freq : word;var format : byte;var sm : boolean);
var divider,n,dummy,xtal : byte;
begin
   sm := false;
   dummy := readCODECreg($08);
   if get_bit(dummy,5) = true then {Companded data}
   begin
      if get_bit(dummy,6) = false then
      begin
        format := COMP_U_LAW; {8 Bit U-law companded}
      end
      else
      begin
        format := COMP_A_LAW; {8 Bit A-law companded}
      end;
   end
   else           {Linear PCM data}
   begin
       if get_bit(dummy,6) = false then {8 Bit unsigned PCM}
       begin
         format := PCM_U_8BIT;
       end
       else         {16 Bit Twos-Complement PCM}
       begin
         format := PCM_COMPL_16BIT;
       end;
   end;

   if Get_bit(dummy,4) then sm := true;

   dummy := dummy and 15; {clear bit 4 to 7}
   xtal := ord(Get_bit(dummy,0))+1;
   divider := dummy shr 1;
   for n := 1 to 14 do
   begin
    if (codec_rates[n].divider = divider) and
       (codec_rates[n].xtal = xtal) then
    begin
      freq := codec_rates[n].freq;
      break;
    end;
   end;
  end;


  Procedure SetDigitalMix(Enable : Boolean; Volume : byte);
  var dummy : byte;
  begin
     dummy := 0;
     if volume > 63 then volume := 63;
     volume := 63-volume;

     dummy := volume shl 2;
     set_bit(dummy,0,enable);
     writeCODECReg($0D,dummy);
  end;


  Function GetInputDevice : byte;
   var dummy : byte;
  begin
    dummy := readCODECReg($00);
    if dummy = 0 then
    begin
     dummy := readCODECReg($01);
    end;

      if (get_bit(dummy,7) = false) and (get_bit(dummy,6) = false) then
      begin
       GetInputDevice := LINE;
      end;
      if (get_bit(dummy,7) = false) and (get_bit(dummy,6) = true) then
      begin
       GetInputDevice := AUX1;
      end;
      if (get_bit(dummy,7) = true) and (get_bit(dummy,6) = false) then
      begin
       GetInputDevice := MIC;
      end;
      if (get_bit(dummy,7) = true) and (get_bit(dummy,6) = true) then
      begin
       GetInputDevice := POSTMX;
      end;
   end;





  Procedure SetInput(Device, Channel, Volume : byte; MicGain : Boolean);
  var dummy : byte;
  begin

      dummy := 0;
      if volume > 15 then volume := 15;
      volume := 15-volume;

      dummy := volume;

      if device = LINE then    {00}
      begin
        set_bit(dummy,7,false);
        set_bit(dummy,6,false);
      end;

      if device = AUX1i then    {01}
      begin
        set_bit(dummy,7,false);
        set_bit(dummy,6,true);
      end;

      if device = MIC then      {10}
      begin
       set_bit(dummy,7,true);
       set_bit(dummy,6,false);
      end;

      if device = POSTMX then   {11}
      begin
       set_bit(dummy,7,true);
       set_bit(dummy,6,true);
      end;

      set_bit(dummy,5,micgain);

      Case Channel Of
      Left         :
                   begin
                     writeCODECReg($00,dummy);
                   end;
      Right        :
                   begin
                     writeCODECReg($01,dummy);
                   end;

      LeftAndRight :
                   begin
                     writeCODECReg($00,dummy);
                     writeCODECReg($01,dummy);
                   end;
      end;

  end;



 Procedure Playback(startstop : Boolean);
 var dummy : byte;
 begin
   dummy :=  0;
   set_bit(dummy,0,startstop);  {set PEN}
   writeCODECReg($9,dummy);
   writeCODECreg($B,0); {reset dma underran etc}
   writeCODECreg($A,0); {disable interrupt}
 end;

 Procedure Capture(startstop : Boolean);
 var dummy : byte;
 begin
   dummy :=  0;
   set_bit(dummy,1,startstop);  {set CEN}
   writeCODECReg($09,dummy);
 end;


 Procedure MuteDAC(Channel : byte; muteit : Boolean);
 var dummy : byte;
  begin

      Case Channel Of
      Left         :
                   begin
                     dummy := readCODECreg($06);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($06,dummy);          {mute/unmute left channel}
                   end;
      Right        :
                   begin
                     dummy := readCODECreg($07);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($07,dummy);          {mute/unmute right channel}
                   end;

      LeftAndRight :
                   begin
                     dummy := readCODECreg($06);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($06,dummy);          {mute/unmute left channel}
                     dummy := 0;
                     dummy := readCODECreg($07);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($07,dummy);          {mute/unmute right channel}
                   end;
      end;
  end;


 Procedure MuteAUX1(Channel : byte; muteit : Boolean);
  var dummy : byte;
  begin

      Case Channel Of
      Left         :
                   begin
                     dummy := readCODECreg($02);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($02,dummy);          {mute/unmute left channel}
                   end;
      Right        :
                   begin
                     dummy := readCODECreg($03);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($03,dummy);          {mute/unmute right channel}
                   end;

      LeftAndRight :
                   begin
                     dummy := readCODECreg($02);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($02,dummy);          {mute/unmute left channel}
                     dummy := 0;
                     dummy := readCODECreg($03);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($03,dummy);          {mute/unmute right channel}
                   end;
      end;
  end;

  Procedure MuteAUX2(Channel : byte; muteit : Boolean);
  var dummy : byte;
  begin
     dummy := 0;

      Case Channel Of
      Left         :
                   begin
                     dummy := readCODECreg($04);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($04,dummy);          {mute/unmute left channel}
                   end;
      Right        :
                   begin
                     dummy := readCODECreg($05);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($05,dummy);          {mute/unmute right channel}
                   end;

      LeftAndRight :
                   begin
                     dummy := readCODECreg($04);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($04,dummy);          {mute/unmute left channel}
                     dummy := 0;
                     dummy := readCODECreg($05);
                     set_bit(dummy,7,muteit);
                     writeCODECReg($05,dummy);          {mute/unmute right channel}
                   end;
      end;
  end;



Procedure AD1848_SetVolume(VolumeType, Channel, Volume : Byte);
var reg,reg2 : byte;
begin


    if volume > 30 then volume := 30;
    volume := 30-volume;

    {The codec has only attenuation regs, so we totally mute outputs to get
     silence with volume 0 }

    if (volume = 30) then
    begin
      set_bit(volume,7,true);
    end;


    Case Channel Of
      Left         :
                   begin
                     WriteCODECReg(VolumeType,volume);
                   end;

      Right        :
                   begin
                     WriteCODECReg(VolumeType+1,volume);
                   end;

      LeftAndRight :
                   begin
                     WriteCODECReg(VolumeType,volume);
                     WriteCODECReg(VolumeType+1,volume);
                   end;
    end;

end;


Function AD1848_GetVolume(VolumeType, Channel : byte) : byte;
var  Volume,vl,vr : Byte;
begin
   vl := ReadCODECReg(VolumeType);
   vr := ReadCODECReg(VolumeType+1);

   vl := vl and 31;
   vr := vr and 31;

    Case Channel Of
      Left         : volume := vl;
      Right        : volume := vr;
      LeftAndRight : volume := (vr+vl) div 2;
   end;

  AD1848_GetVolume := 30-volume;
end;


Function AD1848_GetGain(Channel : byte) : byte;
var  Volume,vl,vr : Byte;
begin
   vl := ReadCODECReg($00);
   vr := ReadCODECReg($01);
   vl := vl and 15;
   vr := vr and 15;

    Case Channel Of
      Left         : volume := vl;
      Right        : volume := vr;
      LeftAndRight : volume := (vr+vl) div 2;
   end;

  AD1848_GetGain := 15-volume;
end;


end.