{Low level driver for OPTi 82C929A controller chip
 V 1.0 (c) 23.12.2018 by Jan Knipperts

Inspired by MAD16.C by Hannu Savolainen}


Unit Opti929;

interface

uses misc,ad1848;

const

 {Ports of the chip}
 MC1_PORT       = $F8D;	{WSS Port, CD-ROM interface type, joystick */}
 MC2_PORT	= $F8E;	{CD-ROM address, CD IRQ, CD DMA, plus OPL4 bit}
 MC3_PORT	= $F8F; {SB IRQ, SB DMA, FreqMAp, SB adress, Chip-Rev/GP Mode}
 MC4_PORT       = $F90; {GP OUT, OUTMX, FMCLK, SILENCE, SB Version}
 MC5_PORT       = $F91; {Shadow protect, Codec Access, FIFO, CODEC select}
 MC6_PORT       = $F92; {MPU, MPU Port, MPU IRQ}
 PASSWD_REG	= $F8F;
 PASSWORD       = $E3; {Every OPTi Chip has its own code for register access.
                        For the 929 it is E3h}

 {     From the manual:
       The 82C929 occupies I/O ports 0xf8d to 0xf93 (fixed locations).
       All ports are inactive by default. They can be activated by
       writing 0xE3 to the password register. The password is valid
       only until the next I/O read or write.
}

 SONY = 1;
 MITSUMI = 2;
 PANASONIC = 3;
 IDE = 4;



type
OPTI929config       = record
  initmode    : byte;   {Modus SB/WSS}
  powerdwn    : byte;   {Stromsparmodus}
  fmclk       : byte;   {OPL 2 oder 3 Taktung}
  silence     : byte;   {Soundausgabe an/aus}
  Cfix        : byte;   {Delay fix fr Crystal Chips}
  shprotect   : byte;   {Shadow Register protection}
  access      : byte;   {Zugriff auf Codec auch im SB Modus?}

  CDTYPE      : byte;
  CDBASE      : word;   {Port fr CD-ROM}
  OPL         : byte;   {OPL 3/4}
  CDIRQ       : byte;   {IRQ fr CD-ROM}
  CDDMA       : byte;   {DMA fr CD-ROM}

  SBBase      : word;   {SB Port}
  SBIRQ       : byte;   {SB IRQ}
  SBDMA       : byte;   {SB DMA}
  FMAP        : byte;   {SB Frequencymapping with one/both xtals}
  SBVER       : byte;   {SB DSP Version}
  FIFO        : byte;   {SB command FIFO}
  ADPCM       : byte;   {SB ADPCM support}
  SBMIX       : byte;   {SB Mixer emulation}

  WSSBase     : word;   {WSS Port}
  WSSDMA      : byte;   {WSS playback DMA}
  WSSIRQ      : byte;   {WSS IRQ}

  GPEN        : byte;   {GamePort an/aus}
  GPMode      : byte;   {Game Port Timer.  0 fr Extern, 1 fr Intern}
  GPOUT       : byte;   {General purpose output}
  OUTMX       : byte;   {Mix Midi / gameport outputs}

  MPU401      : byte;  {MPU401 an/aus}
  MPUBASE     : word;  {MPU401 Port}
  MPUIRQ      : byte;  {MPU401 IRQ}
 end;

var
 OPTIcfg      : OPTI929config;
 SB,WSS       : Boolean;

Function  read929(portnum : word) : byte;
{Reads one byte from the given register}

Procedure write929(portnum : word; value : byte);
{Writes one byte to the controllers register}

Function  Detect929 : boolean;
{Is there an OPTi 82C929A Controller?}

Procedure SetWSSMode(cfg : OPTI929config);
{Sets Controller into WSS mode}

Procedure SetupWSSPort(cfg : OPTI929config);
{Configures the WSS main I/O Port with the actual settings}

Procedure SetSBMode(cfg : OPTI929config);
{Sets Controller to Sound Blaster Pro Mode}

Procedure GetCfg(var cfg : OPTI929config);
{Reads the actual configuration from the Controller}

Procedure SetInitValues;
{Sets the default values found in the datasheet}

Function SBMode : boolean;
{Returns true if the controller is in Sound Blaster mode}

Procedure Codec_Access(value : boolean);
{Enable / Disbale access to the codec in SB mode}

Procedure Protect_Shadowregs(value : boolean);
{Writeprotect shadowed codec register?}

Procedure Powerdown929(on : boolean);
{Enable/Disable powerdown mode}

Procedure ChipTest929(on : boolean);
{Enable/Disable Chip-Test-Mode}

Procedure Silence929(on : boolean);
{Mute/unmute all audio}

Procedure SBMixer(on : boolean);
{Enable/Disbale Mixer emulation and automatic volume control in SB Mode}

Procedure SBADPCM(on : boolean);
{Enable/Disbale ADPC decompression feature}

Function ChipRevision_929 : byte;
{Returns the Revision of the 82c929}

implementation

