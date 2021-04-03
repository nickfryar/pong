# PONG for NES

### About
Just what it sounds like - a simple Pong game for the NES written in 6502 assembly. It's nothing fancy, but it could be used as a starting point for other projects.

### Build Instructions
You will need [cc65](https://cc65.github.io/) to build this. Once installed, run:

`ca65 game.asm -o game.o --debug-info`

`ld65 game.o -o game.nes -t nes --dbgfile game.dbg`

Note that you may need to copy the *nes.cfg* file to the project directory (found in cc65/cfg).