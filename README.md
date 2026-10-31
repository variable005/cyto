# Cyto

![Cyto Desktop Pet Banner](Cyto%20Desktop%20Pet%20README%20Banner.png)

Cyto is an offline, native macOS desktop companion and ambient lifeform designed to introduce organic physical behavior, spatial awareness, and real-time focus dynamics directly onto the operating system canvas.

Unlike standard utilities or static status bar apps, Cyto operates as a living digital entity suspended in user-space. It interacts directly with the spatial boundaries of open application windows, dynamically adjusting its behavioral states, physical movements, and energy levels according to user workflow cadence and system idle metrics.

## Concept and Philosophy

Cyto is engineered to bridge sensory interaction, procedural physics, and non-intrusive ambient companionship on Apple Silicon hardware without requiring network connectivity, telemetry, or invasive permissions.

- Spatial Topography: Window title bars, IDE headers, and browser frames serve as physical surfaces and walkable ledges.
- Dynamic Cadence: Real-time hardware typing frequency and mouse gaze tracking influence emotional states and energy levels.
- Non-Invasive Integration: Dedicated compact floating surface (`NSPanel`) with circular hit-testing allows uninterrupted click-through to background applications.

---

## Architecture Overview

Cyto utilizes a decoupled modular architecture executed on a 60Hz run loop simulation timer. The system orchestrates low-overhead window tracking, zero-permission hardware telemetry, ethereal kinematics, an emotion cycling state machine, and a vector rendering pipeline.

```
+-----------------------------------------------------------------------------------------+
|                                    Cyto Runtime Loop                                    |
|                                                                                         |
|  [Hardware Telemetry]         [Window Server]                  [User Input]             |
|   CGEventSource Key/Mouse      kCGWindowListCopyWindowInfo      Mouse Drag / Pet Taps   |
|            |                               |                             |              |
|            v                               v                             v              |
|     ActivityEngine                   WindowTracker                   CytoView           |
|            |                               |                             |              |
|            +---------------+---------------+-----------------------------+              |
|                            |                                                            |
|                            v                                                            |
|                     CytoController (60Hz Tick)                                          |
|                            |                                                            |
|            +---------------+---------------+                                            |
|            |                               |                                            |
|            v                               v                                            |
|      PhysicsEngine               EmotionCycleEngine                                     |
|    (Ethereal Aerodynamics)      (Typing Progression)                                    |
|            |                               |                                            |
|            +---------------+---------------+                                            |
|                            |                                                            |
|                            v                                                            |
|                       CytoEntity (Single Source of Truth)                               |
|                            |                                                            |
|            +---------------+---------------+                                            |
|            |                               |                                            |
|            v                               v                                            |
|        CytoView                      MenuBarController                                  |
|   (CoreGraphics Canvas)              (NSStatusItem)                                     |
|            |                                                                            |
|            v                                                                            |
|       OverlayPanel (NSPanel Level .floating)                                            |
|                                                                                         |
+-----------------------------------------------------------------------------------------+
```

---

## Data Flow Diagram (DFD)

### Level 0: Context Diagram

The context diagram illustrates boundary interactions between external operating system services, user input sources, and the Cyto companion application.

```mermaid
flowchart TD
    UserHW([User Hardware Inputs]) -->|Keystroke & Mouse Activity| OSServices[macOS System & WindowServer]
    OSServices -->|CGEventSource Idle Clocks| CytoApp[Cyto Companion Engine]
    OSServices -->|Window Frame Topography| CytoApp
    UserHW -->|Direct Drag & Pet Gestures| CytoApp
    CytoApp -->|Vector Drawing & Speech Bubbles| Overlay[Transparent Floating NSPanel]
    CytoApp -->|Mood & Accessory Menu| StatusItem[macOS Menu Bar Item]
    CytoApp -->|Haptic Impulses| Actuator[Force Touch Trackpad]
    Overlay -->|Visual Frames| Screen([Desktop Display Canvas])
```

### Level 1: Subsystem Data Flow Decomposition

The Level 1 decomposition demonstrates how hardware telemetry, spatial queries, and physics simulations flow into the core entity state and are dispatched to the view layer.

