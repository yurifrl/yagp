# Entity Component System Design

## Core Concepts

### Entity
- An identifier (ID) that references a collection of components
- No behavior, just a way to group components

```zig
const Entity = struct {
    id: u64,
};
```

### Component
- Pure data, no behavior
- Defines attributes of entities
- Typed data structures

```zig
const Position = struct {
    x: f32,
    y: f32,
};

const Building = struct {
    type: u8,
    level: u8,
};

const Resource = struct {
    type: u8,
    amount: i32,
};
```

### System
- Contains logic that operates on entities with specific components
- Processes entities in a DAG (Directed Acyclic Graph) order

```zig
fn resourceSystem(world: *World) void {
    // Get all entities with Position and Building components
    var query = world.query(.{Position, Building});
    while (query.next()) |entity| {
        // Process building production based on type and level
        if (entity.get(Building).type == RESOURCE_PRODUCER) {
            world.produce(entity, entity.get(Building).level);
        }
    }
}
```

## Design Principles

### Performance Considerations

1. **Cache Coherency**
   - Group similar components together in memory
   - Avoid hash maps for core data paths
   - Use arrays for component storage

2. **Archetype-based Storage**
   - Entities with identical component types share a table
   - Tables contain densely packed component arrays
   - No gaps for missing components

```zig
// Conceptual view of archetype storage
const PositionBuildingArchetype = struct {
    entities: []Entity,
    positions: []Position,
    buildings: []Building,
};
```

3. **Efficient Iteration**
   - Only iterate over entities with required components
   - Avoid checking if components exist during iteration
   - Minimize pointer chasing

### Implementation Strategy

1. **World Structure**
   - Manages all entities and archetypes
   - Provides query interface for systems

```zig
const World = struct {
    archetypes: ArrayList(Archetype),
    // Maps component types to archetypes containing them
    componentToArchetypes: HashMap(TypeId, ArrayList(ArchetypeId)),

    pub fn query(self: *World, comptime ComponentTypes: anytype) Query(ComponentTypes) {
        // Find archetypes containing all requested components
        // Return iterable query object
    }
};
```

2. **Chunked World Extension**
   - For large-scale simulations, spatially divide the world into chunks
   - Each chunk manages a subset of entities based on their position

```zig
const ChunkCoord = struct {
    x: i32,
    y: i32,
};

const Chunk = struct {
    entity_ids: []u64,
};

const ChunkedWorld = struct {
    world: World,
    chunks: HashMap(ChunkCoord, Chunk),
    chunk_size: i32,

    pub fn getChunkCoord(pos: Position) ChunkCoord {
        return ChunkCoord{
            .x = @intFromFloat(pos.x) / chunk_size,
            .y = @intFromFloat(pos.y) / chunk_size,
        };
    }

    pub fn assignToChunk(self: *ChunkedWorld, entity: Entity, pos: Position) void {
        const coord = self.getChunkCoord(pos);
        // insert entity ID into chunk
    }
};
```

3. **Component Registration**
   - Use generics for type safety
   - Avoid runtime type assertions

4. **Entity Management**
   - Create/destroy entities
   - Add/remove components (involves moving between archetypes)

```zig
// Adding a component moves entity to new archetype
pub fn addComponent(world: *World, entity: Entity, component: anytype) void {
    const sourceArchetype = world.getEntityArchetype(entity);
    const destArchetype = world.getOrCreateArchetype(sourceArchetype.types + @TypeOf(component));

    // Copy existing components
    // Add new component
    // Update entity location
}
```

## Query System

```zig
const Query = struct {
    archetypes: []Archetype,
    current_archetype: usize = 0,
    current_index: usize = 0,

    pub fn next(self: *Query) ?EntityRef {
        // Iterate through matching archetypes
        // Return reference to entity and its components
    }
};
```

## Performance Considerations

1. **Batch Operations**
   - Add/remove components in batches
   - Component changes require moving entities between archetypes

2. **Memory Layout**
   - Dense arrays for component data
   - Minimal indirection (pointer chasing)

3. **System Scheduling**
   - Systems form a directed acyclic graph (DAG)
   - Dependencies determine execution order

```zig
const SystemGraph = struct {
    systems: []System,
    dependencies: [][]usize,

    pub fn execute(self: *SystemGraph, world: *World) void {
        // Execute systems in topological order
    }
};
```

## Chunk-Based Simulation Benefits

- **Scalability**: Partitioning the simulation world allows for managing millions of entities efficiently.
- **Parallelism**: Independent chunks can be processed in parallel without conflicts.
- **Culling & Streaming**: Only simulate and render active chunks, improving performance and memory use.
- **Modular Simulation**: Systems can target chunks individually, allowing frequency and priority tuning per region.

This hybrid model of archetype ECS with chunked spatial locality is ideal for city builders, RTS games, and large simulations where scale and responsiveness are critical.
