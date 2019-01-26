Unit MPU;
{ Unit to handle Roland MPU-401
  v 1.3 - 20.08.2000 by Jan Knipperts}

interface

uses dos, crt, misc;

var
    COMDPORT : word; { MPU-401 Command Port) }
    STATPORT : word; { MPU-401 Status Port) }
    DATAPORT : Word; { MPU-401 Data I/O Port) }


Procedure SendData(dat:byte); {Sends byte to MPU}
Function  ReceiveData:integer;    { Receive byte from MPU }
Function  ResetMPU(mode:byte) : boolean;    { Reset MPU to defaults }
Procedure NoteOn(MidiChannel, Note, Velocity : Byte);{NoteOn on MidiChannel 0..15, Velocity 0 is noteOff  }
Procedure NoteOff(MidiChannel, Note, Velocity  : Byte); {NoteOff on Midichannel 0..15}
Procedure SetPatch(MidiChannel, Patch : byte); {Sets defined GM-Patch to midichannel}


implementation

const
   { Status Port Bits }
  DRR      = $40;  { MPU-401 'Ready to receive' mask }
  DSR      = $80;  { MPU-401 'Ready to send' mask }

  { MPU commands }
  CMD_UART     = $3F; { Become a dumb uart }
  CMD_INTCLOCK = $80; { MPU is master clock }
  CMD_EXTCLOCK = $82; { Master clock is not MPU }
  CMD_FSKINT   = $92; { Set FSK sync res. to internal sync res. }
  CMD_FSKMIDI  = $93; { Set FSK sync res. to MIDI sync res. }
  CMD_RESET    = $FF; { Reset to default state }

  { Initialization switches }
  SW_D_ALLOFF   = $30; { Disable automatic "ALL NOTES OFF" }
  SW_D_REALTIME = $32; { Disable automatic real time msgs }
  SW_D_THRU     = $33; { Disable "thru" function }
  SW_E_TIME     = $34; { Add timing bytes in "data in stop" mode }
  SW_E_MODE     = $35; { Pass mode messages to host }
  SW_E_TEXCL    = $37; { Pass exclusive msgs from in to out }
  SW_E_COMMON   = $38; { Pass common messages to host }
  SW_E_REALTIME = $39; { Pass real time messages to host }
  SW_E_FSKSYNC  = $81; { Enable FSK input/output & sync to it }
  SW_E_METRO    = $83; { Metronome on - no accents }
  SW_D_METRO    = $84; { Metronome off }
  SW_E_AMETRO   = $85; { Metronome on - w/accents }
  SW_D_BENDER   = $86; { Disable continuous controller to host }
  SW_E_BENDER   = $87; { Enable continuous controller msgs }
  SW_D_VOXTHRU  = $88; { Disable voice "thru" function }
  SW_E_VOXTHRU  = $89; { Enable voice "thru" function }
  SW_D_DATAINSTOP = $8A; { Disable "data in stop" mode }
  SW_E_DATAINSTOP = $8B; { Enable "data in stop" mode }
  SW_D_MEASEND  = $8C; { Disable "measure end" to host }
  SW_E_MEASEND  = $8D; { Enable "measure end" to host }
  SW_D_CONDUCT  = $8E; { Disable conductor function }
  SW_E_CONDUCT  = $8F; { Enable conductor function }
  SW_D_RTAFFECT = $90; { Disable real time affection }
  SW_E_RTAFFECT = $91; { Enable real time affection }
  SW_D_CLKHOST  = $94; { Disable "clock to host" msgs }
  SW_E_CLKHOST  = $95; { Enable "clock to host" msgs }
  SW_D_HEXCL    = $96; { Don't pass exclusives to host }
  SW_E_HEXCL    = $97; { Pass exclusives to host }
  SW_D_CRTA     = $98; { Channel reference table A off }
  SW_E_CRTA     = $99; { Channel reference table A on }
  SW_D_CRTB     = $9A; { Channel reference table B off }
  SW_E_CRTB     = $9B; { Channel reference table B on }
  SW_D_CRTC     = $9C; { Channel reference table C off }
  SW_E_CRTC     = $9D; { Channel reference table C on }
  SW_D_CRTD     = $9E; { Channel reference table D off }
  SW_E_CRTD     = $9F; { Channel reference table D on }

  { Information retrieving commands }
  GET_PC1       = $A0; { Get play counter for track 1 }
  GET_PC2       = $A1; { Get play counter for track 2 }
  GET_PC3       = $A2; { Get play counter for track 3 }
  GET_PC4       = $A3; { Get play counter for track 4 }
  GET_PC5       = $A4; { Get play counter for track 5 }
  GET_PC6       = $A5; { Get play counter for track 6 }
  GET_PC7       = $A6; { Get play counter for track 7 }
  GET_PC8       = $A7; { Get play counter for track 8 }
  GET_RC        = $AB; { Get record counter (& clear it) }
  GET_TEMPO     = $AF; { Get the tempo }
  GET_VERSION   = $AC; { Get firmware version }
  GET_REVISION  = $AD; { Get firmware revision }

  { Clear functions }
  CLR_RELTEMPO  = $B1; { Sets relative tempo to 1/1 }
  CLR_PC        = $B8; { Clears all play counters }
  CLR_PM        = $B9; { Clears all channel reference tables }
  CLR_RC        = $BA; { Clear the record counter }

  { Set functions (no operands) }
  SET_TB48      = $C2; { Set timebase to 48 clocks/beat }
  SET_TB72      = $C3; { Set timebase to 72 clocks/beat }
  SET_TB96      = $C4; { Set timebase to 96 clocks/beat }
  SET_TB120     = $C5; { Set timebase to 120 clocks/beat }
  SET_TB144     = $C6; { Set timebase to 144 clocks/beat }
  SET_TB168     = $C7; { Set timebase to 168 clocks/beat }
  SET_TB192     = $C8; { Set timebase to 192 clocks/beat }

  { Set functions (operand follows) }
  SET_TEMPO     = $E0; { Set tempo }
  SET_RTEMPO    = $E1; { Set relative tempo }
  SET_TGRAD     = $E2; { Set tempo graduation }
  SET_CMBEAT    = $E4; { Set # MIDI clocks / metronome beat }
  SET_MBMEAS    = $E6; { Set # metronome beats / measure }
  SET_ICCLOCK   = $E7; { Set # internal clocks (x4) / clock to host }
  SET_ACTIVE    = $EC; { Set active tracks bitmap }
  SET_PLAYCTRS  = $ED; { Set play counter bitmap }
  SET_LACCCH    = $EE; { Set lo acceptable tracks bitmap }
  SET_HACCCH    = $EF; { Set hi acceptable tracks bitmap }

  { Request functions }
  REQ_SCH0      = $D0; { Want to send data on track 0 }
  REQ_SCH1      = $D1; { Want to send data on track 1 }
  REQ_SCH2      = $D2; { Want to send data on track 2 }
  REQ_SCH3      = $D3; { Want to send data on track 3 }
  REQ_SCH4      = $D4; { Want to send data on track 4 }
  REQ_SCH5      = $D5; { Want to send data on track 5 }
  REQ_SCH6      = $D6; { Want to send data on track 6 }
  REQ_SCH7      = $D7; { Want to send data on track 7 }
  REQ_SSYS      = $DF; { Want to send system message }

  CMD_ACK       = $FE; { MPU's acknowledement of a command }

  MIDI_EOX      = $F7; { End Of eXclusive message }




(****************************************************************
 *           Public   S U B R O U T I N E S                     *
 ****************************************************************)

Procedure SendData(dat:byte);
begin
  repeat until (Port[STATPORT] and DRR)=0;
  Port[DATAPORT]:=dat;
  xdelay(10);
end;

Function ReceiveData : integer;
var i:integer;
begin
  i:=20000;
  repeat
  dec(i);
  until (i=0) or ((Port[STATPORT] and DSR)=0);

  if i=0 then
    ReceiveData:=256
  else
    ReceiveData:=Port[DATAPORT];
end;


Function ResetMPU(mode:byte) : boolean;
{ mode = 0 : Reset MPU to power-on defaults }
{ mode = 1 : Command MPU to dumb UART mode }
var foo:byte;
    timer : word;
begin
  Port[COMDPORT]:=CMD_RESET; { Send RESET command to MPU }

    if (mode=1) then
    begin
      xdelay(20);
      timer := $FF;
      while ((Port[STATPORT] and DSR)<>0) and (timer > 0) do dec(timer);
      foo:=Port[DATAPORT];

        if (foo <> CMD_ACK) or (timer = 0) then
        begin
         ResetMPU := false;
         exit;
        end;

      xdelay(10);

        if (Port[STATPORT] and DRR)<>0 then
        begin
          ResetMPU := false;
          exit;
        end;

      Port[COMDPORT]:=CMD_UART;
      xdelay(10);
      timer := $FF;

      while ((Port[STATPORT] and DSR) <> 0) and (timer > 0) do
      dec(timer);

      foo:=Port[DATAPORT];

      if (foo <> CMD_ACK) or (timer = 0) then
      begin
        ResetMPU := false;
        exit;
      end;
    end;

   {Some devices need an additional "GM-Reset" sysex: }
   SendData($F0);
   SendData($7E);
   SendData($7F);
   SendData($09);
   SendData($01);
   SendData($F7);

   ResetMPU := true;
end;


Procedure SetPatch(MidiChannel, Patch : byte);
{Sets defined GM-Patch to midichannel}
begin
 SendData($C0+ MidiChannel);
 SendData(Patch);
end;


Procedure NoteOn(MidiChannel, Note, Velocity : Byte);
{ Sends NoteOn on MidiChannel 0..15, Velocity 0 is noteOff  }

begin
  SendData($90+ MidiChannel);
  xdelay(10);
  SendData(Note);
  xdelay(10);
  SendData(Velocity);
  xdelay(10);
end;

Procedure NoteOff(MidiChannel, Note, Velocity  : Byte);
{ Sends NoteOff on MidiChannel 0..15}

begin
  SendData($80+ MidiChannel);
  SendData(Note);
  SendData(Velocity);
end;




end.
