Unit SBPro;
{Unit to handle the Sound Blaster Pro

v0.4 - July 2001 by Jan Knipperts}

interface
uses misc,dos,crt;


 const
  Master        = 0;
  Microphone    = 1;
  CD            = 2;
  LineIn        = 3;
  Voice         = 4;
  FM            = 5;

  Left          = 0;
  Right         = 1;
  LeftAndRight  = 2;

  HighPass      = 0;
  LowPass       = 1;

  PCM_8Bit      = 0;
  ADPCM_2Bit    = 1;
  ADPCMR_2Bit   = 2;
  ADPCM_4Bit    = 3;
  ADPCMR_4Bit   = 4;
  ADPCM_26Bit   = 5;
  ADPCMR_26Bit  = 6;

  Stereo        = True;
  Mono          = False;

  DmaChannel     : Array [0..3,1..3] of Byte =
  (($87,$0,$1),($83,$2,$3),($81,$2,$3),($82,$6,$7));


 var
     SBerror      : integer;
     SBPort       : Word;

 {DSP and Mixerchip I/O:}
 Function  DSP_Reset(Portnum : Word) : Boolean;
 Function  DSP_Read : Byte;
 Procedure DSP_Write(Value : byte);
 Procedure Mixer_Write(index, value : byte);
 Function  Mixer_Read(index : byte) : byte;

 {Volumes}
 Procedure SB_ResetMixer;
 Procedure SB_SetVolume(VolumeType, Channel, NewVolume : Byte);
 Function  SB_GetVolume(VolumeType, Channel : Byte) : byte;

 Function  SB_GetDSPVersion : word;
 Function  SB_GetDSPCopyright : string;

 Procedure SB_Speaker(Toggle : Boolean);
 Procedure SB_SetSampleRate(Freq : word);

 Procedure SB_SetOutput(StereoOutput, Filter : Boolean);
 Procedure SB_GetOutput(var StereoOutput, Filter : Boolean);

 Procedure SB_SetDataformat(value : byte);

 {Direct Play}
 Procedure SB_Direct_Play(samplebyte : byte);

 {Single cycle DMA}
 Procedure SB_Play_Buffer(Sample : Pointer; Size, Freq : Word; DMACh : Byte);
 Procedure SB_HaltDMA;
 Procedure SB_ContinueDMA;

 Procedure SB_Install_IRQ(irq : byte; p : pointer);
 Procedure SB_Uninstall_IRQ;



 {Record}
 Function  SB_Direct_Record : byte;
 Procedure SB_SetInput(Inputdevice, filter : byte; Filteron : Boolean);
 Procedure SB_GetInput(var Inputdevice, filter : byte; var Filteron : Boolean);

 {Single cycle DMA}
 Procedure SB_Record_Buffer(Buffer : Pointer; Size, Freq : Word; DMACh : Byte);



implementation
var DataFormat,
    IRQStopMask,
    IRQStartMask,
    IRQIntVector   : byte;
    OldintVector   : pointer;
    PICPort        : word;

Function getBit(b, n : Byte) : boolean;
{liefert den Zustand eines Bit}
begin
  getBit := boolean(odd(b shr n));
end;

Procedure XDelay(ms:word);
assembler;
asm
  mov ax,1000
  mul ms
  mov cx,dx
  mov dx,ax
  mov ah,86h
  int 15h
end;




Function  DSP_Reset(Portnum : Word) : Boolean;
begin
  {Reset the DSP}
  Port[Portnum + $6] := 1;
  xDelay(10);
  Port[Portnum + $6] := 0;
  xDelay(10);
  {Check if reset was succesfull}
  if (Port[Portnum + $E] and $80 = $80) and (Port[Portnum + $A] = $AA) then
  begin
    {DSP was found}
    DSP_Reset := true;
    SBPort := Portnum;
  end
  else
    {No DSP was found}
    DSP_Reset := false;
