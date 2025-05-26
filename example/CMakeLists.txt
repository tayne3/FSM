add_executable(simple simple.c)
target_link_libraries(simple fsm::fsm)

add_executable(vending_machine vending_machine.c)
target_link_libraries(vending_machine fsm::fsm)

add_executable(traffic_light traffic_light.c)
target_link_libraries(traffic_light fsm::fsm)
