## Optimized MAD16 PRO (OPTi 82c929) Sound controller initialisation


Join me on a real oldschool / retro project:

Sound cards with a sound controller of type 82c929 (MAD16 PRO) were widely used
in the mid 90s. These cards support the Windows Sound System mode, 
which with 48 kHz, 16 bit stereo sound exceeds the capabilities of a SB 16, 
as well as the Sound Blaster Pro standard, which was widespread in games at 
that time. 
Back in the day many manufacturers began to focus on driver support for Windows,
and DOS drivers are often poorly programmed and just made to maintain 
compatibility. Also further developed codecs were used for these sound card, 
which are not fully supported by the previous drivers. 
This makes it difficult for today's friends of old hardware to get these sound 
cards to work properly. 
I therefore decided to program my own DOS driver, which lets the user change 
all possible settings and configure his sound card optimally.

Greetings and thanks go to the community of https://dosreloaded.de. 

The driver is written in Pascal and inline assembly and uses some units for 
FM sound, fast screen handling in textmode, sound blaster stuff and more that I have written 
during the late 90's and early 2000s.


My driver consists of the following programs:

SETUP.EXE
Allows the comfortable configuration of the sound card. 
On the first screen you can set the default configuration for Sound Blaster, 
WSS, the MPU401 midi interface and a CD-ROM drive connected to the card.

929INIT.EXE
This program initializes the sound card with the settings stored in the setup. 
The mode of the sound card can also be easily changed from the command line.

MIXER.EXE
Allows you to adjust the volume, configure the sound card's inputs for 
recording, and perform a sound check.

SBFIX.COM
A small, memory-resident program that forces the sound card to output in stereo
in Sound Blaster mode. 
Some games have problems with stereo output with OPTi929 soundcards, this small
program can help to fix this issue.  Just run it before starting the game. 

## The Setup:

![Alt text](https://github.com/JKnipperts/OPTi82c929_Driver/blob/master/screen_001.png?raw=true "Title")

## The Mixer:

![Alt text](https://github.com/JKnipperts/OPTi82c929_Driver/blob/master/screen_002.png?raw=true "Title")
