{
 Program: Unit for replay of "Easy Adlib" OPL-2 Sound modules
 Author : Jan Knipperts (Abaddon /CodeBreaker)
 Ver.   : 1.0
 Date   : 26.02.2000}

 Unit BMF;

 interface
 uses dos,misc,opl;

 type


   ChannelInfo = record
             Note   : byte;
             Octave : byte;
             Voice  : byte;
             Vol    : byte;
             Active : boolean;
   end;

 const
{Timer:}
     irq_freq   : real = 50;
     timer_freq : real = 50;
     BMFtimer   = 70; {Bei manchen Liedern scheinen 55, bei anderen 68,5 Hz oder 70 Hz zu passen...}

var
        title       : array[1..40] of char;
        composer    : array[1..40] of char;
        speed       : byte;
        numinst     : byte;
        music       : pointer;
        datasize    : word;
        Chan        : array[0..8] of ChannelInfo;


        Function  PlayBMFfile(filename : string) : byte;
        {Loads a BMF file to the buffers
        Errorcodes returned :
         0 = no error
         1 = file not found
         2 = read error
         3 = unknown file version
         4 = not enough mem}
        Function PlayBMFdata(p : pointer; songsize : word) : byte;
        Procedure StopBMFplayer;



implementation

        const

     {Das Standart-Instrument "Silence"}
     Silencename : array[1..11] of char = (
     'S','i','l','e','n','c','e',' ',' ',' ',#0);
     Silence     : array[0..12] of byte = (
     $01, $01, $3F, $3F, $00, $00, $F0, $F0, $00, $00, $00, $00, $00);




        type
           BMFInst = record
            Name   : array[1..11] of char;
            data   : array[0..12] of byte;
           end;

           BMFEvent = record
            note    : byte;
            delay   : byte;
            cmd     : byte;
            cmddata : byte;
           end;

           StreamData = record
            Pos     : word;
            Delay   : byte;
            LoopPos : word;
            LoopCnt : byte;
           end;



    var
       f            : file;
       z,b,z1       : byte;
       ID           : array[1..3] of char; {BMF}
       Filever      : array[1..3] of char; {1.1}
       ok           : integer;
       iflag        : array[1..4] of byte;  {flag 32-Bit fÅr instrumente}
       tflag        : array[1..4] of byte;  {flag fÅr Tracks}
       bc           : word;
       inst         : array[1..32] of bmfinst;
       defaultvoice : bmfinst;
       mempos       : word;
       memuse       : boolean;
       tracknum     : byte;
       ticklooper,
       clock,tick0  : real;
       ticks        : word;
       oldint08     : procedure;
       Stream       : array[0..8] of array[0..1023] of BMFEvent;
       Streaminfo   : array[0..8] of StreamData;






        Function GetDataByte(pos : word) : byte;
        begin
         {Gets one byte from buffer}
          if (ofs(music^)+pos <= 65535) and (pos < datasize) then
          begin
            GetDataByte := mem[seg(music^):ofs(music^)+pos];
          end;
        end;



        Procedure SetVoice(channr : byte;var instr : BMFInst);
        {Loads the instrument (instr) to the given channel (chnnr)}
        var ic : byte;
        begin
          setreg(offsets[0,channr]+$20, instr.data[0]);
          setreg(offsets[1,channr]+$20, instr.data[1]);
          setreg(offsets[0,channr]+$40, instr.data[2]);
          setreg(offsets[1,channr]+$40, instr.data[3]);
          setreg(offsets[0,channr]+$60, instr.data[4]);
          setreg(offsets[1,channr]+$60, instr.data[5]);
          setreg(offsets[0,channr]+$80, instr.data[6]);
          setreg(offsets[1,channr]+$80, instr.data[7]);
          setreg($A0+channr, instr.data[8]);
          setreg($B0+channr, instr.data[9]);
          setreg($C0+channr, instr.data[10]);
          setreg(offsets[0,channr]+$E0, instr.data[11]);
          setreg(offsets[1,channr]+$E0, instr.data[12]);
          chan[channr].vol := getcvolume(channr);
        end;


        Procedure ConvertStream(chan : byte);
        var
          command            : byte;
          cpos               : word;
          ende               : boolean;
        begin

          ende := false;
          cpos := 0;
          fillchar(stream[chan][cpos],sizeof(stream[chan][cpos]),0);
          repeat;
            command := GetDataByte(mempos);

            if (command = $7D) or (command = $FC) or (command = $FE) then
            begin

              if (command = $FE) then      {End of Stream}
              begin
                stream[chan][cpos].cmd := $FF;
                ende := true;
                inc(mempos);
                exit;
              end;

              if command = $FC then      {Save Loop Position}
              begin
               stream[chan][cpos].cmd := $FE;
               stream[chan][cpos].cmddata := (GetDataByte(mempos+1) and $3F);
               inc(mempos,2);
              end;

              if command = $7D then      {Loop saved Position}
              begin
               stream[chan][cpos].cmd := $FD;
               inc(mempos);
              end;

            end
            else
            begin

              if (command AND $80) <> 0 then
              begin


                if (getdataByte(mempos+1) and $80) <> 0 then
                begin

                   if ( getdatabyte(mempos+1) and $40) <> 0 then
                   begin
                     stream[chan][cpos].note    := command and $7F;
                     stream[chan][cpos].delay   := getdatabyte(mempos+1) and $3F;
                     stream[chan][cpos].cmd     := getdatabyte(mempos+2);
                     inc(mempos,3);
                   end
                   else
                   begin
                     stream[chan][cpos].note    := command and $7F;
                     stream[chan][cpos].delay   := getdatabyte(mempos+1) and $3F;
                     inc(mempos,2);
                   end;

                end
                else
                begin
                  stream[chan][cpos].note    := command and $7F;
                  stream[chan][cpos].cmd     := getdatabyte(mempos+1);
                  inc(mempos,2);
                end;

              end
              else
              begin
                stream[chan][cpos].note    := command and $7F;
                inc(mempos);
              end;
            end;

            inc(cpos);

           until (cpos >= 1024) or (mempos >= datasize) or (ende = true);
          end;






          Procedure DecrunshStreams;
          {Decrunshes all Streams in the file and loads them to the right channels}

          var bc : byte;
          begin

            fillchar(stream,sizeof(stream),0);
            mempos := 0;

            for bc := 7 downto 0 do     {Bit counter}
            begin
              if getbit(tflag[1],bc) = 1 then      {is the bit set? Then load the stream}
              begin
                ConvertStream(7-bc);
              end
              else
              begin                             {if not, then there is no stream to play}
                stream[7-bc][0].cmd := $FF;
              end;
            end;

            {And again for channel 9}

            if getbit(tflag[2],7) = 1 then
            begin
              ConvertStream(8);
            end
            else
            begin
              stream[8][0].cmd := $FF;
            end;

            end;



          {=========================== FX ======================}

          Procedure Portamento_up(chan,speed : byte);
          var  freqdum : word;
               b1      : byte;


          begin

          freqdum := getfreq(chan);

          if ((freqdum+speed) <= 20000) then
          begin
              inc(freqdum,speed);
              setfreq(chan,freqdum)
          end
          else
          begin
              setfreq(chan,20000);
          end;

          end;



         Procedure Portamento_down(chan,speed : byte);
         var
         freqdum : integer;
            b1   : byte;
         begin

           freqdum := getfreq(chan);
           if ((freqdum-speed) >= 0) then
           begin
             dec(freqdum,speed);
             setfreq(chan,word(freqdum))
           end
           else
           begin
             setfreq(chan,0);
           end;

        end;



{================================== Main Player}

  Procedure UpdatePlayer;
  {The Main update function for the player to be called by the interrupt}
  var cc,ic    : byte;
      event    : BMFEvent;
  begin

     for cc := 0 to 8 do
     begin

      if streaminfo[cc].pos <> $FFFF then
      begin

        if streaminfo[cc].delay > 0 then       {proceed delay..}
        begin
         dec(streaminfo[cc].delay);
         Chan[cc].note   := 0;  {update variables}
         Chan[cc].octave := 0;
        end
        else
        begin

             {First proceed the special events
              (end of stream and loop of events)}

             event := stream[cc][streaminfo[cc].pos]; {just for our comfort}

             while event.cmd in [$FD..$FF] do     {while there comes a special event}
             begin

                  if event.cmd = $FF then          {End of stream}
                  begin
                   streaminfo[cc].pos  := $FFFF;
                   dec(tracknum);                 {dec number of active tracks}
                   chan[cc].active := false;
                   Chan[cc].note   := 0;  {update variables}
                   Chan[cc].octave := 0;
                   break;
                  end;

                  if event.cmd = $FE then
                  begin
                   streaminfo[cc].looppos  := streaminfo[cc].pos+1;
                   streaminfo[cc].loopcnt  := event.cmddata;
                  end;

                  if event.cmd = $FD then
                  begin
                     if streaminfo[cc].loopcnt  > 0 then
                     begin
                      streaminfo[cc].pos := streaminfo[cc].looppos-1;
                      dec(streaminfo[cc].loopcnt);
                     end;
                  end;

                  inc(streaminfo[cc].pos);
                  event := stream[cc][streaminfo[cc].pos];

             end; {While}




             {Now the normal events}

             if streaminfo[cc].pos <> $FFFF then    {Check again}
             begin
                  streaminfo[cc].delay := event.delay;  {Get next delay}

                  if event.cmd > 0 then   {There is a command / fx}
                  begin

                       if event.cmd in [0..$F] then {Porta up}
                       begin
                        Portamento_up(cc,event.cmd);
                       end;

                       if event.cmd in [1..$1F] then {Porta down}
                       begin
                        Portamento_down(cc,event.cmd-$10);
                       end;

                       if (event.cmd in [$20..$3F]) then {Set Voice}
                       begin
                         SetVoice(cc,inst[(event.cmd-$20)+1]);
                         Chan[cc].voice := (event.cmd-$20)+1;
                       end;

                       if (event.cmd in [$40..$7F]) then {Set Volume}
                       begin
                         SetCVolume(cc,(event.cmd-$40));  {Set carrier}
                         SetMVolume(cc,(event.cmd-$40));  {Set modulator}
                         Chan[cc].vol := (event.cmd-$40);
                       end;
                  end;

                  if event.note > 0 then
                  begin
                       keyoff(cc);
                       if (event.note < $60) then {if note is > $60 just do a keyoff}
                       begin
                         keyon(cc,event.note div 12,nfreq(event.note mod 12));   {Play note}
                         Chan[cc].note   := event.note mod 12;  {update variables}
                         Chan[cc].octave := event.note div 12;
                       end;
                  end;

                inc(streaminfo[cc].pos);        {and step to the next byte}


             end; {<> $FFFF}
        end; {No delay?}

      end; {<> $FFFF}

   if tracknum = 0 then {if no active track is left -> start over again}
   begin
     for ic := 0 to 8 do
     begin
      streaminfo[ic].pos := 0;
      chan[ic].active := true;
     end;
     tracknum := 9;

   end;

  end; {For}
end;





{================================ Player / Interrupt}


Procedure PollBMF;
{Player timing and update procedure to be called by the interrupt}
begin

 if ((ticks-tick0+1 >= speed)) then {correct speed?}
 begin
  UpdatePlayer;                 {Play}
  tick0 := ticks;               {and reset counter}
 end
 else
 begin
   inc(ticks);  {just count the ticks}
 end;

end;


procedure SetClockRate(ticks: longint); {set a new clockrate}
begin
  port[$43] := $36;
  port[$40] := lo(ticks);
  port[$40] := hi(ticks);
end;

procedure UpdateTimer(refresh: real);   {Update Timer to a specified frequency}
begin
  timer_freq := refresh;

  If (timer_freq < 32) then
  begin
    irq_freq := 32
  end
  else
  begin
   irq_freq := timer_freq;
  end;

  If (timer_freq < 32) then
  begin
   SetClockRate($0ffff DIV Round(irq_freq/18.2))
  end
 else
  begin
   SetClockRate(Round(1193150/irq_freq));
  end;
end;




procedure BMFint; interrupt;   {Our own interrupt routine}
begin
  If (ticklooper > 0) then
  begin
  asm
    cli
    mov al,20h
    out 20h,al
  end;
  end
  else
  begin
  asm
   pushf
  end;
    pollbmf;
    oldint08;
  end;

  ticklooper := ticklooper+timer_freq/irq_freq;
  If (ticklooper >= 1) then ticklooper := 0;

end;


procedure init_BMFirq;
begin
  GetIntVec($1C,@oldint08);
  SetIntVec($1C,@bmfint);
end;

procedure done_BMFirq;
begin
  SetIntVec($1C,@oldint08);
  SetClockRate(0);
end;




{================================== File Handling =====================}






Procedure StartBMFPlayer;
begin

{ SetFnumTable(BMFFnums);}

 {Some Initialisation}
 for z := 0 to 8 do
 begin
     setvoice(z,defaultvoice);
     chan[z].voice := 1;
     chan[z].vol := 0;
     chan[z].active := true;
 end;

 tracknum := 9;


 {Set the new Interrupt and start the Player}
 init_BMFirq;
 UpdateTimer(BMFtimer);
end;

Procedure StopBMFPlayer;
begin
 done_BMFirq;        {Restore the original timing interrupt and frequency}
 initOPL;            {Clear OPL-Chip}
 fillchar(chan,sizeof(chan),0);
 fillchar(stream,sizeof(stream),0);
 fillchar(streaminfo,sizeof(streaminfo),0);
 mempos := 0;
 if memuse then freemem(music,datasize); {free the memory buffer}
end;








Function PlayBMFdata(p : pointer; songsize : word) : byte;
var bytec,cnt,c : byte;
    o     : word;
{
 Errorcodes returned :
 0 = no error
 1 = data not found
 2 = unknown file version
 3 = no OPL2 chip found}

begin
 o := 0;
 memuse := false;
 if p = nil then
 begin
   PlayBMFdata := 1;
   exit;
 end;
  move(ptr(seg(p^),ofs(p^))^,ID,sizeof(ID));
  inc(o,sizeof(id));
  move(ptr(seg(p^),ofs(p^)+o)^,FileVer,sizeof(FileVer));
  inc(o,sizeof(FileVer));

  fillchar(title,sizeof(title),0);
  fillchar(composer,sizeof(composer),0);


   cnt := 0;
   c := 0;
   repeat;
     c := mem[seg(p^):ofs(p^)+o+cnt];
     title[cnt+1] := chr(c);
     inc(cnt);
   until (c = 0) or (cnt = 41);
   inc(o,cnt);
   cnt := 0;
   c := 0;
  repeat;
    c := mem[seg(p^):ofs(p^)+o+cnt];
    composer[cnt+1] := chr(c);
    inc(cnt);
  until (c = 0) or (cnt = 41);
  inc(o,cnt);
  move(ptr(seg(p^),ofs(p^)+o)^,speed,1);
  inc(o);

  if (ID <> 'BMF') or (Filever <> '1.1') then
  begin
   PlayBMFdata := 2;
   exit;
  end;


{Read Instruments}
 move(ptr(seg(p^),ofs(p^)+o)^,iflag,sizeof(iflag));
 inc(o,sizeof(iflag));

 numinst := 0;
 bc := 4;
 z := 1;

 for bytec := 1 to 4 do  {Byte counter}
 begin
   for bc := 7 downto 0 do     {Bit counter}
   begin
      if getbit(iflag[bytec],bc) = 1 then      {is the bit set? Then load the instrument from file}
      begin
        fillchar(inst[z],sizeof(bmfinst),0);
        move(ptr(seg(p^),ofs(p^)+o)^,inst[z],sizeof(bmfinst));
        inc(o,sizeof(bmfinst));
        inc(numinst);
      end
      else
      begin                             {if not, then uses the standard instrument}
        fillchar(inst[z],sizeof(bmfinst),0);
        move(defaultvoice,inst[z],sizeof(bmfinst));
      end;
      inc(z);
   end;
  end;


  {Read the flag variable for the tracks}
  move(ptr(seg(p^),ofs(p^)+o)^,tflag,sizeof(tflag));
  inc(o,sizeof(tflag));

  music := ptr(seg(p^),ofs(p^)+o); {Pointer to musicdata}
  datasize := songsize-o;

  DecrunshStreams;               {Unpack compressed stream data}

  if not detectOPL2 then
  begin
   PlayBMFdata := 3;
   exit;
  end;

  StartBMFPlayer;

  PlayBMFdata := 0;

end;


Function PlayBMFfile(filename : string) : byte;
var bytec,cnt,c : byte;
{
 Errorcodes returned :
 0 = no error
 1 = file not found
 2 = read error
 3 = unknown file version
 4 = not enough mem
 5 = no OPL2 chip found}

begin
 memuse := false;
 if not fileexist(filename) then
 begin
   PlayBMFfile := 1;
   exit;
 end;

  assign(f,filename);
  reset(f,1);

  {Read Header}

  {$I-}
  blockread(f,ID,sizeof(ID));
  blockread(f,FileVer,sizeof(FileVer));

  fillchar(title,sizeof(title),0);
  fillchar(composer,sizeof(composer),0);
  cnt := 1;
  c := 0;

  repeat;
    blockread(f,c,1);
    title[cnt] := chr(c);
    inc(cnt);
  until (c = 0) or (cnt = 41);

  cnt := 1;
  c := 0;
  repeat;
    blockread(f,c,1);
    composer[cnt] := chr(c);
    inc(cnt);
  until (c = 0) or (cnt = 41);

  blockread(f,speed,1);
  {$I+}

  if IOResult <> 0 then
  begin
   close(f);
   PlayBMFfile := 2;
   exit;
  end;

  if (ID <> 'BMF') or (Filever <> '1.1') then
  begin
   close(f);
   PlayBMFfile := 3;
   exit;
  end;


{Read Instruments}
 blockread(f,iflag,sizeof(iflag));


 numinst := 0;
 bc := 4;
 z := 1;

 for bytec := 1 to 4 do  {Byte counter}
 begin
   for bc := 7 downto 0 do     {Bit counter}
   begin
      if getbit(iflag[bytec],bc) = 1 then      {is the bit set? Then load the instrument from file}
      begin
        fillchar(inst[z],sizeof(bmfinst),0);
        blockread(f,inst[z],sizeof(bmfinst));
        inc(numinst);
      end
      else
      begin                             {if not, then uses the standard instrument}
        fillchar(inst[z],sizeof(bmfinst),0);
        move(defaultvoice,inst[z],sizeof(bmfinst));
      end;
      inc(z);
   end;
  end;


  blockread(f,tflag,sizeof(tflag)); {Read the flag variable for the tracks}

  datasize := filesize(f)-filepos(f); {Calculate size}

  getmem(music,datasize);             {Reserve buffer}
  memuse := true;
  if music = Nil then
  begin
   close(f);
   PlayBMFfile := 4;
   exit;
  end;
  blockread(f,music^,datasize);  {Read the data into memory}
  close(f);                      {That's it for loading}
  DecrunshStreams;               {Unpack compressed stream data}

  if not detectOPL2 then
  begin
   PlayBMFfile := 5;
   exit;
  end;

  StartBMFPlayer;

  PlayBMFfile := 0;
end;


end.




