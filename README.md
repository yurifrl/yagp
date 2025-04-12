
## Architecture

### ECS

Entities: a unique integer
Components: structs of plain old data
Systems: normal functions

## Reference

- [daneelsan/minimal-zig-wasm-canvas](https://github.com/daneelsan/minimal-zig-wasm-canvas/tree/master)
    - A minimal example showing how HTML5's canvas, wasm memory and zig can interact.
    - Just wasm example, it does not use raylib nor builds native
- [raylib-zig/project\_setup.sh](https://github.com/Not-Nik/raylib-zig/blob/devel/project_setup.sh#L32C5-L32C42)
    - Raylib-zig project setup script, it has raylib wasm example
- [raylib-zig/emcc.zig](https://github.com/Not-Nik/raylib-zig/blob/devel/emcc.zig)
    - Not sure what this is for but it seems to build the wasm file
- [raylib-zig/build.zig](https://github.com/Not-Nik/raylib-zig/blob/devel/build.zig)
    - Raylib-zig build file, no wasm example
- [permutationlock/zig\_hello\_emcc: ](https://github.com/permutationlock/zig_hello_emcc/tree/main)
    - A hello world example that can build to target native targets and Emscriptenm
    - The simplest example on how to use the same code for native and wasm
- [Not-Nik/raylib-zig](https://github.com/Not-Nik/raylib-zig)
    - Raylib-zig repo. Manually tweaked, auto-generated raylib bindings for zig
- Zip Server
    - [7  Project 2 - Building a HTTP Server from scratch – Introduction to Zig](https://pedropark99.github.io/zig-book/Chapters/04-http-server.html)
    - [Writing a HTTP Server in Zig](https://www.pedaldrivenprogramming.com/2024/03/writing-a-http-server-in-zig/)
    - [Zig Bits 0x4: Building an HTTP client/server from scratch - Orhun's Blog](https://blog.orhun.dev/zig-bits-04/)
    - [TCP Server in Zig - Part 1 - Single Threaded](https://www.openmymind.net/TCP-Server-In-Zig-Part-1-Single-Threaded/)
        - Another web server example in Zig
        - This is very complete example, I should follow it sometime
- [jdah/zigsteroids: asteroids in zig](https://github.com/jdah/zigsteroids/tree/main)
    - Asteroids in Zig
- [ryupold/examples-raylib.zig: Example usage of raylib.zig bindings](https://github.com/ryupold/examples-raylib.zig)
    - Example usage of raylib.zig bindings
- [SimonLSchlee/zigraylib: a fairly minimal raylib zig example codebase using the zig package manager](https://github.com/SimonLSchlee/zigraylib/tree/main)
    - using c raylib?
- [SimonLSchlee/zigraylib: a fairly minimal raylib zig example codebase using the zig package manager](https://github.com/SimonLSchlee/zigraylib?tab=readme-ov-file)
- [raylib - cheatsheet](https://www.raylib.com/cheatsheet/cheatsheet.html)
- [Raylib 15 Game - Showcase - Ziggit](https://ziggit.dev/t/raylib-15-game/5233)
    - Nice examples, use as reference
- [Durobot/raylib-zig-examples: Raylib examples ported to Zig](https://github.com/Durobot/raylib-zig-examples)
    - That's a lot of examples
- [Hot-reloading with Raylib - Zig NEWS](https://zig.news/perky/hot-reloading-with-raylib-4bf9)
    - Hot reloading in zig

- Assets
    - [Town Sprites Pack | FREE by RedEyeGames](https://red-eye-games.itch.io/freetownspritespack?download)
        - Using
    - [City tilemap 32x32 by AvKov](https://avkov.itch.io/city-tilemap-32x32)
    - [City Pack - Top Down - Pixel Art by NYKNCK](https://nyknck.itch.io/citypackpixelart)
    - [Top Down City Pack by Buggy Studio](https://buggystudio.itch.io/top-down-city-pack)

- [SimCities and SimCrises - International City Gaming Conference keynote](https://molleindustria.org/GamesForCities/)
- [SimHacker/MicropolisCore: SimCity/Micropolis C++ Core](https://github.com/SimHacker/MicropolisCore)
    - [Micropolis Web Demo 1 - YouTube](https://www.youtube.com/watch?v=wlHGfNlE8Os
- [Building SimCity: How to Put the World in a Machine : r/SimCity](https://www.reddit.com/r/SimCity/comments/1dhrxrm/building_simcity_how_to_put_the_world_in_a_machine/)
    - Slack post with bunch of things
# Calorie couting app