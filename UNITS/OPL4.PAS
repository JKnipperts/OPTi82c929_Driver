{Small unit to interact with Yamaha OPL4 Wavetable synthesizer
 v0.1 - 09/02/2019 by Jan Knipperts}

Unit OPL4;

interface

const
 OPL4_PCM_PORT = $380;
 OPL4_FM_PORT  = $388;

 Var
 OPL4ML : Boolean;

Procedure OPL4_wait;
Procedure OPL4_PCM(onoff : boolean);
Function OPL4_detect : boolean;
Function OPL4_YRW801_detect : boolean;
Function OPL4_SRAM : boolean;
Procedure OPL4_write(reg, value : byte);
Function OPL4_read(reg : byte) : byte;
Procedure OPL4_read_memory(buf : pointer; offset, size : word);
Procedure OPL4_write_memory(buf : pointer; offset, size : longint);

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



Procedure Addrdelay;
assembler;
asm
   mov     cx, 6           {6 Wiederhohlungen = 3.3 microsekunden}
   mov     dx, opl4_fm_port        {Adlib Port (388h)}

@delayloop1:
   in      al, dx
   loop    @delayloop1
   ret
end;


Procedure Datadelay;
assembler;
asm
   mov     cx, 35          {35 Wiederhohlungen = 23 microsekunden}
   mov     dx, opl4_fm_port     {Adlib Port (388h)}

@delayloop2:
   in      al, dx
   loop    @delayloop2
   ret
end;


procedure opl4_wait;
var timeout : byte;
begin
  for timeout := 1 to 15 do
   if (port[opl4_fm_port] and $01) = 0 then break;  {Break if OPL is not busy}
end;


procedure OPL4_write(reg, value : byte);
begin
  opl4_wait;
  port[opl4_pcm_port] := reg;
  opl4_wait;
  port[opl4_pcm_port+1] := value;
end;

function OPL4_read(reg : byte) : byte;
begin
  opl4_wait;
  port[opl4_pcm_port] := reg;
  opl4_wait;
  OPL4_read := port[opl4_pcm_port+1];
end;

Procedure OPL4_read_memory(buf : pointer; offset, size : word);
var
  memcfg : byte;
  cnt    : word;
begin
  asm
   cli
   pusha
  end;
  memcfg := OPL4_read($02);
  OPL4_write($02, memcfg or $01);     {02 = Allow CPU to read/write mem}
  OPL4_write($03 ,offset shr 16);      {03 = High mem address reg}
  OPL4_write($04 ,offset shr 8);       {04 = Mid mem address reg}
  OPL4_write($05 ,offset);             {05 = Low mem address reg}
  opl4_wait;
  port[opl4_pcm_port] := $06; {06 = Memory data register}
  opl4_wait;
  for cnt := 0 to size-1 do
  begin
   mem[seg(buf^):ofs(buf^)+cnt] := port[opl4_pcm_port+1];
  end;
  OPL4_write($02,memcfg);
  asm
   popa
   sti
  end;
end;

Function OPL4_SRAM : boolean;
var
 memcfg : byte;
begin
 memcfg := OPL4_read($02);
 OPL4_SRAM := boolean(odd(memcfg shr 1));
end;

Procedure OPL4_write_memory(buf : pointer; offset, size : longint);
var
  memcfg : byte;
  cnt    : longint;
begin
  asm
   cli
   pusha
  end;
  memcfg := OPL4_read($02);
  if boolean(odd(memcfg shr 1)) then {Don't try to write if ROM is installed}
  begin
   OPL4_write($02, memcfg or $01);
   OPL4_write($03,offset shr 16);
   OPL4_write($04,offset shr 8);
   OPL4_write($05,offset);
   opl4_wait;
   port[opl4_pcm_port] := $06;
   opl4_wait;
   for cnt := 1 to size do
   port[opl4_pcm_port+1] := mem[seg(buf^):ofs(buf^)+cnt];
   OPL4_write($02,memcfg);
   asm
    popa
    sti
   end;
 end;
end;


Procedure OPL4_PCM(onoff : boolean);
var d : byte;
begin
 port[opl4_fm_port+2] := $05;
 AddrDelay;
 d := 0;
 set_bit(d,1,onoff);
 port[opl4_fm_port+3] := d;
 DataDelay;
end;



function OPL4_detect : boolean;
var id,ofm,opcm,fm,pcm : byte;
begin
  OPL4_PCM(true); {Enable PCM}
  id :=  OPL4_read($02); {Read memory configuration reg}
  if ((id and $E0) <> $20) and     {NO OPL4 ID}
     ((id and $E0) <> $40) then    {NO OPL4 ML ID}
  begin
    OPL4_detect := false;
    exit;
  end;

  ofm := OPL4_read($F8);  {FM MIX Control}
  opcm := OPL4_read($F9); {PCM MIX Control}

  OPL4_write($F8,$00); {Set FM Mix control to 0}
  OPL4_write($F9,$FF); {Set PCM Mix control to FFh}
  fm := OPL4_read($F8);
  pcm := OPL4_read($F9);

  if (fm  <> 0) or (pcm <> $FF) then   {Failed to write registers = No OPL4}
  begin
    OPL4_detect := false;
    exit;
  end;

  OPL4_write($F8,ofm);  {Set original volumes}
  OPL4_write($F9,opcm);



  OPL4_write($02,$00);  {Reset memory cfg}
  OPL4_detect := true;
end;


function OPL4_YRW801_detect : boolean;
var buf : array[0..14] of char;
    s   : string;
begin
 OPL4_read_memory(addr(buf),$1200,15);
 s := buf;
 if pos('YAMAHA',s) = 0 then
 begin
   OPL4_YRW801_detect := false;
 end;
 OPL4_YRW801_detect := true;
end;


end.








