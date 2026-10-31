# Cyto

Cyto is an offline, native macOS desktop companion and ambient lifeform designed to introduce organic physical behavior and focus dynamics directly onto the operating system canvas.

Unlike standard utilities or static status bar apps, Cyto operates as a living digital entity suspended in user-space. It interacts directly with the spatial boundaries of open application windows, dynamically adjusting its behavioral states, physical movements, and energy levels according to user workflow cadence and system idle metrics.

## Concept and Architecture

Cyto is engineered to bridge sensory interaction, procedural physics, and non-intrusive ambient companionship on Apple Silicon hardware.

### Spatial Window Awareness
Cyto treats the macOS desktop as a physical topographical landscape. Utilizing core graphics window server boundaries, it calculates the bounding frames of visible application windows. Cyto can navigate along title bars, traverse window headers, sit upon borders, and react to window repositioning. When underlying support surfaces are closed or minimized, standard gravitational acceleration and rebound dampening determine its trajectory to the next available surface or the system Dock.

### Cadence and Focus Feedback
The core behavioral engine monitors workflow rhythm through low-overhead, privacy-first system metrics:
- Flow State: Sustained keyboard input and active application engagement soothe the entity, transitioning it into resting, observation, or contented animation modes.
- Distraction and Idle States: Prolonged inactive intervals or sporadic erratic inputs trigger curiosity, restlessness, wandering, or attention-seeking behaviors across the screen perimeter.
- Zero Inspection: Behavioral states are driven strictly by timing differentials and idle durations. No keystroke content, input buffer, or window text is ever captured, logged, or processed.

### Non-Intrusive Overlay Integration
Cyto renders on a dedicated borderless, transparent floating window level (`NSPanel`). The view surface dynamically manages mouse interaction boundaries:
- Transparent Passthrough: Areas outside the entity permit full click-through to underlying applications, IDEs, and browsers without disrupting active workflows.
- Direct Interaction: Engaging directly with the entity enables manual repositioning, kinetic tossing with inertia, and tactile petting gestures.

### Haptic and Sensory Coupling
When interacting with Cyto via the trackpad, force feedback patterns are dispatched directly to the Force Touch actuator, generating physical tactile responses such as purring or pulse feedback.

## Privacy and System Footprint

- Completely Offline: Built with zero network dependencies, analytics endpoints, or telemetry services.
- Resource Efficient: Renders procedurally with dynamic frame-rate throttling. When the entity is idle or sleeping, rendering throttles down to minimal refresh rates to preserve battery efficiency.
- Sandboxed and Non-Invasive: Runs entirely in user-space without kernel extensions, administrative privileges, or memory injection into foreign processes.

## Development Status

This project is currently under active development. It is in an experimental state and is not recommended for running at this stage. Core subsystems, physics algorithms, and behavioral models are subject to continuous restructuring.

---

A project by Hariom Sharnam
