# gbalua

A Game Boy Advance emulator written in Lua. The implementation follows [gbajs](https://github.com/endrift/gbajs), adapted for Lua's language and runtime differences.

## Requirements

- **Lua 5.4**
- **moongl** – OpenGL bindings for Lua (and its dependency **moonglfw** for window/input)

Install via LuaRocks:

```bash
luarocks install moongl
```

## Running

Place `bios.bin` in the project directory, then:

```bash
lua main.lua <rom.gba>
```


Press **ESC** to exit. Save files are stored in the current working directory.

## Current Status

- **Performance**: Runs slowly and needs optimization.
- **Audio**: Not implemented yet.
- **Video**: Software renderer implemented.
- **Save**: SRAM, Flash, and EEPROM save types supported.