procedure set_bit(var b:byte; bit:integer; value:boolean);
{Fast routine to toggle a single bit}
begin
   if value then
      b:= b or (1 shl bit)
   else
      b:= b and not (1 shl bit);
end;


Function get_Bit(b, n : Byte) : boolean;
{Returns the state of a bit}
begin
  get_Bit := boolean(odd(b shr n));
end;



Function read929(portnum : word) : byte;
var
	tmp : byte;

begin
	port[PASSWD_REG] := PASSWORD;
	tmp := port[portnum];
	read929 := tmp;
end;

procedure write929(portnum : word; value : byte);
begin
  port[PASSWD_REG] := PASSWORD;
  port[portnum] := value and $FF;
end;


Function CODECBase : word;
{Finds and returns the base I/O Port of the codec}
var mc1data : byte;
    base    : word;
begin
 mc1data := read929(MC1_PORT);

 if (getbit(mc1data,4) = 0) and (getbit(mc1data,5) = 0) then
  Base := $530;

 if (getbit(mc1data,4) = 1) and (getbit(mc1data,5) = 0) then
  Base := $E80;
 
 if (getbit(mc1data,4) = 0) and (getbit(mc1data,5) = 1) then
  Base := $F40;
 
 if (getbit(mc1data,4) = 1) and (getbit(mc1data,5) = 1) then
  Base := $604;
 
 CODECBase := base;
end;



Function Detect929 : boolean;
var tmp, tmp2,tmp3, bit : byte;
    i, portnum     : word;
begin
{ First we check if we can read from a register with the password}

  tmp := read929(MC1_PORT);

if (tmp = $FF) then {Unfortunately we get only bus float... }
   begin
        Detect929 := false;
        exit;
   end;

  {Now check that the gate is closed on first I/O after writing
   the password. (This is how a MAD16 compatible card works)}

   tmp2 := port[MC1_PORT];
   if (tmp2 = tmp) then	{It didn't close}
   begin
    Detect929 := false;
    exit;
   end;
   
   {First hurdle cleared, password is correct and the chip works as expected}

{Finally let's check the revisionid bits in register MC3. Just to be save}
   tmp3 := read929(MC3_PORT);
   {Bits 0 and 1 store the ID of the 82C929.
    Should be "10" for 82C929A}

   if (getbit(tmp3,0) <> 0) and (getbit(tmp3,1) <> 1) then
   begin
    Detect929 := false;
    exit;
   end;

   Detect929 := true;
end;


  Procedure SetupWSSPort(cfg : OPTI929config);
  var wss_irq, wss_port, wss_dma : byte;
      wss_cfg                     : byte;
  begin
    wss_irq := 0;

    if cfg.wssirq = 7 then
    wss_irq := 1;
    if cfg.wssirq = 9 then
    wss_irq := 2;
    if cfg.wssirq = 10 then
    wss_irq := 3;
    if cfg.wssirq = 11 then
    wss_irq := 4;

    wss_dma := 0;

     {Only singe DMA mode supported for now}
      case cfg.wssdma of
       0:  wss_dma := 1;
       1:  wss_dma := 2;
       3:  wss_dma := 3;
      end;

    wss_cfg := 0;
    wss_cfg := wss_irq;
    wss_cfg := wss_cfg shl 3;
    wss_cfg := wss_cfg or wss_dma;
    if cfg.wssirq = $FF then set_bit(wss_cfg,6,true); {auto interrupt select}
    if getbit(port[cfg.WSSbase],7) = 1 then set_bit(wss_cfg,7,true);

    port[cfg.WSSbase] := wss_cfg;
  end;




Procedure SetWSSMode(cfg : OPTI929config);
{Sets the Controller in Windows Sound System mode using the configuration provided in "cfg"}

var mc1data,
    mc2data,
    mc3data,
    mc4data,
    mc5data,
    mc6data  : byte;    {Variables for the register values}


begin
 mc1data := 0;
 set_bit(mc1data,7,true);  {set WSS mode}
 if cfg.powerdwn = 1 then set_bit(mc1data,6,true); {powerdown mode}

 case cfg.WSSbase of
   $530:
    begin
     set_bit(mc1data,4,false);
     set_bit(mc1data,5,false);
    end;

   $E80:
    begin
     set_bit(mc1data,4,true);
     set_bit(mc1data,5,false);
    end;

   $F40:
    begin
     set_bit(mc1data,4,false);
     set_bit(mc1data,5,true);
    end;

   $604:
   begin
     set_bit(mc1data,4,true);
     set_bit(mc1data,5,true);
    end;
 end;

 case cfg.CDTYPE of

  SONY:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,false);
    set_bit(mc1data,1,true);
   end;

  MITSUMI:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,true);
    set_bit(mc1data,1,false);
   end;

  PANASONIC:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,true);
    set_bit(mc1data,1,true);
   end;

  IDE:
   begin
    set_bit(mc1data,3,true);
    set_bit(mc1data,2,false);
    set_bit(mc1data,1,false);
   end;

  $FF:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,false);
    set_bit(mc1data,1,false);
   end;
  end;

 if cfg.gpen = 1 then
  set_bit(mc1data,0,false) {1 means off here}
 else
  set_bit(mc1data,0,true);
 
 mc2data := 0;

 case cfg.CDBASE of

 $340:
 begin
    set_bit(mc2data,7,false);
    set_bit(mc2data,6,false);
 end;

 $330:
 begin
    set_bit(mc2data,7,false);
    set_bit(mc2data,6,true);
 end;

 $360:
 begin
    set_bit(mc2data,7,true);
    set_bit(mc2data,6,false);
 end;

 $320:
 begin
    set_bit(mc2data,7,true);
    set_bit(mc2data,6,true);
 end;
 end;


 case cfg.cddma of

 3:
 begin
    set_bit(mc2data,0,false);
    set_bit(mc2data,1,false);
 end;

 0:
 begin
    set_bit(mc2data,0,false);
    set_bit(mc2data,1,true);
 end;

 1:
 begin
    set_bit(mc2data,0,true);
    set_bit(mc2data,1,false);
 end;

 $FF:
 begin
    set_bit(mc2data,0,true);
    set_bit(mc2data,1,true);
 end;