end;


Function  DSP_Read : Byte;
var timer : word;
begin
  timer := $FFFF;

  {Wait for the DSP to be ready to accept data}
  while (Port[SBPort + $E] and $80 = 0) and (timer > 0) do dec(timer);

  if timer = 0 then
  begin
   SBerror := 1;
   DSP_Read := $FF;
  end
  else
  begin
   DSP_Read := Port[SBPort + $A];
   SBerror := 0;
  end;
end;

Procedure DSP_Write(Value : byte);
var timer : word;
begin
  timer := $FF;
  {Wait for the DSP to be ready to accept data and check for timeout}
  while (Port[SBPort + $C] and $80 <> 0) and (timer > 0) do dec(timer);
  {Send byte}
  if timer > 0 then
  begin
   SBerror := 0;
   Port[SBPort + $C] := value;
  end
  else
  begin
   SBerror := 1;
  end;
end;


Procedure Mixer_Write(index, value : byte);
begin
 Port[SBPort+4] := Index;
 xdelay(1);
 Port[SBPort+5] := Value;
 xdelay(1);
end;


Function Mixer_Read(index : byte) : byte;
begin
 Port[SBPort+4] := Index;
 xdelay(1);
 Mixer_Read :=  Port[SBPort+5];
 xdelay(1);
end;

Procedure SB_ResetMixer;
begin
 Mixer_write($00,$FF);
 xdelay(10);
end;


Function SB_GetVolume(VolumeType, Channel : Byte) : byte;
var
 Index, Volume : Byte;

begin
   case VolumeType of
     Master         : Index := $22;
     Voice          : Index := $04;
     FM             : Index := $26;
     Microphone     : Index := $0A;
     CD             : Index := $28;
     LineIn         : Index := $2E;
    end;

   Volume := Mixer_Read(Index);

   if (Channel=Left) and (VolumeType <> Microphone) then
   begin
    SB_GetVolume := volume shr 5;
   end;

   If (VolumeType = Microphone) or (Channel=Right) then
   begin
    SB_GetVolume := ($F and Volume) shr 1;
   end;

end;

Procedure SB_SetVolume(VolumeType, Channel, NewVolume : Byte);
var
  Index,volume : byte;
begin

   If VolumeType <> Microphone then
   begin
     if newvolume > 7 then newvolume := 7;

     if Channel = Left then
     begin
      Volume := (SB_GetVolume(VolumeType,Right) shl 1) or (NewVolume shl 5);
     end;

     if Channel = Right then
     begin
       Volume := (NewVolume shl 1) or (SB_GetVolume(VolumeType,Left) shl 5);
     end;

     if Channel = LeftAndRight then
     begin
      Volume := (NewVolume shl 1) or (NewVolume shl 5);
     end;
   end
   else
   begin
    if newvolume > 3 then newvolume := 3;
    Volume := NewVolume shl 1;
   end;

     case VolumeType of
     Master         : Index := $22;
     Voice          : Index := $04;
     FM             : Index := $26;
     Microphone     : Index := $0A;
     CD             : Index := $28;
     LineIn         : Index := $2E;
    end;

    Mixer_Write(Index,Volume);
end;




Function  SB_GetDSPVersion : word;
var lv,hv : byte;
    ver   : word;

begin
 DSP_Write($E1);
 hv := DSP_Read;
 xdelay(10);
 lv := DSP_Read;
 asm
  mov al,lv
  mov ah,hv
  mov ver,ax
 end;
 SB_GetDSPVersion := ver;
end;

Function SB_GetDSPCopyright : string;
var s : string;
    i,c : byte;
begin
 s := '';
 DSP_Write($E3);
 xdelay(10);
 while i < 128 do
 begin
  c := DSP_Read;
  if (c = 0) or (SBerror > 0) then break;
  s := s + chr(c);
  inc(i);
 end;
end;


