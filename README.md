# Yet Another Game Project

## Reference

### Zig + WebAssembly

- [Using Zig with WebAssembly | mjgrzymek's blog](https://blog.mjgrzymek.com/blog/zigwasm)
- [Zig in WebAssembly | Fermyon Developer](https://developer.fermyon.com/wasm-languages/zig)
- [WebAssembly With Zig, Pt. II - DEV Community](https://dev.to/sleibrock/webassembly-with-zig-pt-ii-ei7)
- [WebAssembly with Zig | Enarx](https://enarx.dev/docs/webassembly/zig)
- [Zig for WebAssembly guide | vExcess](https://vexcess.github.io/blog/zig-for-webassembly-guide.html)
- [daneelsan/minimal-zig-wasm-canvas](https://github.com/daneelsan/minimal-zig-wasm-canvas/tree/master)
  - A minimal example showing how HTML5's canvas, wasm memory and zig can interact
  - Just wasm example, it does not use raylib nor builds native
- [permutationlock/zig_hello_emcc](https://github.com/permutationlock/zig_hello_emcc/tree/main)
  - A hello world example that can build to target native targets and Emscriptenm
  - The simplest example on how to use the same code for native and wasm

### Raylib + Zig
- [Not-Nik/raylib-zig](https://github.com/Not-Nik/raylib-zig)
  - Manually tweaked, auto-generated raylib bindings for zig
- [raylib - cheatsheet](https://www.raylib.com/cheatsheet/cheatsheet.html)
- [raylib-zig/project_setup.sh](https://github.com/Not-Nik/raylib-zig/blob/devel/project_setup.sh#L32C5-L32C42)
  - Raylib-zig project setup script, it has raylib wasm example
- [raylib-zig/emcc.zig](https://github.com/Not-Nik/raylib-zig/blob/devel/emcc.zig)
  - Not sure what this is for but it seems to build the wasm file
- [raylib-zig/build.zig](https://github.com/Not-Nik/raylib-zig/blob/devel/build.zig)
  - Raylib-zig build file, no wasm example
- [ryupold/examples-raylib.zig](https://github.com/ryupold/examples-raylib.zig)
  - Example usage of raylib.zig bindings
- [SimonLSchlee/zigraylib](https://github.com/SimonLSchlee/zigraylib/tree/main)
  - A fairly minimal raylib zig example codebase using the zig package manager
- [Raylib 15 Game - Showcase - Ziggit](https://ziggit.dev/t/raylib-15-game/5233)
  - Nice examples, use as reference
- [Durobot/raylib-zig-examples](https://github.com/Durobot/raylib-zig-examples)
  - That's a lot of examples
- [Hot-reloading with Raylib - Zig NEWS](https://zig.news/perky/hot-reloading-with-raylib-4bf9)
  - Hot reloading in zig
- [jdah/zigsteroids](https://github.com/jdah/zigsteroids/tree/main)
  - Asteroids in Zig

### ECS (Entity Component System)
- [prime31/zig-ecs](https://github.com/prime31/zig-ecs/tree/master?tab=readme-ov-file)
- [Let's build an Entity Component System from scratch (part 1) | Hexops' devlog](https://devlog.hexops.com/2022/lets-build-ecs-part-1/)
- [Let's build an Entity Component System (part 2): databases | Hexops' devlog](https://devlog.hexops.com/2022/lets-build-ecs-part-2-databases/)
- [Hexops' devlog - ECS series](https://devlog.hexops.com/categories/build-an-ecs/)
- [SanderMertens/flecs](https://github.com/SanderMertens/flecs?tab=readme-ov-file)
  - A fast entity component system (ECS) for C & C++
- [Building an ECS #1: Where are my Entities and Components | by Sander Mertens](https://ajmmertens.medium.com/building-an-ecs-1-where-are-my-entities-and-components-63d07c7da742)
- [Building a fast ECS on top of a slow ECS - YouTube](https://www.youtube.com/watch?v=71RSWVyOMEY)

### Zig HTTP/TCP Server
- [Project 2 - Building a HTTP Server from scratch – Introduction to Zig](https://pedropark99.github.io/zig-book/Chapters/04-http-server.html)
- [Writing a HTTP Server in Zig](https://www.pedaldrivenprogramming.com/2024/03/writing-a-http-server-in-zig/)
- [Zig Bits 0x4: Building an HTTP client/server from scratch - Orhun's Blog](https://blog.orhun.dev/zig-bits-04/)
- [TCP Server in Zig - Part 1 - Single Threaded](https://www.openmymind.net/TCP-Server-In-Zig-Part-1-Single-Threaded/)
  - Another web server example in Zig
  - This is very complete example, I should follow it sometime

### City Simulation / SimCity
- [SimCities and SimCrises - International City Gaming Conference keynote](https://molleindustria.org/GamesForCities/)
- [SimHacker/MicropolisCore: SimCity/Micropolis C++ Core](https://github.com/SimHacker/MicropolisCore)
- [Micropolis Web Demo 1 - YouTube](https://www.youtube.com/watch?v=wlHGfNlE8Os)
- [Building SimCity: How to Put the World in a Machine : r/SimCity](https://www.reddit.com/r/SimCity/comments/1dhrxrm/building_simcity_how_to_put_the_world_in_a_machine/)
  - Slack post with bunch of things
- [osgcc/simcity: Will Wright's city simulator (renamed here as Micropolis)](https://github.com/osgcc/simcity)
  - Mirror of Don Hopkins' open source version

### Assets
- [Town Sprites Pack | FREE by RedEyeGames](https://red-eye-games.itch.io/freetownspritespack?download)
  - Using
- [City tilemap 32x32 by AvKov](https://avkov.itch.io/city-tilemap-32x32)
- [City Pack - Top Down - Pixel Art by NYKNCK](https://nyknck.itch.io/citypackpixelart)
- [Top Down City Pack by Buggy Studio](https://buggystudio.itch.io/top-down-city-pack)