end;



 case cfg.CDIRQ of

 5:
  begin
    set_bit(mc2data,4,false);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,true);
  end;

 7:
  begin
    set_bit(mc2data,4,false);
    set_bit(mc2data,3,true);
    set_bit(mc2data,2,false);
  end;

 9:
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,false);
  end;

 10:
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,true);
  end;

 11:
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,true);
    set_bit(mc2data,2,false);
  end;

 $FF:                           {CD-ROM support OFF}
  begin
    set_bit(mc2data,4,false);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,false);
  end;

 $FA:                            {Special Chip-Test-Mode}
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,true);
    set_bit(mc2data,2,true);
  end;

 end;

 if cfg.opl = 4 then set_bit(mc2data,5,true);

 mc3data := 0;

 case cfg.SBirq of
 7:
   begin
     set_bit(mc3data,6,false);
     set_bit(mc3data,7,false);
   end;

 5:
   begin
     set_bit(mc3data,6,false);
     set_bit(mc3data,7,true);
   end;

 10:
   begin
     set_bit(mc3data,6,true);
     set_bit(mc3data,7,false);
   end;

  {IRQ is disabled}
 $FF:
   begin
     set_bit(mc3data,6,true);
     set_bit(mc3data,7,true);
   end;

 end;

 case cfg.SBdma of
 0:
  begin
     set_bit(mc3data,4,true);
     set_bit(mc3data,5,false);
   end;

 1:
   begin
     set_bit(mc3data,4,false);
     set_bit(mc3data,5,false);
   end;

 3:
   begin
     set_bit(mc3data,4,false);
     set_bit(mc3data,5,true);
   end;

  {DMA is disabled}
 $FF:
   begin
     set_bit(mc3data,4,true);
     set_bit(mc3data,5,true);
   end;

 end;

 if cfg.fmap = 1 then set_bit(mc3data,3,true);
 if cfg.gpmode = 1 then set_bit(mc3data,1,true);


 mc4data := 0;

 set_bit(mc4data,7,true);     {reserved bits}
 set_bit(mc4data,5,true);
 if cfg.silence = 1 then set_bit(mc4data,2,true);   {silence}

 if cfg.gpout > 0 then set_bit(mc4data,6,true);
 if cfg.outmx > 0 then set_bit(mc4data,4,true);
 if cfg.fmclk = 2 then set_bit(mc4data,3,true);


 set_bit(mc5data,7,true);     {set reserved bits of MC5}
 set_bit(mc5data,6,false);
 set_bit(mc5data,2,true);
 set_bit(mc5data,0,true);


 if cfg.shprotect = 1 then  set_bit(mc5data,5,true);
 if cfg.access = 1 then  set_bit(mc5data,4,true);

 if cfg.fifo = 1 then  set_bit(mc5data,3,true);
 if cfg.cfix = 1 then  set_bit(mc5data,1,true);

 mc6data := 0;

 {Set the reserved bits of byte 6}
 set_bit(mc6data,2,false);
 set_bit(mc6data,1,true);
 set_bit(mc6data,0,true);


 if cfg.mpu401 = 1 then  set_bit(mc6data,7,true);

 case cfg.MPUbase of
   $330:
    begin
     set_bit(mc6data,5,false);
     set_bit(mc6data,6,false);
    end;

   $320:
    begin
     set_bit(mc6data,5,true);
     set_bit(mc6data,6,false);
    end;

   $310:
    begin
     set_bit(mc6data,5,false);
     set_bit(mc6data,6,true);
    end;

   $300:
   begin
     set_bit(mc6data,5,true);
     set_bit(mc6data,6,true);
    end;
 end;

 case cfg.MPUIRQ of
 9:
   begin
     set_bit(mc6data,3,false);
     set_bit(mc6data,4,false);
   end;

 10:
   begin
     set_bit(mc6data,3,true);
     set_bit(mc6data,4,false);
   end;

 5:
   begin
     set_bit(mc6data,3,false);
     set_bit(mc6data,4,true);
   end;

 7:
   begin
     set_bit(mc6data,3,true);
     set_bit(mc6data,4,true);
   end;

 end;