Procedure SB_Speaker(Toggle : Boolean);
begin
  if (Toggle = false) then
      DSP_Write($D3)  { off }
  else
      DSP_Write($D1); { on }
end;

Procedure SB_SetSampleRate(Freq : word);
begin
 DSP_Write($40);
 DSP_Write(256 - 1000000 Div Freq);
end;


Procedure SB_SetOutput(StereoOutput, Filter : Boolean);
var value : byte;
begin
 Value := 0;
 if StereoOutput then Value := 2;
 if not Filter then Value := Value or 32;
 Mixer_Write($0E,Value);
end;


Procedure SB_GetOutput(var StereoOutput, Filter : Boolean);
var value : byte;
begin
 Value := Mixer_Read($0E);
 StereoOutput := boolean((Value and 2) > 0);
 Filter := boolean((Value and 32) > 0);
end;

Procedure SB_SetInput(Inputdevice, filter : byte; Filteron : Boolean);
var value : byte;
begin

 Value := 0;

   case InputDevice of
     Microphone     : value := 0;
     CD             : value := 2;
     LineIn         : value := 6;
   else
     exit;
   end;

 if Filter = Lowpass then value := value or 8;
 if not filteron then value := value or 32;
 Mixer_write($0C,value);
end;

Procedure SB_GetInput(var Inputdevice, filter : byte; var Filteron : Boolean);
var value : byte;
begin

 Value := Mixer_read($0C);

   case Value and 6 of
     0 : Inputdevice := Microphone;
     2 : Inputdevice := CD;
     6 : Inputdevice := LineIn;
   end;

  if value and 8 <> 0 then filter := LOwPass else Filter := HighPass;
  Filteron := (Value and 32) = 0;
end;


Procedure SB_SetDataformat(value : byte);
begin
 if value < 6 then DataFormat := value;
end;


Procedure SB_Direct_Play(samplebyte : byte);
{Outputs single sample}
begin
 DSP_Write($10);
 DSP_Write(samplebyte);
end;

Function SB_Direct_Record : byte;
{Records single sample}
begin
 DSP_Write($20);
 SB_Direct_Record := DSP_Read;
end;


Procedure SB_Play_Buffer(Sample : Pointer; Size, Freq : Word; DMACh : Byte);
{Plays sound data with single cycle dma transfer

 The format of the datamust be set with "SB_Set_Dataformat" before!

 Size           Size of data block (Max. 64 Kb in one time!)
 Freq           Sampling rate in herts
 DMACh          Number of DMA-channel (0-3)}

 var Offset,Page : Word;
    l            : Longint;
Begin

 SB_SetSampleRate(Freq);
 SB_Speaker(True);


 if (size = 0) then
 begin
  DSP_Write($0F2);
  exit;
 end;

 case DataFormat of
  PCM_8Bit      :  size := size - 1;
  ADPCM_2Bit    :  size := (size - 1 + 3) div 4;
  ADPCMR_2Bit   :  size := (size - 1 + 3) div 4 + 1;
  ADPCM_26Bit   :  size := (size - 1 + 2) div 3;
  ADPCMR_26Bit  :  size := (size - 1 + 2) div 3 + 1;
  ADPCM_4Bit    :  size := (size - 1 + 1) div 2;
  ADPCMR_4Bit   :  size := (size - 1 + 1) div 2 + 1;
 end;

 Offset := Seg(Sample^) Shl 4 + Ofs(Sample^);
 Page := (Seg(Sample^) + Ofs(Sample^) Shr 4) Shr 12;
 Port[$0A] := $4 + DMACh; {Stop DMA Transfers on this channel}
 Port[$0C] := 0;          {Clear the internal DMA flip-flop}

 Port[$0B] := $48 + DMACh;  {Set 8Bit DMA-Transfer mode}
 Port[DMAChannel[DMACh,2]] := Lo(Offset);   {Provide data source and size}
 Port[DMAChannel[DMACh,2]] := Hi(Offset);
 Port[DMAChannel[DMACh,1]] := Page;
 Port[DMAChannel[DMACh,3]] := Lo(Size);
 Port[DMAChannel[DMACh,3]] := Hi(Size);
 Port[$0A] := DMACh;       {Start DMA Channel}

 case DataFormat of
  PCM_8Bit      :  DSP_Write($14); {Start 8 Bit DMA-Transfer to DSP}
  ADPCM_2Bit    :  DSP_Write($16); {Start 2 Bit ADPCM Transfer to DSP}
  ADPCMR_2Bit   :  DSP_Write($17); {Start 2 Bit ADPCM Transfer with reference byte to DSP}
  ADPCM_4Bit    :  DSP_Write($74); {Start DMA DAC 4 Bit ADPCM Transfer}
  ADPCMR_4Bit   :  DSP_Write($75); {Start DMA DAC 4 Bit ADPCM with reference byte Transfer}
  ADPCM_26Bit   :  DSP_Write($76); {Start DMA DAC 2.6 Bit ADPCM Transfer}
  ADPCMR_26Bit  :  DSP_Write($77); {Start DMA DAC 2.6 Bit ADPCM with reference byte Transfer}
 end;

 DSP_Write(Lo(Size));    {Provide Size to dsp}
 DSP_Write(Hi(Size));