```mermaid
flowchart TD
    subgraph Inputs["External Sensory Inputs"]
        E1[CGEventSource: Event Type KeyDown]
        E2[CGEventSource: Event Type MouseMoved]
        E3[CGWindowListCopyWindowInfo]
        E4[NSEvent Mouse Tracking]
    end

    subgraph SensoryPipelines["1.0 Sensory & Topography Engines"]
        P1[1.1 ActivityEngine: Idle Duration & Focus Tier]
        P2[1.2 WindowTracker: Visible Window Bounds Filter]
        P3[1.3 Keystroke Cadence & KPS Tracker]
    end

    subgraph Storage["State Storage"]
        D1[(Ledge Cache: Walkable Surfaces)]
        D2[(CytoEntity: Single Source of Truth)]
    end

    subgraph Processing["2.0 Behavioral & Physical Engines"]
        P4[2.1 PhysicsEngine: Gravity, Glide & Squish]
        P5[2.2 EmotionCycleEngine: Typing Progression]
        P6[2.3 Autonomous Decision State Machine]
    end

    subgraph Output["3.0 Presentation & Surface Dispatch"]
        P7[3.1 CytoView: CoreGraphics Procedural Vector Renderer]
        P8[3.2 OverlayPanel: Screen Position Coordinate Sync]
        P9[3.3 MenuBarController: Status & Expression Selector]
    end

    E1 --> P1
    E1 --> P3
    E2 --> P1
    E3 --> P2
    E4 --> P7

    P1 -->|Focus Tier & Idle Seconds| D2
    P2 -->|Walkable Headers| D1
    P3 -->|Burst Count & Cadence KPS| P5

    D1 -->|Geometry Coordinates| P4
    D2 -->|Velocity & Position| P4
    P4 -->|Updated Kinematics| D2

    P5 -->|Expression & Head Tilt| D2
    P6 -->|Behavior Transitions| D2

    D2 -->|Coordinates, Phases & Mood| P7
    D2 -->|Physical Coordinates| P8
    D2 -->|Current State & Focus| P9
```

---

## Domain Model and Component Relationships

The domain model outlines the object-oriented runtime architecture, illustrating how the core controller binds telemetry engines, dynamic entity states, physics ledge boundaries, and AppKit presentation layers.

```mermaid
classDiagram
    class CytoController {
        -CytoEntity entity
        -WindowTracker windowTracker
        -PhysicsEngine physicsEngine
        -ActivityEngine activityEngine
        -OverlayPanel overlayPanel
        -CytoView cytoView
        -MenuBarController menuBarController
        +start()
        +tick()
    }

    class CytoEntity {
        +CGPoint position
        +CGVector velocity
        +CGSize size
        +CGFloat squishX
        +CGFloat squishY
        +CGFloat floatPhase
        +CGFloat wispPhase
        +CGFloat headphoneGlowPhase
        +CGPoint eyeOffset
        +CGFloat blinkFactor
        +Double typingTimer
        +CGFloat curiousTilt
        +String speechBubbleText
        +Double speechBubbleTimer
        +Double stateTimer
        +Double stateDuration
        +Double blinkTimer
        +Double breathPhase
        +Double walkPhase
        +Bool isBeingInteractedWith
        +CGFloat affection
    }

    class Ledge {
        +CGRect rect
        +CGFloat topY
        +CGFloat minX
        +CGFloat maxX
    }

    class CytoState {
        <<enumeration>>
        idle
        walking
        sitting
        sleeping
        falling
        bouncing
        dragged
        petted
        curious
        mischievous
    }

    class CytoMood {
        <<enumeration>>
        calm
        happy
        sleepy
        playful
    }

    class FocusTier {
        <<enumeration>>
        inFlow
        steady
        wandering
        idle
    }

    class JellyExpression {
        <<enumeration>>
        neutral
        happy
        excited
        curious
        sleepy
        focused
        surprised
        confused
    }

    class JellyAccessory {
        <<enumeration>>
        none
        coffee
        coding
    }

    class OverlayPanel {
        +NSRect frame
        +Int windowNumber
        +Bool ignoresMouseEvents
    }

    class CytoView {
        +CGPoint dragStartMouseScreen
        +CGPoint dragStartEntityPos
        +Date lastDragTime
        +Int petCounter
    }

    class WindowTracker {
        +fetchWalkableLedges()
    }

    class PhysicsEngine {
        +update()
    }

    class ActivityEngine {
        +updateFocusTier()
    }

    class MenuBarController {
        +update()
    }

    CytoController --> CytoEntity : manages
    CytoController --> WindowTracker : queries
    CytoController --> PhysicsEngine : steps
    CytoController --> ActivityEngine : samples
    CytoController --> OverlayPanel : positions
    CytoController --> MenuBarController : syncs
    OverlayPanel *-- CytoView : embeds
    CytoView --> CytoEntity : renders

    CytoEntity --> CytoState : exhibits
    CytoEntity --> CytoMood : experiences
    CytoEntity --> FocusTier : reflects
    CytoEntity --> JellyExpression : displays
    CytoEntity --> JellyAccessory : equips
    CytoEntity ..> Ledge : perches on
```

---

## State Transition & Emotion Cycling Diagram

Cyto cycles dynamically through emotional expressions based on typing progression, typing velocity (keystrokes per second), and pause duration.

