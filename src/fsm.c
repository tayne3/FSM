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
#include "fsm.h"

#include <assert.h>

// Macro to check if a state is in a mask
#define FSM_STATE_IN_MASK(state, mask) ((mask & FSM_STATE_MASK(state)) != 0)

fsm_result_t fsm_init(fsm_t* self, uint8_t initial_state, const fsm_transition_t* transition_rules,
					  size_t transition_count) {
	if (!self || !transition_rules || transition_count == 0) {
		return FSM_RESULT_INVALID_PARAMS;
	}
	for (size_t i = 0; i < transition_count; i++) {
		if (transition_rules[i].target_state >= FSM_MAX_STATES) {
			return FSM_RESULT_INVALID_PARAMS;
		}
	}

	self->current_state    = initial_state;
	self->transition_rules = transition_rules;
	self->transition_count = transition_count;
	return FSM_RESULT_SUCCESS;
}

fsm_result_t fsm_process_event(fsm_t* self, uint8_t event, void* data) {
	assert(self);
	assert(self->transition_rules);
	for (size_t i = 0; i < self->transition_count; i++) {
		const fsm_transition_t* rule = &self->transition_rules[i];
		if (rule->event == event && FSM_STATE_IN_MASK(self->current_state, rule->source_states_mask)) {
			if (rule->guard) {
				if (rule->guard(self, data) != 0) {
					return FSM_RESULT_GUARD_DENIED;
				}
			}
			self->current_state = rule->target_state;
			if (rule->action) {
				rule->action(self, data);
			}
			return FSM_RESULT_SUCCESS;
		}
	}
	return FSM_RESULT_NO_TRANSITION_FOR_STATE;
}

uint8_t fsm_current_state(const fsm_t* self) {
	assert(self);
	return self->current_state;
}

void* fsm_userdata(const fsm_t* self) {
	assert(self);
	return self->userdata;
}

void fsm_set_userdata(fsm_t* self, void* userdata) {
	assert(self);
	self->userdata = userdata;
}

const char* fsm_result_string(fsm_result_t result) {
#define F(code, name, describe) \
	case FSM_RESULT_##name: return describe;
	switch (result) {
		FSM_RESULT_FOREACH(F)
		default: return "Unknown";
	}
#undef F
}
