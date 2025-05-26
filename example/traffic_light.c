#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fsm.h"

// Traffic light states
typedef enum {
	STATE_RED,        // Red light
	STATE_GREEN,      // Green light
	STATE_YELLOW,     // Yellow light
	STATE_EMERGENCY,  // Emergency mode (flashing)
	STATE_COUNT       // Number of states
} light_state_t;

// Traffic light events
typedef enum {
	EVENT_TIMEOUT,    // Timer expired
	EVENT_EMERGENCY,  // Emergency event
	EVENT_RESET,      // Reset event
	EVENT_COUNT       // Number of events
} light_event_t;

// Traffic light context data
typedef struct {
	int green_duration;   // Green light duration (seconds)
	int yellow_duration;  // Yellow light duration (seconds)
	int red_duration;     // Red light duration (seconds)
	int current_timer;    // Current timer value
	int emergency_count;  // Emergency mode count
} light_context_t;

// Action function: Red light
void action_red(fsm_t *fsm, void *data) {
	light_context_t *ctx = (light_context_t *)fsm_userdata(fsm);
	ctx->current_timer   = ctx->red_duration;
	printf("+ Red light on, please wait %d seconds.\n", ctx->current_timer);
}

// Action function: Green light
void action_green(fsm_t *fsm, void *data) {
	light_context_t *ctx = (light_context_t *)fsm_userdata(fsm);
	ctx->current_timer   = ctx->green_duration;
	printf("+ Green light on, you may proceed for %d seconds.\n", ctx->current_timer);
}

// Action function: Yellow light
void action_yellow(fsm_t *fsm, void *data) {
	light_context_t *ctx = (light_context_t *)fsm_userdata(fsm);
	ctx->current_timer   = ctx->yellow_duration;
	printf("+ Yellow light on, please slow down for %d seconds.\n", ctx->current_timer);
}

// Action function: Emergency mode
void action_emergency(fsm_t *fsm, void *data) {
	light_context_t *ctx = (light_context_t *)fsm_userdata(fsm);
	ctx->emergency_count++;
	printf("! Entering emergency mode, this is the %dth emergency.\n", ctx->emergency_count);
}

// Action function: Reset
void action_reset(fsm_t *fsm, void *data) {
	printf("- Traffic light reset to default state.\n");
}

// Guard function: Check if emergency mode is allowed
int guard_emergency(fsm_t *fsm, void *data) {
	light_context_t *ctx = (light_context_t *)fsm_userdata(fsm);

	// If emergency mode has been entered more than 3 times, deny
	if (ctx->emergency_count >= 3) {
		printf("x Emergency mode limit reached, denying emergency mode.\n");
		return 1;  // Return non-zero to deny transition
	}
	return 0;  // Return 0 to allow transition
}

int main(void) {
	// Initialize context data
	light_context_t light_ctx = {
		.green_duration  = 30,
		.yellow_duration = 5,
		.red_duration    = 20,
		.current_timer   = 0,
		.emergency_count = 0,
	};
	// Define state transition table
	static const fsm_transition_t transitions[] = {
		{
			.event              = EVENT_TIMEOUT,
			.source_states_mask = FSM_STATES_MASK(STATE_RED),
			.target_state       = STATE_GREEN,
			.guard              = NULL,
			.action             = action_green,
		},
		{
			.event              = EVENT_TIMEOUT,
			.source_states_mask = FSM_STATES_MASK(STATE_GREEN),
			.target_state       = STATE_YELLOW,
			.guard              = NULL,
			.action             = action_yellow,
		},
		{
			.event              = EVENT_TIMEOUT,
			.source_states_mask = FSM_STATES_MASK(STATE_YELLOW),
			.target_state       = STATE_RED,
			.guard              = NULL,
			.action             = action_red,
		},
		{
			.event              = EVENT_EMERGENCY,
			.source_states_mask = FSM_STATES_MASK(STATE_RED, STATE_GREEN, STATE_YELLOW),
			.target_state       = STATE_EMERGENCY,
			.guard              = guard_emergency,
			.action             = action_emergency,
		},
		{
			.event              = EVENT_RESET,
			.source_states_mask = FSM_STATES_MASK(STATE_EMERGENCY),
			.target_state       = STATE_RED,
			.guard              = NULL,
			.action             = action_reset,
		},
	};

	fsm_t        fsm;
	fsm_result_t result;
	result = fsm_init(&fsm, STATE_RED, transitions, sizeof(transitions) / sizeof(fsm_transition_t));
	if (result != FSM_RESULT_SUCCESS) {
		printf("FSM initialization failed: %s\n", fsm_result_string(result));
		return -1;
	}
	fsm_set_userdata(&fsm, &light_ctx);

	char cmd[20];
	printf("-- Traffic Light Control --\n");
	printf("Available commands:\n");
	printf("  timeout  - Trigger timer timeout\n");
	printf("  emergency - Trigger emergency mode\n");
	printf("  reset    - Reset traffic light\n");
	printf("  help     - Show this help\n");
	printf("  exit     - Exit program\n");

	while (1) {
		printf("\n");
		printf("Current state: ");
		switch (fsm_current_state(&fsm)) {
			case STATE_RED: printf("+ Red light\n"); break;
			case STATE_GREEN: printf("+ Green light\n"); break;
			case STATE_YELLOW: printf("+ Yellow light\n"); break;
			case STATE_EMERGENCY: printf("! Emergency mode\n"); break;
		}
		printf("Enter command> ");
		if (scanf("%19s", cmd) != 1) {
			break;
		}

		if (strcmp(cmd, "timeout") == 0) {
			result = fsm_process_event(&fsm, EVENT_TIMEOUT, NULL);
		} else if (strcmp(cmd, "reset") == 0) {
			result = fsm_process_event(&fsm, EVENT_RESET, NULL);
		} else if (strcmp(cmd, "emergency") == 0) {
			result = fsm_process_event(&fsm, EVENT_EMERGENCY, NULL);
		} else if (strcmp(cmd, "help") == 0) {
			printf("Available commands:\n");
			printf("  timeout  - Trigger timer timeout\n");
			printf("  emergency - Trigger emergency mode\n");
			printf("  reset    - Reset traffic light\n");
			printf("  help     - Show this help\n");
			printf("  exit     - Exit program\n");
		} else if (strcmp(cmd, "exit") == 0) {
			break;
		} else {
			printf("Unknown command: %s\n", cmd);
			continue;
		}

		if (result != FSM_RESULT_SUCCESS) {
			printf("Event processing failed: %s\n", fsm_result_string(result));
		}
	}

	printf("Program exited.\n");
	return 0;
}