{Write new values to the chip}
 write929(MC1_PORT,mc1data);
 write929(MC2_PORT,mc2data);
 write929(MC3_PORT,mc3data);
 write929(MC4_PORT,mc4data);
 write929(MC5_PORT,mc5data);
 write929(MC6_PORT,mc6data);
 
 {Calculate addresses for codec access}
 CODEC.WSSPort := cfg.WSSBase;
 CODEC.ADDR    := cfg.WSSBase+4;
 CODEC.DATA    := cfg.WSSBase+5;
 CODEC.STATUS  := cfg.WSSBase+6;
 CODEC.PIO     := cfg.WSSBase+7;
 
 {Set up the WSS main I/O port}
 SetupWSSPort(cfg);
end;




Function SBMode : boolean;
{Is the controller in Sound Blaster mode?}

var 
  mc1data : byte;
begin
 mc1data := read929(MC1_PORT);

 if getbit(mc1data,7) = 1 then {WSS mode?}
 begin
  SBMode := false;
 end
 else
 begin
  SBMode := true;
 end;

end;

Procedure GetCFG(var cfg : OPTI929config);
{Reads all readable register values from the controller and stores actual configuration in "cfg"}

var mc1data,
    mc2data,
    mc3data,
    mc4data,
    mc5data,
    mc6data,
    wssdata : byte;



