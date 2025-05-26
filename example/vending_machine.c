#include <stdio.h>
#include <string.h>

#include "fsm.h"

/**
 * @brief Vending machine states
 */
typedef enum {
	STATE_IDLE,        // Idle state: waiting for coins
	STATE_ACCEPTING,   // Accepting state: coins inserted, waiting for selection or more coins
	STATE_DISPENSING,  // Dispensing state: dispensing item
	STATE_COUNT,       // Total number of states (must be the last one)
} State;

// Array for printing state names
const char* state_names[] = {
	"IDLE",
	"ACCEPTING",
	"DISPENSING",
};

/**
 * @brief Vending machine events
 */
typedef enum {
	EVENT_INSERT_COIN,    // Event: Coin inserted
	EVENT_SELECT_ITEM,    // Event: Item selected
	EVENT_DISPENSE_DONE,  // Event: Dispensing finished (simulated)
	EVENT_CANCEL,         // Event: Transaction cancelled
	EVENT_COUNT,          // Total number of events (must be the last one)
} Event;

// Array for printing event names
const char* event_names[] = {
	"INSERT_COIN",
	"SELECT_ITEM",
	"DISPENSE_DONE",
	"CANCEL",
};

// Item ID definitions
#define ITEM_WATER_ID 0
#define ITEM_SODA_ID  1
#define ITEM_JUICE_ID 2
#define ITEM_COUNT    3

/**
 * @brief Vending machine user data structure
 * @note Stores the current balance, item information, and messages for the vending machine.
 */
typedef struct {
	int current_balance;   // Current balance
	int selected_item_id;  // Currently selected item ID
	struct {
		const char* name;   // Item name
		int         price;  // Item price
		int         count;  // Item stock
	} items[ITEM_COUNT];    // Array of items
	const char* message;    // Message to display to the user
} VendingMachineContext;

static int  can_dispense_guard(struct fsm* fsm, void* data);
static void add_coin_action(struct fsm* fsm, void* data);
static void start_dispense_action(struct fsm* fsm, void* data);
static void return_change_action(struct fsm* fsm, void* data);
static void refund_action(struct fsm* fsm, void* data);
static void process_event_and_display_status(fsm_t* fsm, Event event, void* data);

/**
 * @brief State transition rules for the vending machine
 * @note This is the core of the FSM. It's an array indexed by event.
 * Each event has a rule defining source state mask, target state,
 * optional guard function, and action function.
 */
static const fsm_transition_t transitions[] = {
	{
		.event  = EVENT_INSERT_COIN,
		.guard  = NULL,  // Inserting a coin is always allowed
		.action = add_coin_action,
		.source_states_mask =
			FSM_STATES_MASK(STATE_IDLE, STATE_ACCEPTING),  // Can insert coin in IDLE or ACCEPTING state
		.target_state = STATE_ACCEPTING,                   // Enter ACCEPTING state after inserting coin
	},
	{
		.event              = EVENT_SELECT_ITEM,
		.guard              = can_dispense_guard,  // Must pass guard check (stock/balance)
		.action             = start_dispense_action,
		.source_states_mask = FSM_STATE_MASK(STATE_ACCEPTING),  // Can only select item in ACCEPTING state
		.target_state       = STATE_DISPENSING,                 // Enter DISPENSING state after successful selection
	},
	{
		.event              = EVENT_DISPENSE_DONE,
		.guard              = NULL,
		.action             = return_change_action,
		.source_states_mask = FSM_STATE_MASK(STATE_DISPENSING),  // Can only complete dispensing in DISPENSING state
		.target_state       = STATE_IDLE,                        // Return to IDLE state after completion
	},
	{
		.event              = EVENT_CANCEL,
		.guard              = NULL,
		.action             = refund_action,
		.source_states_mask = FSM_STATE_MASK(STATE_ACCEPTING),  // Can only cancel in ACCEPTING state
		.target_state       = STATE_IDLE,                       // Return to IDLE state after cancellation
	},
};

int main(void) {
	fsm_t fsm;

	VendingMachineContext context = {
		.current_balance  = 0,
		.selected_item_id = -1,
		.items =
			{
				[ITEM_WATER_ID] = {.name = "Water", .price = 10, .count = 5},
				[ITEM_SODA_ID]  = {.name = "Soda", .price = 15, .count = 3},
				[ITEM_JUICE_ID] = {.name = "Juice", .price = 20, .count = 0},  // Sold out
			},
		.message = "Welcome! Please insert coins.",
	};

	// Initialize FSM
	fsm_result_t result = fsm_init(&fsm, STATE_IDLE, transitions, sizeof(transitions) / sizeof(fsm_transition_t));
	if (result != FSM_RESULT_SUCCESS) {
		printf("ERROR: FSM initialization failed: %s\n", fsm_result_string(result));
		return 1;
	}
	fsm_set_userdata(&fsm, &context);

	printf("--- Vending Machine Simulation Start ---\n");
	printf("Initial State: %s, Balance: %d\n", state_names[fsm_current_state(&fsm)], context.current_balance);
	printf("Message: %s\n", context.message);

	// Prepare some coins and item selections
	int coin_10    = 10;
	int coin_5     = 5;
	int item_soda  = ITEM_SODA_ID;
	int item_juice = ITEM_JUICE_ID;
	int item_water = ITEM_WATER_ID;

	// Scenario 1: Attempt to buy a sold-out item
	printf("\n--- Scenario 1: Buy sold-out item (Juice) ---\n");
	process_event_and_display_status(&fsm, EVENT_INSERT_COIN, &coin_10);     // Insert 10
	process_event_and_display_status(&fsm, EVENT_SELECT_ITEM, &item_juice);  // Try to buy Juice (sold out)

	// Scenario 2: Successful purchase
	printf("\n--- Scenario 2: Successful purchase (Soda) ---\n");
	process_event_and_display_status(&fsm, EVENT_INSERT_COIN, &coin_5);     // Insert 5 (balance: 10+5=15)
	process_event_and_display_status(&fsm, EVENT_SELECT_ITEM, &item_soda);  // Buy Soda (price 15)
	process_event_and_display_status(&fsm, EVENT_DISPENSE_DONE, NULL);      // Dispense complete

	// Scenario 3: Invalid event for current state
	printf("\n--- Scenario 3: Invalid event (select item in IDLE state) ---\n");
	process_event_and_display_status(&fsm, EVENT_SELECT_ITEM, &item_water);  // Select item in IDLE (not allowed)

	// Scenario 4: Another successful purchase
	printf("\n--- Scenario 4: Successful purchase (Water) ---\n");
	process_event_and_display_status(&fsm, EVENT_INSERT_COIN, &coin_10);     // Insert 10
	process_event_and_display_status(&fsm, EVENT_SELECT_ITEM, &item_water);  // Buy Water (price 10)
	process_event_and_display_status(&fsm, EVENT_DISPENSE_DONE, NULL);       // Dispense complete

	// Scenario 5: Cancel transaction
	printf("\n--- Scenario 5: Cancel transaction after inserting coin ---\n");
	process_event_and_display_status(&fsm, EVENT_INSERT_COIN, &coin_10);  // Insert 10
	process_event_and_display_status(&fsm, EVENT_CANCEL, NULL);           // Cancel transaction

	printf("\n--- Vending Machine Simulation End ---\n");

	return 0;
}

