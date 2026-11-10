# Place-and-route constraints: OpenLane's base SDC with a tighter fanout target.
#
# Signoff STA uses the base SDC unchanged (max fanout 10). Global routing adds
# antenna diodes after the resizer has run, and every diode counts as a load,
# so the resizer aims for 6 here to leave room for them.
source $::env(BASE_SDC_FILE)
set_max_fanout 6 [current_design]