begin
 mc1data := read929(MC1_PORT);
 mc2data := read929(MC2_PORT);
 mc3data := read929(MC3_PORT);
 mc4data := read929(MC4_PORT);
 mc5data := read929(MC5_PORT);
 mc6data := read929(MC6_PORT);

 fillchar(cfg,sizeof(cfg),0);

 if getbit(mc1data,7) = 1 then cfg.initmode := 1;  {WSS mode}
 if getbit(mc1data,6) = 1 then cfg.powerdwn := 1;  {powerdown}
 if getbit(mc1data,0) = 0 then cfg.gpen := 1;  {Gameport enable (1 means off here)}
 if getbit(mc3data,3) = 1 then cfg.fmap := 1; {Frequency Mapping}



 {CD-ROM:}

 if (getbit(mc1data,3) = 0)
 and (getbit(mc1data,2) = 0)
 and (getbit(mc1data,1) = 1) then
     cfg.CDTYPE := SONY;

 if (getbit(mc1data,3) = 0)
 and (getbit(mc1data,2) = 1)
 and (getbit(mc1data,1) = 0) then
     cfg.CDTYPE := MITSUMI;

 if (getbit(mc1data,3) = 0)
 and (getbit(mc1data,2) = 1)
 and (getbit(mc1data,1) = 1) then
     cfg.CDTYPE := PANASONIC;

 if (getbit(mc1data,3) = 1)
 and (getbit(mc1data,2) = 0)
 and (getbit(mc1data,1) = 0) then
     cfg.CDTYPE := IDE;


 if (getbit(mc1data,3) = 0)
 and (getbit(mc1data,2) = 0)
 and (getbit(mc1data,1) = 0) then
     cfg.CDTYPE := $FF;


 {CD I/O-Port}

 if (getbit(mc2data,7) = 0) and (getbit(mc2data,6) = 0) then
     cfg.CDBASE := $340;

 if (getbit(mc2data,7) = 0) and (getbit(mc2data,6) = 1) then
     cfg.CDBASE := $330;

 if (getbit(mc2data,7) = 1) and (getbit(mc2data,6) = 0) then
     cfg.CDBASE := $360;

 if (getbit(mc2data,7) = 1) and (getbit(mc2data,6) = 1) then
     cfg.CDBASE := $320;


 {CD DMA}

 if (getbit(mc2data,0) = 0) and (getbit(mc2data,1) = 0) then
     cfg.CDDMA := 3;

 if (getbit(mc2data,0) = 0) and (getbit(mc2data,1) = 1) then
     cfg.CDDMA := 0;

 if (getbit(mc2data,0) = 1) and (getbit(mc2data,1) = 0) then
     cfg.CDDMA := 1;

 if (getbit(mc2data,0) = 1) and (getbit(mc2data,1) = 1) then
     cfg.CDDMA := $FF;


 {CD IRQ}

 if (getbit(mc2data,4) = 0)
 and (getbit(mc2data,3) = 0)
 and (getbit(mc2data,2) = 1) then
     cfg.CDIRQ := 5;

 if (getbit(mc2data,4) = 0)
 and (getbit(mc2data,3) = 1)
 and (getbit(mc2data,2) = 0) then
     cfg.CDIRQ := 7;

 if (getbit(mc2data,4) = 1)
 and (getbit(mc2data,3) = 0)
 and (getbit(mc2data,2) = 0) then
     cfg.CDIRQ := 9;

 if (getbit(mc2data,4) = 1)
 and (getbit(mc2data,3) = 0)
 and (getbit(mc2data,2) = 1) then
     cfg.CDIRQ := 10;

 if (getbit(mc2data,4) = 1)
 and (getbit(mc2data,3) = 1)
 and (getbit(mc2data,2) = 0) then
     cfg.CDIRQ := 11;

 if (getbit(mc2data,4) = 0)
 and (getbit(mc2data,3) = 0)
 and (getbit(mc2data,2) = 0) then
     cfg.CDIRQ := $FF;

 if (getbit(mc2data,4) = 1)
 and (getbit(mc2data,3) = 1)
 and (getbit(mc2data,2) = 1) then
     cfg.CDIRQ := $FA;                 {Chip-Test-Mode}


 {WSS:}

 {WSS Base}

   if (getbit(mc1data,4) = 0) and (getbit(mc1data,5) = 0) then
     cfg.WSSBase := $530;

   if (getbit(mc1data,4) = 1) and (getbit(mc1data,5) = 0) then
     cfg.WSSBase := $E80;

   if (getbit(mc1data,4) = 0) and (getbit(mc1data,5) = 1) then
     cfg.WSSBase := $F40;

   if (getbit(mc1data,4) = 1) and (getbit(mc1data,5) = 1) then
     cfg.WSSBase := $604;


   wssdata := port[cfg.WSSbase];

   {WSS IRQ}


   if (getbit(wssdata,3) = 0) and
      (getbit(wssdata,4) = 0) and
      (getbit(wssdata,5) = 0) then
     cfg.WSSIrq := $FF;

   if (getbit(wssdata,3) = 1) and
      (getbit(wssdata,4) = 0) and
      (getbit(wssdata,5) = 0) then
     cfg.WSSIrq := 7;

   if (getbit(wssdata,3) = 0) and
      (getbit(wssdata,4) = 1) and
      (getbit(wssdata,5) = 0) then
     cfg.WSSIrq := 9;

   if (getbit(wssdata,3) = 1) and
      (getbit(wssdata,4) = 1) and
      (getbit(wssdata,5) = 0) then
      cfg.WSSIrq := 10;

   if (getbit(wssdata,3) = 0) and
      (getbit(wssdata,4) = 0) and
      (getbit(wssdata,5) = 1) then
      cfg.WSSIrq := 11;




  {WSS DMA}

   if (getbit(wssdata,0) = 0) and
      (getbit(wssdata,1) = 0) and
      (getbit(wssdata,2) = 0) then
   begin
     cfg.WSSDMA  := $FF;
   end;

   if (getbit(wssdata,0) = 1) and
      (getbit(wssdata,1) = 0) and
      (getbit(wssdata,2) = 0) then
   begin
     cfg.WSSDMA  := 0;
   end;

   if (getbit(wssdata,0) = 0) and
      (getbit(wssdata,1) = 1) and
      (getbit(wssdata,2) = 0) then
   begin
     cfg.WSSDMA  := 1;
   end;

   if (getbit(wssdata,0) = 1) and
      (getbit(wssdata,1) = 1) and
      (getbit(wssdata,2) = 0) then
   begin
     cfg.WSSDMA  := 3;
   end;


   if (getbit(wssdata,0) = 0) and
      (getbit(wssdata,1) = 0) and
      (getbit(wssdata,2) = 1) then
   begin
     cfg.WSSDMA  := $FF;
   end;

   if (getbit(wssdata,0) = 1) and
      (getbit(wssdata,1) = 0) and
      (getbit(wssdata,2) = 1) then
   begin
     cfg.WSSDMA  := 0;
   end;

   if (getbit(wssdata,0) = 0) and
      (getbit(wssdata,1) = 1) and
      (getbit(wssdata,2) = 1) then
   begin
     cfg.WSSDMA  := 1;
   end;

   if (getbit(wssdata,0) = 1) and
      (getbit(wssdata,1) = 1) and
      (getbit(wssdata,2) = 1) then
   begin
     cfg.WSSDMA  := 3;
   end;

 {SB}


 {SB IRQ}
 if (getbit(mc3data,6) = 0) and (getbit(mc3data,7) = 0) then
  cfg.SBirq := 7;

 if (getbit(mc3data,6) = 0) and (getbit(mc3data,7) = 1) then
  cfg.SBirq := 5;

 if (getbit(mc3data,6) = 1) and (getbit(mc3data,7) = 0) then
  cfg.SBirq := 10;

 if (getbit(mc3data,6) = 1) and (getbit(mc3data,7) = 1) then
  cfg.SBirq := $FF;


 {SB DMA}

 if (getbit(mc3data,4) = 1) and (getbit(mc3data,5) = 0) then
  cfg.SBdma := 0;

 if (getbit(mc3data,4) = 0) and (getbit(mc3data,5) = 0) then
  cfg.SBdma := 1;

 if (getbit(mc3data,4) = 0) and (getbit(mc3data,5) = 1) then
  cfg.SBdma := 3;

 if (getbit(mc3data,4) = 1) and (getbit(mc3data,5) = 1) then
  cfg.SBdma := $FF;

 if (getbit(mc3data,2) = 1) then
 begin
  cfg.sbbase := $240;
 end
 else
 begin
  cfg.sbbase := $220;
 end;

 if (getbit(mc4data,3) = 1) then
 begin
  cfg.opl := 2;
 end
 else
 begin
  cfg.opl := 3;
 end;

 if (getbit(mc6data,7) = 1) then
 begin
  cfg.mpu401 := 1;
 end
 else
 begin
  cfg.mpu401 := 0;
 end;

 if (getbit(mc4data,0) = 1) and (getbit(mc4data,1) = 0) then
 begin
  cfg.SBver := 1;
 end;
 if (getbit(mc4data,0) = 0) and (getbit(mc4data,1) = 0) then
 begin
  cfg.SBver := 2;
 end;
 if (getbit(mc4data,0) = 0) and (getbit(mc4data,1) = 1) then
 begin
  cfg.SBver := 3;
 end;
 if (getbit(mc4data,0) = 1) and (getbit(mc4data,1) = 1) then
 begin
  cfg.SBver := 4;
 end;

 if (getbit(mc4data,6) = 1) then
 begin
  cfg.gpout := 1;
 end
 else
 begin
  cfg.gpout := 0;
 end;

 if (getbit(mc4data,4) = 1) then
 begin
  cfg.outmx := 1;
 end
 else
 begin
  cfg.outmx := 0;
 end;



 if (getbit(mc5data,5) = 1) then
 begin
  cfg.shprotect := 1;
 end
 else
 begin
  cfg.shprotect := 0;
 end;

 if (getbit(mc5data,4) = 1) then
 begin
  cfg.access := 1;
 end
 else
 begin
  cfg.access := 0;
 end;

 if (getbit(mc5data,3) = 1) then
 begin
  cfg.fifo := 1;
 end
 else
 begin
  cfg.fifo := 0;
 end;

 if (getbit(mc5data,1) = 1) then
 begin
  cfg.cfix := 1;
 end
 else
 begin
  cfg.cfix := 0;
 end;

 if (getbit(mc6data,7) = 1) then
 begin
  cfg.mpu401 := 1;
 end
 else
 begin
  cfg.mpu401 := 0;
 end;


 if (getbit(mc6data,5) = 0) and (getbit(mc6data,6) = 0) then
 begin
  cfg.MPUbase := $330;
 end;
 if (getbit(mc6data,5) = 1) and (getbit(mc6data,6) = 0) then
 begin
  cfg.MPUbase := $320;
 end;
 if (getbit(mc6data,5) = 0) and (getbit(mc6data,6) = 1) then
 begin
  cfg.MPUbase := $310;
 end;
 if (getbit(mc6data,5) = 1) and (getbit(mc6data,6) = 1) then
 begin
  cfg.MPUbase := $300;
 end;


 if (getbit(mc6data,3) = 0) and (getbit(mc6data,4) = 0) then
 begin
  cfg.MPUIRQ := 9;
 end;
 if (getbit(mc6data,3) = 1) and (getbit(mc6data,4) = 0) then
 begin
  cfg.MPUIRQ := 10;
 end;
 if (getbit(mc6data,3) = 0) and (getbit(mc6data,4) = 1) then
 begin
  cfg.MPUIRQ := 5;
 end;
 if (getbit(mc6data,3) = 1) and (getbit(mc6data,4) = 1) then
 begin
  cfg.MPUIRQ := 7;
 end;

