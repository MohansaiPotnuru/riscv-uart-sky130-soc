# Place-and-route constraints: LibreLane's base SDC with one change.
#
# Signoff STA uses the base SDC unchanged (max fanout 10). Antenna repair after
# detailed routing can add a diode to a net, and a diode counts as a load, so
# the resizer aims for 9 here to leave room for it.
source $::env(SCRIPTS_DIR)/base.sdc
set_max_fanout 9 [current_design]
