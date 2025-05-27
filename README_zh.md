[English](README.md) | 中文

# 🧩 FSM: A Simple C Finite State Machine

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![CMake](https://img.shields.io/badge/CMake-3.12%2B-brightgreen)

FSM 是一个用C语言开发的简易有限状态机 (Finite State Machine) 库，其设计目标是提供一个清晰、易于理解且易于集成的FSM实现，让你能够专注于业务逻辑，而不是被复杂的状态管理细节所困扰。

## 📋 主要特性

- **高效**: 使用位掩码实现高效的状态检查
- **易用**: 简洁的API设计，便于集成到任何C项目中
- **灵活**: 支持状态转换的守卫条件和动作回调

## 🛠️ 项目构建

**源码拉取**:

```sh
git clone https://github.com/tayne3/FSM.git
```

**构建**:

```sh
mkdir build
cd build
cmake ..
make
```

## 🚀 快速上手

**定义状态和事件**:

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

**定义转移表**:

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
        .on_entry           = action_start,
        .on_exit            = NULL,
    },
    {
        .event              = EVENT_STOP,
        .source_states_mask = FSM_STATE_MASK(STATE_RUN),
        .target_state       = STATE_STOP,
        .guard              = NULL,
        .on_entry           = NULL,
        .on_exit            = action_stop,
    },
};
```

**初始化状态机**:

```c
fsm_t fsm;
fsm_result_t result = fsm_init(&fsm, STATE_INIT, transitions, sizeof(transitions) / sizeof(fsm_transition_t));
if (result != FSM_RESULT_SUCCESS) {
    printf("FSM init failed: %s\n", fsm_result_string(result));
    return -1;
}
```

**事件处理**:

```c
fsm_result_t result = fsm_process_event(&fsm, EVENT_START, NULL);
if (result != FSM_RESULT_SUCCESS) {
    printf("Event processing failed: %s\n", fsm_result_string(result));
}
```

完整示例参见[最小示例](example/simple.c), 更多示例前往 [example](example) 目录。


## ❓ 常见问题

### Q: 状态机可以处理多少个状态？
A: 出于性能考虑，最多支持32个状态，对于绝大多数场景已经足够。

### Q: 如何处理相对复杂的状态转换逻辑？
A: 你可以通过指定守卫函数来实现条件性的状态转换，使用 `userdata` 来传递自定义数据。

### Q: 这个FSM库是线程安全的吗？
A: FSM库本身不是线程安全的，在多线程环境中你需要自行处理互斥锁（mutex）等同步机制。

### Q: 状态转换表可以在运行时动态修改吗？
A: 不支持，FSM库在初始化时指定一个指向静态转换规则数组的指针，后续不能修改。