end;







Procedure SetSBMode(cfg : OPTI929config);
{Sets the controller to Sound Blaster mode using the configuration provided in "cfg"}


var mc1data,
    mc2data,
    mc3data,
    mc4data,
    mc5data,
    mc6data  : byte;



begin
 mc1data := 0;
 set_bit(mc1data,7,false); {set SB Pro mode}
 if cfg.powerdwn = 1 then set_bit(mc1data,6,true); {powerdown mode}
 set_bit(mc1data,4,false); {WSS Base is not used this time}
 set_bit(mc1data,5,false);


case cfg.CDTYPE of

  SONY:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,false);
    set_bit(mc1data,1,true);
   end;

  MITSUMI:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,true);
    set_bit(mc1data,1,false);
   end;

  PANASONIC:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,true);
    set_bit(mc1data,1,true);
   end;

  IDE:
   begin
    set_bit(mc1data,3,true);
    set_bit(mc1data,2,false);
    set_bit(mc1data,1,false);
   end;

  $FF:
   begin
    set_bit(mc1data,3,false);
    set_bit(mc1data,2,false);
    set_bit(mc1data,1,false);
   end;
  end;


 if cfg.gpen = 1 then
 begin
  set_bit(mc1data,0,false); {1 means off here}
 end
 else
 begin
  set_bit(mc1data,0,true);
 end;


 mc2data := 0;

 case cfg.CDBASE of

 $340:
 begin
    set_bit(mc2data,7,false);
    set_bit(mc2data,6,false);
 end;

 $330:
 begin
    set_bit(mc2data,7,false);
    set_bit(mc2data,6,true);
 end;

 $360:
 begin
    set_bit(mc2data,7,true);
    set_bit(mc2data,6,false);
 end;

 $320:
 begin
    set_bit(mc2data,7,true);
    set_bit(mc2data,6,true);
 end;
 end;


 case cfg.cddma of

 3:
 begin
    set_bit(mc2data,0,false);
    set_bit(mc2data,1,false);
 end;

 0:
 begin
    set_bit(mc2data,0,false);
    set_bit(mc2data,1,true);
 end;

 1:
 begin
    set_bit(mc2data,0,true);
    set_bit(mc2data,1,false);
 end;

 $FF:
 begin
    set_bit(mc2data,0,true);
    set_bit(mc2data,1,true);
 end;
