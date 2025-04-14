# ECS Architecture Refactoring Instructions

This code needs to adhere to locality and behavior patterns. The current architecture mixes concerns and spreads related functionality across different files, making it hard to maintain and extend.

1. Move Camera functionality to a single module. Camera data structure and update logic should be together, not split between ecs.zig and game.zig.

2. Separate rendering from ECS logic. Create a dedicated renderer that consumes ECS data but doesn't directly access internal data structures.

3. Consolidate World/ChunkedWorld implementations. Choose one approach and eliminate duplication.

4. Extract common chunk visibility calculation into a shared utility function used by both rendering and debugging.

5. Implement a more generic component system that doesn't require hardcoded component types in switch statements.

6. Create clear boundaries between systems. Each system should own its behavior and only communicate through well-defined interfaces.

7. Apply consistent abstraction levels within each module. Low-level implementation details should not mix with high-level game logic.

8. Encapsulate entity-component access patterns to reduce code duplication and maintain consistency.