End;

Procedure SB_Record_Buffer(Buffer : Pointer; Size, Freq : Word; DMACh : Byte);
{Records 8Bit PCM data with single cycle dma transfer}
var Offset,Page : word;
begin

 dec(size);

 if (size = 0) then
 begin
  exit;
 end;

 Offset := Seg(Buffer^) Shl 4 + Ofs(Buffer^);
 Page := (Seg(Buffer^) + Ofs(Buffer^) Shr 4) Shr 12;
 Port[$0A] := $4 + DMACh; {Stop DMA Transfers on this channel}
 Port[$0C] := 0;          {Clear the internal DMA flip-flop}

 Port[$0B] := $45;  {Set 8Bit input DMA-Transfer mode}
 Port[DMAChannel[DMACh,2]] := Lo(Offset);   {Provide data source and size}
 Port[DMAChannel[DMACh,2]] := Hi(Offset);
 Port[DMAChannel[DMACh,1]] := Page;
 Port[DMAChannel[DMACh,3]] := Lo(Size);
 Port[DMAChannel[DMACh,3]] := Hi(Size);
 Port[$0A] := DMACh;       {Start DMA Channel}

 SB_Speaker(false);
 SB_SetSampleRate(Freq);

 DSP_Write($24);
 DSP_Write(Lo(Size));    {Provide Size to dsp}
 DSP_Write(Hi(Size));
end;



Procedure SB_HaltDMA;
begin
  DSP_Write($0D0);
end;

Procedure SB_ContinueDMA;
begin
  DSP_Write($0D4);
end;


Procedure SB_Install_IRQ(irq : byte; p : pointer);
const
 IRQIntNums : Array[0..15] of byte = ($08,$09,$0A,$0B,$0C,$0D,$0E,$0F,
                                      $70,$71,$72,$73,$74,$75,$76,$77);

begin
  if irq <= 7 then PICPort := $21 else PICPort := $A1;
  IRQIntVector := IRQIntNums[irq];
  IRQStopMask := 1 shl (irq mod 8);
  IRQStartMask := not IRQStopMask;
  GetIntVec(IRQIntVEctor,Oldintvector);
  SetIntVEc(IRQIntVector,p);
  Port[PICPort] := Port[PICPort] and IRQStartMask;
end;

Procedure SB_uninstall_IRQ;
begin
asm
 cli
end;
  Port[PICPort] := Port[PICPort] or IRQStopMask;
  SetIntVEc(IRQIntVector,OldintVector);
asm
 sti
end;
end;






begin
 SBError := 0;
end.
