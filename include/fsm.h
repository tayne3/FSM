/*
 * MIT License
 *
 * Copyright (c) 2025 tayne3
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 *    all copies or substantial portions of the Software.
 *
 * 2. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *    SOFTWARE.
 */
#ifndef FSM_H
#define FSM_H
#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

// F(code, name, description)
#define FSM_RESULT_FOREACH(F)                                                                                    \
	F(0x00, SUCCESS, "Success")                                 /* Event processed, state transitioned. */       \
	F(0x01, GUARD_DENIED, "Guard denied")                       /* Guard function prevented transition. */       \
	F(0x02, NO_TRANSITION_FOR_STATE, "No transition for state") /* Current status and events are not defined. */ \
	F(0x03, EVENT_OUT_OF_BOUNDS, "Event out of bounds")         /* Event ID is out of valid range. */            \
	F(0x04, STATE_OUT_OF_BOUNDS, "State out of bounds") /* Internal FSM state is invalid (should not happen). */ \
	F(0x05, INVALID_PARAMS, "Invalid parameters")       /* Invalid parameters provided to an FSM function. */

/**
 * @brief Result codes for FSM operations.
 */
typedef enum {
#define F(code, name, description) FSM_RESULT_##name = code,
	FSM_RESULT_FOREACH(F)
#undef F
} fsm_result_t;

struct fsm;

// Maximum number of states supported by the FSM.
#define FSM_MAX_STATES 32

/**
 * @brief Action function executed during a state transition.
 * @param fsm Pointer to the current FSM instance.
 * @param data Optional data associated with the event.
 */
typedef void (*fsm_action_t)(struct fsm* fsm, void* data);

/**
 * @brief Guard function to determine if a state transition should occur.
 * @param fsm Pointer to the current FSM instance.
 * @param data Optional data associated with the event.
 * @return 0 if the transition is allowed, non-zero otherwise.
 */
typedef int (*fsm_guard_t)(struct fsm* fsm, void* data);

/**
 * @brief Defines a single transition rule in the FSM.
 * @note Specifies target state, guard, and action for an event from source states.
 */
typedef struct fsm_transition {
	fsm_guard_t  guard;               ///< Optional guard function (NULL if none).
	fsm_action_t action;              ///< Optional action function (NULL if none).
	uint32_t     source_states_mask;  ///< Bitmask of source states.
	uint8_t      target_state;        ///< Target state enum value.
	uint8_t      event;               ///< The event that triggers this transition.
} fsm_transition_t;

/**
 * @brief FSM instance.
 * @note Holds the current state, transition table, and user-defined data.
 */
typedef struct fsm {
	void*                   userdata;          ///< Pointer to user-defined data.
	const fsm_transition_t* transition_rules;  ///< Pointer to the FSM transition rules list.
	size_t                  transition_count;  ///< Number of rules in the transition_rules list.
	uint8_t                 current_state;     ///< Current state of the FSM.
} fsm_t;

/**
 * @brief Converts a state enum value to its corresponding bit in a mask.
 * @param state State enum value (0 to FSM_MAX_STATES - 1).
 * @return Bit representing the state (e.g., state 0 -> 1, state 1 -> 2).
 */
#define FSM_STATE_MASK(state) (1UL << (state))

/**
 * @brief Converts a list of state enum values to a mask.
 * @param ... State enum values.
 * @return Bitmask representing the states.
 */
#define FSM_STATES_MASK(...) __FSM_STATE_MASK_HELPER(__VA_ARGS__, 0, 0, 0, 0, 0, 0, 0)
#define __FSM_STATE_MASK_HELPER(s1, s2, s3, s4, s5, s6, s7, s8, ...)                                       \
	(FSM_STATE_MASK(s1) | ((s2) ? FSM_STATE_MASK(s2) : 0) | ((s3) ? FSM_STATE_MASK(s3) : 0) |              \
	 ((s4) ? FSM_STATE_MASK(s4) : 0) | ((s5) ? FSM_STATE_MASK(s5) : 0) | ((s6) ? FSM_STATE_MASK(s6) : 0) | \
	 ((s7) ? FSM_STATE_MASK(s7) : 0) | ((s8) ? FSM_STATE_MASK(s8) : 0))

/**
 * @brief Initializes an FSM instance.
 *
 * @param self Pointer to the FSM instance to initialize.
 * @param initial_state The starting state for the FSM.
 * @param transition_rules Pointer to the array of transition rules.
 * @param num_transition_rules Number of rules in the transition_rules array.
 * @return FSM_RESULT_SUCCESS on success, FSM_RESULT_INVALID_PARAMS on invalid parameters.
 */
fsm_result_t fsm_init(fsm_t* self, uint8_t initial_state, const fsm_transition_t* transition_rules,
					  size_t num_transition_rules);

/**
 * @brief Processes an event for the FSM.
 *
 * @param self Pointer to the FSM instance.
 * @param event The event ID to process.
 * @param data Optional data associated with the event, passed to guard and action functions.
 * @return fsm_result_t indicating the result of event processing.
 */
fsm_result_t fsm_process_event(fsm_t* self, uint8_t event, void* data);

/**
 * @brief Gets the current state of the FSM.
 *
 * @param self Pointer to the FSM instance.
 * @return The current state enum value.
 */
uint8_t fsm_current_state(const fsm_t* self);

/**
 * @brief Gets the user-defined data from the FSM.
 * @param self Pointer to the FSM instance.
 * @return Pointer to the user-defined data.
 */
void* fsm_userdata(const fsm_t* self);

/**
 * @brief Sets the user-defined data for the FSM.
 * @param self Pointer to the FSM instance.
 * @param userdata Pointer to the user-defined data.
 */
void fsm_set_userdata(fsm_t* self, void* userdata);

/**
 * @brief Converts an FSM result code to a human-readable string.
 * @param result The FSM result code.
 * @return String representation of the result code.
 */
const char* fsm_result_string(fsm_result_t result);

#ifdef __cplusplus
}
#endif
#endif  // FSM_H