end;



 case cfg.CDIRQ of

 5:
  begin
    set_bit(mc2data,4,false);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,true);
  end;

 7:
  begin
    set_bit(mc2data,4,false);
    set_bit(mc2data,3,true);
    set_bit(mc2data,2,false);
  end;

 9:
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,false);
  end;

 10:
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,true);
  end;

 11:
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,true);
    set_bit(mc2data,2,false);
  end;

 $FF:
  begin
    set_bit(mc2data,4,false);
    set_bit(mc2data,3,false);
    set_bit(mc2data,2,false);
  end;

 $FA:                            {Special Chip-Test-Mode}
  begin
    set_bit(mc2data,4,true);
    set_bit(mc2data,3,true);
    set_bit(mc2data,2,true);
  end;


 end;


 if cfg.opl = 4 then set_bit(mc2data,5,true);


 mc3data := 0;

 case cfg.SBirq of
 7:
   begin
     set_bit(mc3data,6,false);
     set_bit(mc3data,7,false);
   end;

 5:
   begin
     set_bit(mc3data,6,false);
     set_bit(mc3data,7,true);
   end;

 10:
   begin
     set_bit(mc3data,6,true);
     set_bit(mc3data,7,false);
   end;

  {IRQ is disabled}
 $FF:
   begin
     set_bit(mc3data,6,true);
     set_bit(mc3data,7,true);
   end;

 end;

 case cfg.SBdma of
 0:
  begin
     set_bit(mc3data,4,true);
     set_bit(mc3data,5,false);
   end;

 1:
   begin
     set_bit(mc3data,4,false);
     set_bit(mc3data,5,false);
   end;

 3:
   begin
     set_bit(mc3data,4,false);
     set_bit(mc3data,5,true);
   end;

  {DMA is disabled}
 $FF:
   begin
     set_bit(mc3data,4,true);
     set_bit(mc3data,5,true);
   end;

 end;

 if cfg.fmap = 1 then set_bit(mc3data,3,true);
 if cfg.gpmode = 1 then set_bit(mc3data,1,true);    
 if cfg.sbbase = $240 then set_bit(mc3data,2,true);

 mc4data := 0;
 if cfg.adpcm = 1 then set_bit(mc4data,7,true);
 if cfg.gpout > 0 then set_bit(mc4data,6,true);
 set_bit(mc4data,5,true); {Time Out ACK, reserved must be 1}
 if cfg.outmx > 0 then set_bit(mc4data,4,true); 
 if cfg.fmclk = 2 then set_bit(mc4data,3,true);
 if cfg.silence = 1 then set_bit(mc4data,2,true);   {silence}

 case cfg.SBver of

 1:
 begin
   set_bit(mc4data,0,true);
   set_bit(mc4data,1,false);
 end;

 2:
 begin
   set_bit(mc4data,0,false);
   set_bit(mc4data,1,false);
 end;

 3:
 begin
   set_bit(mc4data,0,false);
   set_bit(mc4data,1,true);
 end;

 4:
 begin
   set_bit(mc4data,0,true);
   set_bit(mc4data,1,true);
 end;

 end;


 mc5data := 0;

 {Reserved Bits of byte 5}

 if cfg.sbmix = 1 then set_bit(mc5data,7,true);
 set_bit(mc5data,6,false);   {reserved. OPL5 Adress decoding disabled}
 if cfg.shprotect = 1 then  set_bit(mc5data,5,true);
 set_bit(mc5data,4,false); {Codec access blocked in SB Mode}
 if cfg.fifo = 1 then  set_bit(mc5data,3,true);
 if cfg.sbmix = 1 then set_bit(mc5data,2,true); {SB PRO mixer voice volume emulation (PEN)}
 if cfg.cfix = 1 then  set_bit(mc5data,1,true);
 set_bit(mc5data,0,true);  {CDFTOEN}

 mc6data := 0;
 if cfg.mpu401 = 1 then  set_bit(mc6data,7,true);

 case cfg.MPUbase of
   $330:
    begin
     set_bit(mc6data,5,false);
     set_bit(mc6data,6,false);
    end;

   $320:
    begin
     set_bit(mc6data,5,true);
     set_bit(mc6data,6,false);
    end;

   $310:
    begin
     set_bit(mc6data,5,false);
     set_bit(mc6data,6,true);
    end;

   $300:
   begin
     set_bit(mc6data,5,true);
     set_bit(mc6data,6,true);
    end;
 end;

 case cfg.MPUIRQ of
 9:
   begin
     set_bit(mc6data,3,false);
     set_bit(mc6data,4,false);
   end;

 10:
   begin
     set_bit(mc6data,3,true);
     set_bit(mc6data,4,false);
   end;

 5:
   begin
     set_bit(mc6data,3,false);
     set_bit(mc6data,4,true);
   end;

 7:
   begin
     set_bit(mc6data,3,true);
     set_bit(mc6data,4,true);
   end;

 end;

 {Reserved bits of byte 6}
 set_bit(mc6data,2,false);    {DRQTM, DMA Watch Dog}
 set_bit(mc6data,1,true);     {Enable / Disable WAVE}
 set_bit(mc6data,0,true);     {ATTN? Must be 1}


 write929(MC1_PORT,mc1data);
 write929(MC2_PORT,mc2data);
 write929(MC3_PORT,mc3data);
 write929(MC4_PORT,mc4data);
 write929(MC5_PORT,mc5data);
 write929(MC6_PORT,mc6data);

