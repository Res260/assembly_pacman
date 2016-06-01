Assembly PacMan
===============

The software is basically Pacman and ghosts running around the screen
and derping. Player 1 controls PacMan and Player 2 controls the ghosts.
If player 1 presses A, it toggles the tactical flight mode and Pacman leads
the ghosts to fight for freedom. The toggle is very sensitive so press fast.

This is a project I did for my "Operating Systems 2" class. It is written in
6502 assembly (the same as the NES console).

Although I wrote most of the code, I started  with Modele.asm, a file written 
by François Allard (@BinarMorker). 

Compilation
-----------

To compile the code, you'll need to use nesasm, which I include in this repo.
run "Compile.bat" to compile the program. You might need to change the path in
compile.bat to make it work. It will create a .nes file.

Installation
------------

To run the application, you need to download the FCEUX NES emulator
here: ( http://www.fceux.com/web/download.html ). You need to open the nes file
you made with FCEUX and it will run the game.
