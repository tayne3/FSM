#include <stdio.h>

#include "fsm.h"

typedef enum {
	STATE_INIT,
	STATE_RUN,
	STATE_STOP,
} state_t;

typedef enum {
	EVENT_START,
	EVENT_STOP,
} event_t;

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
		.on_entry           = action_stop,
		.on_exit            = NULL,
	},
};

int main(void) {
	fsm_t        fsm;
	fsm_result_t result = fsm_init(&fsm, STATE_INIT, transitions, sizeof(transitions) / sizeof(fsm_transition_t));
	if (result != FSM_RESULT_SUCCESS) {
		printf("FSM init failed: %s\n", fsm_result_string(result));
		return -1;
	}

	printf("Initial state: %d\n", fsm_current_state(&fsm));
	printf("\nProcessing EVENT_START...\n");
	result = fsm_process_event(&fsm, EVENT_START, NULL);
	if (result != FSM_RESULT_SUCCESS) {
		printf("Event processing failed: %s\n", fsm_result_string(result));
	} else {
		printf("Successfully processed EVENT_START.\n");
	}
	printf("Current state after EVENT_START: %d\n", fsm_current_state(&fsm));

	printf("\nProcessing EVENT_STOP...\n");
	result = fsm_process_event(&fsm, EVENT_STOP, NULL);
	if (result != FSM_RESULT_SUCCESS) {
		printf("Event processing failed: %s\n", fsm_result_string(result));
	} else {
		printf("Successfully processed EVENT_STOP.\n");
	}
	printf("Current state after EVENT_STOP: %d\n", fsm_current_state(&fsm));
	return 0;
}