end;


Procedure SetInitValues;
{Sets the default values from the data sheet.}
 
var mc1data,
    mc2data,
    mc3data,
    mc4data,
    mc5data,
    mc6data  : byte;

begin
 mc1data := 0;
 mc2data := 3;
 mc3data := 2;
 mc4data := $A2;
 mc5data := $25; { $2F for Crystal Codec}
 mc6data := $83;

 write929(MC1_PORT,mc1data);
 write929(MC2_PORT,mc2data);
 write929(MC3_PORT,mc3data);
 write929(MC4_PORT,mc4data);
 write929(MC5_PORT,mc5data);
 write929(MC6_PORT,mc6data);
end;


Procedure Codec_Access(value : boolean);
{Enable/Disbale access to the codec when in Sound Blaster mode}
var dummy : byte;
begin
   if SBMode then  {Only do this when in SB mode!}
   begin
     dummy := 0;
     dummy := read929(MC5_PORT);
     set_bit(dummy,4,value); {enable/disable access to codec in SB Mode}
     write929(MC5_PORT,dummy);
   end;
end;


Procedure Protect_Shadowregs(value : boolean);
{The registers of the codec are shadowed by the controller. This shadow registers can be writeprotected}
var dummy : byte;
begin
  dummy := 0;
  dummy := read929(MC5_PORT);
  set_bit(dummy,5,value); {Protect/unprotect shadow registers}
  write929(MC5_PORT,dummy);
end;


Procedure Silence929(on : boolean);
var dummy : byte;
begin
 dummy := 0;
 dummy := read929(MC4_PORT);
 set_bit(dummy,2,on);
 write929(MC4_PORT,dummy);
end;


Procedure ChipTest929(on : boolean);
{Experimental! Enables Chip-Test-Mode}
var dummy : byte;
begin
 dummy := 0;
 dummy := read929(MC2_PORT);
 set_bit(dummy,4,on);
 set_bit(dummy,3,on);
 set_bit(dummy,2,on);
 write929(MC2_PORT,dummy);
end;

Procedure Powerdown929(on : boolean);
{Enable/Disable powerdown mode }
var dummy : byte;
begin
 dummy := 0;
 dummy := read929(MC1_PORT);
 set_bit(dummy,6,on);
 write929(MC1_PORT,dummy);
end;

Procedure SBMixer(on : boolean);
{Enable/Disbale the simulation of the Sound Blaster Pro Mixer chip}
var dummy : byte;
begin
 dummy := 0;
 dummy := read929(MC5_PORT);
 set_bit(dummy,2,on);  {Enable/Disable mixer emulation}
 set_bit(dummy,7,on);  {Enable/Disable automatic volume control}
 write929(MC5_PORT,dummy);
end;

Procedure SBADPCM(on : boolean);
{Enables / Disables Sound Blaster ADPCM support}
var dummy : byte;
begin
 dummy := 0;
 dummy := read929(MC4_PORT);
 set_bit(dummy,7,on);
 write929(MC4_PORT,dummy);
end;

Function ChipRevision_929 : byte;
{Returns the Revision ID of the 82C929}
var d,d1 : byte;
begin
 d := read929(MC3_PORT);
 d1 := 0;
 set_bit(d1,0,get_bit(d,0));
 set_bit(d1,1,get_bit(d,1));
end;

end.