```mermaid
stateDiagram-v2
    [*] --> Idle

    state "Idle & Neutral" as Idle {
        [*] --> CalmObserving
        CalmObserving --> GazeTracking : Mouse moves
    }

    state "Emotion Cycling Engine (Typing Session)" as TypingSession {
        [*] --> Curious : Keystrokes 1 to 3 (Wake & Tilt)
        Curious --> Focused : Keystrokes 4 to 12 (Determined Squint)
        Focused --> Excited : Keystrokes 13+ with KPS > 3.2 (Star Eyes)
        Focused --> Confused : Pause 0.35s to 1.2s after moderate burst
        Excited --> Surprised : Sudden pause 0.35s to 1.2s after sprint
        Confused --> Happy : Pause 1.2s to 3.5s (Thought Completed)
        Surprised --> Happy : Pause 1.2s to 3.5s (Thought Completed)
        Happy --> Neutral : Inactive > 3.5s (Return to Calm)
    }

    state "Resting & Sleep" as SleepState {
        [*] --> CozyResting : Inactivity > 60s
        CozyResting --> SleepingZzz : Ascending Z particles
    }

    Idle --> TypingSession : Hardware KeyDown Detected
    TypingSession --> Idle : Inactivity > 3.5s
    Idle --> SleepState : Idle timeout reached
    SleepState --> Curious : KeyDown detected (Instant Wake)
    
    Idle --> Walking : Autonomous exploration
    Walking --> Idle : Ledge boundary reached
    
    Idle --> Dragged : Mouse click on entity
    Dragged --> Falling : Mouse released with inertia
    Falling --> Idle : Surface contact collision
```

---

## Subsystem Details

### 1. Spatial Window Topography
- Window Boundary Extraction: Queries `kCGWindowListOptionOnScreenOnly` via CoreGraphics to compute bounding rectangles of on-screen application windows.
- Ledge Filtering: Excludes transparent overlay surfaces and desktop utility layers to identify genuine structural headers and application title bars.
- Gravitational Perching: Coordinates collision boundaries with soft ectoplasm squish recovery upon touchdown.

### 2. Zero-Permission Real-Time Cadence Engine
- Non-Invasive Telemetry: Samples `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)` on each simulation tick. This inspects only monotonic OS hardware idle clocks without reading key buffers, capturing text, or requiring Accessibility privileges.
- Multi-Phase Emotion Lifecycle: Evaluates burst velocity, keystroke density, and hesitation pauses to cycle expressions through Curious, Focused, Excited, Confused, Surprised, Happy, and Neutral modes.
- Cadence-Aware Praise: Dispatches dialogue bubbles only after substantial sustained focus sprints (25+ keys) with built-in cooldowns (50 seconds) to prevent distraction.

### 3. Procedural Vector Rendering
- Ethereal Vector Geometry: Generates a seamless dome-headed ghost sheet with ambient lavender gradients (`#FFFFFF` to `#D8D0E8`) and 4 harmonic rippling bottom hem wisps.
- Studio Headphones: Features an obsidian headband anchored directly to the dome geometry with pulsing neon violet LED ring lighting (`#C084FC`).
- Adaptive Perching: When perched on a title bar or resting, bottom wisps calm down, eyelids close softly, and floating sleep particles ascend smoothly.

### 4. Animated Speech Bubble System
- Spring Pop-In: Uses an elastic overshoot curve to bounce speech bubbles into view.
- Ambient Hover: Floats synchronously alongside physical hover oscillations.
- Dissolving Fade-Out: Shrinks and floats upward into opacity zero, dissolving cleanly without cutting off abruptly.

### 5. Interactive Hit-Testing & Accessibility
- Circular Radial Hit-Test: Constrains mouse interaction to a 52-point radius centered on the entity body. All clicks outside this perimeter pass cleanly through to background windows, editors, and web pages.
- Direct Tapping: Clicking directly on Cyto prompts cheerful dialogue, friendly expressions, and physical hops.
- Optional Accessibility Integration: Users can enable optional system-level Return/Enter key tracking via the menu bar item for dedicated submission reactions.

---

## Technical Specifications

| Component | Specification |
| :--- | :--- |
| Target Platform | macOS 13.0 or higher (Ventura, Sonoma, Sequoia) |
| Architecture | Native Apple Silicon (ARM64) and Universal Binary |
| Primary Language | Swift 5.9+ / Swift 6 |
| User Interface Framework | AppKit / CoreGraphics Vector Engine |
| Network Permissions | None (100% Offline, Zero Sockets, Zero Telemetry) |
| Security Model | Standard User-Space Execution (Zero Elevated Privileges / Zero Kernel Extensions) |
| System Footprint | Under 30 MB Resident Memory, Throttled CPU Footprint |

---

## Development Status

This project is currently under active development. Core subsystems, physics algorithms, and behavioral models are subject to continuous restructuring.

---

## Disclaimer

This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the author or copyright holder be held liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

---

A project by Hariom Sharnam
