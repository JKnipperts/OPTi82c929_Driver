Unit Misc;

{Some miscelaneous and useful features and replacements for Borland's crt unit.
In particular manipulation of single bits, output of numbers (hexadecimal, with leading zeros, as binary...), 
conversion of whole strings into capital letters as well as delay and keyboard routines to do without Borland's CRT.

{Version 1.7 - 07/27/2002  }


interface
uses crt;



const
 copyright : string = #10+#13+' Misc routines v1.7 (c) Jan Knipperts '+#10+#13;
 {Just a small copyright string so that I can see with which version of this unit an EXE file was created}


type
 {Types for bit operations :}
  bit = 0..1;
  bitnum = 0..7;
  bitnumw = 0..15;
  bitnumL = 0..31;




{Bit manipulation}

{For Bytes}
Procedure SetBit(var b:byte; n :bitnum; value :bit);
Function  GetBit(b : Byte; n : bitnum) : bit;

{For Words}
Procedure SetBitW(var w :word; n :bitnumw; value :bit);
Function  GetBitW(w :word; n : bitnumw) : bit;

{low and high nibble of a byte}
Function lonib(bt : byte) : byte;  {Gibt die unteren 4 Bit eines Byte}
Function hinib(bt : byte) : byte;  {Gibt die oberen 4 Bit eines Byte}

Procedure Binout(b : byte); {Prints a byte as binary code to the screen}
Function  UpperCase(low : string) : string; {Converts all chars in a string to capital letters}

{Numbers in hexadecimal
function hexn(h:byte) :string; {Nibble}
function hexb(h:byte) :string; {Byte}
function hexw(h:word) :string; {Word}


Function hoch(z1,z2 : word) : longint;  {Returns the exponent}
Function addzero(b : byte) : string; {prefixes numbers with a 0}
Function removezeros (s : string) : string; {Removezeros}
Function addspace (b : byte) : string; {prefixes numbers with spaces}

Function fileexist(name : string) : boolean; {Just a short check if a file exists}

{Keyboard}
Procedure  Keybon;   {Enables Keyboard}
Procedure  Keyboff;  {Disables Keyboard}

Function  Getkey : char; {Same as CRT's "readkey"}
Function  Catchkey : char;   {Reads a keypress for the keyboard buffer but does not wait until a key is pressed}
Function  IsKeypressed : boolean; {same as crt's keypressed. True if a key has been pressed by the user}
Procedure WaitKey; {Holds the program until the user presses any key}

{Controll of the PC Speaker}

Procedure SpkSound(Hz : word);   {Plays the provided frequency}
Procedure SpkNosound;  {Disbles speaker}

Procedure Xdelay(ms : word); {Replacement for Borland's delay routine. Works reliably even on fast processors}







implementation


Procedure SetBit(var b:byte; n :bitnum; value :bit);
begin
   if value = 1 then
      b:= b or (1 shl n)
   else
      b:= b and not (1 shl n);
end;

Function  GetBit(b : Byte; n : bitnum) : bit;
begin
  getBit := bit(odd(b shr n));
end;


Procedure SetBitW(var w :word; n :bitnumw; value :bit);
begin
   if value = 1 then
      w := w or (1 shl n)
   else
      w := w and not (1 shl n);
end;


Function  GetBitW(w :word; n : bitnumw) : bit;
begin
  getBitW := bit(odd(w shr n));
end;


Procedure Binout(b : byte);
var bc : byte;
begin
 for bc := 7 downto 0 do
 begin
  write(byte(getbit(b,bc)));
 end;
end;


function lonib(bt : byte) : byte; 
var res,bitc : byte;
begin
  res := 0;
  for bitc := 0 to 3 do
  begin
   if getbit(bt,bitc) = 1 then
   begin
    setbit(res,bitc,1);
   end;
  end;
  lonib := res;
end;

function hinib(bt : byte) : byte; 
var res,bitc : byte;
begin
  res := 0;
  for bitc := 3 to 7 do
  begin
   if getbit(bt,bitc) = 1 then
   begin
    setbit(res,bitc,1);
   end;
  end;
  hinib := res;
end;



Function UpperCase(low : string) : string;
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


Function hexn(h:byte):string;   
const
  hexChars: array [0..$F] of Char =
    '0123456789ABCDEF';
begin
  hexn := hexChars[h and $F];

end;



function hexb(h:byte):string;   
const
  hexChars: array [0..$F] of Char =
    '0123456789ABCDEF';
begin
   hexb := hexChars[h shr 4]+
           hexChars[h and $F];
end;


function hexw(h:word):string;   
const
  hexChars: array [0..$F] of Char =
    '0123456789ABCDEF';
begin
    hexw := hexChars[hi(h) shr 4]+
            hexChars[hi(h) and $F]+
            hexChars[Lo(h) shr 4]+
            hexChars[Lo(h) and $F];
end;




Function hoch(z1,z2 : word) : longint;
var d,d1 : word;
begin

d1 := z1;

 for d := 1 to z2 do
 begin
  d1 := d1*z1;
 end;

 hoch := d1;
end;



Function fileexist(name : string) : boolean;
var tf : file;
begin
 fileexist := true;
{$I-}
 assign(tf,name);
 reset(tf,1);
 close(tf);
{$I+}
 If IOResult <> 0 then fileexist := false;
end;

function addspace (b : byte) : string;
var
  c2 : string[3];
begin
  STR (b, c2);
   if b < 10 then
   begin
    c2 := '  ' + c2;
   end
   else
   begin
    if (b >= 10) and (b < 100) then
    c2 := ' ' + c2;
   end;

  addspace := c2
end; {addspace}



function addzero (b : byte) : string;
var
  c2 : string[3];
begin
  STR (b, c2);
   if b < 10 then
   begin
    c2 := '00' + c2;
   end
   else
   begin
    if (b >= 10) and (b < 100) then
    c2 := '0' + c2;
   end;

  addzero := c2
end; {addzero}


Function Removezeros (s : string) : string;
var cnt : byte;
begin
 cnt := 1;
 while s[cnt] = '0' do inc(cnt);
 removezeros := copy(s,cnt,length(s));
end;




{ KEYBOARD }

procedure KeybOn;
assembler;
asm
  in al,21h
  and al,11111101b
  out 21h,al
end;

procedure KeybOff;
assembler;
asm
  in al,21h
  or al,00000010b
  out 21h,al
end;

function IsKeyPressed:boolean;
begin
  asm
    mov        ah,1
    int        16h
    jnz        @true
    mov        [@result],false
    jmp        @end
@true:
    mov        [@result],true
@end:
  end;
end;

function GetKey:char;
assembler;
asm   {OK}
  xor ah,ah
  int 16h
  cmp al,0
  jne @quit
  mov al,ah
@Quit:
end;


function Catchkey : char;
begin
 if iskeypressed then Catchkey := getkey;
end;


Procedure WaitKey;
begin
 while iskeypressed do getkey;
 repeat until iskeypressed;
end;


{ PC SPEAKER }

procedure SpkNoSound;
assembler;
asm
  in al,61h
  and al,0fch
  out 61h,al
end;

procedure SpkSound(hz:word);
assembler;
asm
  mov bx,hz
  mov ax,34ddh
  mov dx,0012h
  cmp dx,bx
  jnc @2
  div bx
  mov bx,ax
  in al,61h
  test al,3
  jnz @1
  or al,3
  out 61h,al
  mov al,0b6h
  out 43h,al
@1:
  mov al,bl
  out 42h,al
  mov al,bh
  out 42h,al
@2:
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







end.
