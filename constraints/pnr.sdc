# Place-and-route constraints: LibreLane's base SDC with two changes.
#
# Signoff STA uses the base SDC unchanged (constraints/signoff.sdc).
# - Max fanout 9 instead of 10: antenna repair after detailed routing can add
#   a diode to a net, and a diode counts as a load.
# - Max transition 0.70 ns instead of 0.75 ns: the resizer estimates wires with
#   nominal RC, which under-predicts slew at the ss/100C/1.60V max-RC corner.
source $::env(SCRIPTS_DIR)/base.sdc
set_max_fanout 9 [current_design]
set_max_transition 0.70 [current_design]