static int can_dispense_guard(struct fsm* fsm, void* data) {
	VendingMachineContext* context     = (VendingMachineContext*)fsm_userdata(fsm);
	int                    selected_id = *(int*)data;

	context->message = NULL;
	if (selected_id < 0 || selected_id >= ITEM_COUNT) {
		context->message = "Invalid selection.";
		return 1;
	}

	context->selected_item_id = selected_id;
	if (context->items[selected_id].count <= 0) {
		context->message = "Item sold out.";
		return 1;
	}
	if (context->current_balance < context->items[selected_id].price) {
		context->message = "Insufficient balance.";
		return 1;
	}

	return 0;
}

static void add_coin_action(struct fsm* fsm, void* data) {
	VendingMachineContext* context    = (VendingMachineContext*)fsm_userdata(fsm);
	int                    coin_value = *(int*)data;
	context->current_balance += coin_value;
	context->message = "Coin accepted.";  // Changed from "Coin inserted."
	printf("  Action: Inserted %d. Balance: %d\n", coin_value, context->current_balance);
}

static void start_dispense_action(struct fsm* fsm, void* data) {
	VendingMachineContext* context     = (VendingMachineContext*)fsm_userdata(fsm);
	int                    selected_id = context->selected_item_id;

	context->items[selected_id].count--;
	context->current_balance -= context->items[selected_id].price;

	printf("  Action: Dispensing %s. Price: %d, Stock left: %d. Remaining balance: %d\n",
		   context->items[selected_id].name, context->items[selected_id].price, context->items[selected_id].count,
		   context->current_balance);
}

static void return_change_action(struct fsm* fsm, void* data) {
	VendingMachineContext* context = (VendingMachineContext*)fsm_userdata(fsm);
	if (context->current_balance > 0) {
		printf("  Action: Returning change: %d\n", context->current_balance);
		context->current_balance = 0;
	}
	context->message = "Thank you! Please take your item.";
	printf("  Action: Dispense complete. Transaction finished.\n");
}

static void refund_action(struct fsm* fsm, void* data) {
	VendingMachineContext* context = (VendingMachineContext*)fsm_userdata(fsm);
	if (context->current_balance > 0) {
		printf("  Action: Refunding amount: %d\n", context->current_balance);
		context->current_balance = 0;
	}
	context->message = "Transaction cancelled. Coins returned.";
	printf("  Action: Transaction cancelled.\n");
}

static void process_event_and_display_status(fsm_t* fsm, Event event, void* data) {
	VendingMachineContext* context   = (VendingMachineContext*)fsm_userdata(fsm);
	uint8_t                old_state = fsm_current_state(fsm);
	context->message                 = NULL;  // Clear previous message before processing an event

	printf("\n---> EVENT: %s\n", event_names[event]);  // Made it more prominent
	fsm_result_t result    = fsm_process_event(fsm, event, data);
	uint8_t      new_state = fsm_current_state(fsm);

	printf("     Result:  %s (%d)\n", fsm_result_string(result), result);
	printf("     State:   %s -> %s\n", state_names[old_state], state_names[new_state]);
	printf("     Balance: %d\n", context->current_balance);

	// If successful and a message wasn't set by an action/guard, set a default one.
	if (result == FSM_RESULT_SUCCESS && !context->message) {
		if (event == EVENT_SELECT_ITEM) {  // Specifically for successful item selection leading to dispense
			context->message = context->items[context->selected_item_id].name;  // Display item name
		}
	}

	if (context->message) {
		printf("     Message: %s\n", context->message);
	}

	if (result == FSM_RESULT_GUARD_DENIED) {
		// Message is already set by the guard
		printf("     INFO: Transition denied by guard. Reason: %s\n", context->message);
	} else if (result == FSM_RESULT_NO_TRANSITION_FOR_STATE) {
		printf("     WARN: Event [%s] not allowed in state [%s].\n", event_names[event], state_names[old_state]);
		context->message = "Operation not allowed in current state.";  // Set a generic message
		printf("     Message: %s\n", context->message);
	}
}
