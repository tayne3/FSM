English | [中文](README_zh.md)

# 🧩 FSM: A Simple C Finite State Machine

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![CMake](https://img.shields.io/badge/CMake-3.12%2B-brightgreen)

FSM is a simple Finite State Machine library developed in C. Its design goal is to provide a clear, easy-to-understand, and easy-to-integrate FSM implementation, allowing you to focus on business logic rather than being bogged down by complex state management details.

## 📋 Features

- **Efficient**: Uses bitmasks for efficient state checking.
- **Easy to Use**: Concise API design, easy to integrate into any C project.
- **Flexible**: Supports guard conditions and action callbacks for state transitions.

## 🛠️ Building the Project

**Clone the source code**:

```sh
git clone https://github.com/tayne3/FSM.git
```

**Build**:

```sh
mkdir build
cd build
cmake ..
make
```

## 🚀 Quick Start

**Define states and events**:

```c
typedef enum {
    STATE_INIT,
    STATE_RUN,
    STATE_STOP,
} state_t;

typedef enum {
    EVENT_START,
    EVENT_STOP,
} event_t;
```

**Define the transition table**:

```c
static void action_start(fsm_t *fsm, void *data) {
    printf("Action: Start.\n");
}

static void action_stop(fsm_t *fsm, void *data) {
    printf("Action: Stop.\n");
}

static const fsm_transition_t transitions[] = {
    {
        .event              = EVENT_START,
        .source_states_mask = FSM_STATES_MASK(STATE_INIT, STATE_STOP),
        .target_state       = STATE_RUN,
        .guard              = NULL,
        .action             = action_start,
    },
    {
        .event              = EVENT_STOP,
        .source_states_mask = FSM_STATE_MASK(STATE_RUN),
        .target_state       = STATE_STOP,
        .guard              = NULL,
        .action             = action_stop,
    },
};
```

**Initialize the state machine**:

```c
fsm_t fsm;
fsm_result_t result = fsm_init(&fsm, STATE_INIT, transitions, sizeof(transitions) / sizeof(fsm_transition_t));
if (result != FSM_RESULT_SUCCESS) {
    printf("FSM init failed: %s\n", fsm_result_string(result));
    return -1;
}
```

**Process events**:

```c
fsm_result_t result = fsm_process_event(&fsm, EVENT_START, NULL);
if (result != FSM_RESULT_SUCCESS) {
    printf("Event processing failed: %s\n", fsm_result_string(result));
}
```

For a complete example, see the [minimal example](example/simple.c). For more examples, go to the [example](example) directory.


## ❓ Frequently Asked Questions

### Q: How many states can the FSM handle?

A: For performance reasons, it supports a maximum of 32 states, which is sufficient for most scenarios.

### Q: How to handle relatively complex state transition logic?
A: You can implement conditional state transitions by specifying guard functions and use `userdata` to pass custom data.

### Q: Is this FSM library thread-safe?
A: The FSM library itself is not thread-safe. If you use it in a multi-threaded environment, you need to handle synchronization mechanisms like mutexes yourself.

### Q: Can the state transition table be dynamically modified at runtime?
A: No, the FSM library accepts a pointer to a static array of transition rules during initialization, which cannot be modified afterward.
