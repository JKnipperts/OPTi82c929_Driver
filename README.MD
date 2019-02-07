## Optimized MAD16 PRO (OPTi 82c929) Sound controller initialisation


Join me on a real oldschool / retro project:

Sound cards with a sound controller of type 82c929 (MAD16 PRO) were widely used in the mid 90s. These cards support the Windows Sound System mode, which with 48 kHz, 16 bit stereo sound exceeds the capabilities of a SB 16, as well as the Sound Blaster Pro standard, which was widespread in games at that time. 
Back in the day many manufacturers began to focus on driver support for Windows, and DOS drivers are often poorly programmed and just made to maintain compatibility. Also further developed codecs were used for these sound card, which are not fully supported by the previous drivers. This makes it difficult for today's friends of old hardware to get these sound cards to work properly. 
I therefore decided to program my own DOS driver, which lets the user change all possible settings and configure his sound card optimally.

## Features:
- You can switch between Windows Sound System and Sound Blaster mode directly from the command line (or from a batch file). 
- The driver offers many options to solve the most common problems with these sound cards:
  - The user can configure ALL settings, including reserved bits, of the chip in a convenient setup program. 
    What is a significantly  improved Sound Blaster Pro compatibility is possible in many games.
  - Some codecs do not fully calibrate at first start, resulting in distorted sound output. 
    It is therefore often recommended to initialize the sound card twice. 
    I have implemented an option for this: With the parameter /N the number of desired initializations can be specified. 
  - While the OPTi 929 imitates the Sound Blaster Pro DSP very well, the imitation of the mixer chip is unfortunately faulty. 
    This can be seen by problems with the volume settings and the playback of stereo sound in some programs written for the SB Pro. 
    This driver offers a mixer that bypasses the Sound Blaster mixer in the OPTi 929 and changes the volume directly in the codec, 
    as well as a small TSR program that acts as a watchdog for the stereo output.


## The driver consists of four main programs:

### SETUP
Allows the comfortable configuration of the sound card. 
On the first screen you can set the default configuration for Sound Blaster, 
WSS, the MPU401 midi interface and a CD-ROM drive connected to the card.

### 929INIT
This program initializes the sound card with the settings stored in the setup. 
The mode of the sound card can also be easily changed from the command line.

### MIXER
Allows you to adjust the volume, configure the sound card's inputs for recording, and perform a sound check.

### SBFIX
A small, memory-resident program that forces the sound card to output in stereo in Sound Blaster mode. 
Some games have problems with stereo output with OPTi929 soundcards, this small program can help to fix this issue.
Just run it before starting the game. 


## The source code
The actual driver is written in Borland Pascal with use of inline assembler. SBFIX is written in pure x86 Assembler code, use NASM to compile it.


The main code to interact with the hardware is contained in these two files:

### OPTI929.PAS 
This file contains all functions to initialize and (re)configure the OPTi 82C929 sound controller.

### AD1848.PAS 
Here you can find all the code needed to interact with an Analog Devices AD1848 compatible codec.  
This unit can be used to play Audiodata through the Windows Sound System (see the use in MIXER.PAS for an example). 

The datasheets for the OPTi 82c929 and it's supported codecs can be found in the DOCS folder.

For FM sound, screen handling in textmode, Sound Blaster and Midi stuff etc. I mostly used old source code that I originally wrote in the late 90s and early 2000s.

### OPL.PAS 
Code to interact with  Yamaha YM 3812/ YMF262 (OPL2/OPL3) Soundchips

### BMF.PAS 
Player for *.bmf Adlib tunes

### MPU.PAS 
Code to interact with Roland MPU 401 Midi interface

### SBPRO.PAS
All necessary code to interact with an Sound BLaster Pro compatible card and it's mixer.

### TEXTMODE.PAS 
Fast drawing routines for the 80x25 Textmode. Replacement of Borlands CRT unit.

### MISC.PAS  
Some misc routines. For example bit manipulation, timing, displaying hex numbers...


## Some Screenshots
### The Setup
![Alt text](https://github.com/JKnipperts/OPTi82c929_Driver/blob/master/screen_001.png?raw=true "Title")

### The Mixer
![Alt text](https://github.com/JKnipperts/OPTi82c929_Driver/blob/master/screen_002.png?raw=true "Title")

Thanks and greetings go to the community of https://dosreloaded.de  With their feedback and suggestions for improvement, they have always made me continue and improve this project. Without the support from the forum, this would probably have been just a simple attempt to initialize a soundcard with my own program.
