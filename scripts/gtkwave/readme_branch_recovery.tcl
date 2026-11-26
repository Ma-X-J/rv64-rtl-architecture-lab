# Curated GTKWave view for the README branch-recovery demonstration.
set top "BranchRecoveryWaveformDemo"

set clock_signals [list \
    "$top.CLK" \
    "$top.RESET" \
]
gtkwave::addSignalsFromList $clock_signals
gtkwave::highlightSignalsFromList $clock_signals
gtkwave::/Edit/Color_Format/Yellow
gtkwave::unhighlightSignalsFromList $clock_signals

set pipeline_pc [list \
    "$top.IF_PC\[15:0\]" \
    "$top.ID_PC\[15:0\]" \
    "$top.EX_PC\[15:0\]" \
    "$top.MEM_PC\[15:0\]" \
]
gtkwave::addSignalsFromList $pipeline_pc
gtkwave::highlightSignalsFromList $pipeline_pc
gtkwave::/Edit/Data_Format/Hex
gtkwave::/Edit/Color_Format/Blue
gtkwave::unhighlightSignalsFromList $pipeline_pc

set pipeline_valid [list \
    "$top.IF_VALID" \
    "$top.ID_VALID" \
    "$top.EX_VALID" \
    "$top.MEM_VALID" \
]
gtkwave::addSignalsFromList $pipeline_valid
gtkwave::highlightSignalsFromList $pipeline_valid
gtkwave::/Edit/Color_Format/Green
gtkwave::unhighlightSignalsFromList $pipeline_valid

set prediction_signals [list \
    "$top.GHR\[1:0\]" \
    "$top.PREDICTED_TAKEN_IF" \
]
gtkwave::addSignalsFromList $prediction_signals
gtkwave::highlightSignalsFromList $prediction_signals
gtkwave::/Edit/Color_Format/Orange
gtkwave::unhighlightSignalsFromList $prediction_signals

set recovery_signals [list \
    "$top.BRANCH_RESOLVE_MEM" \
    "$top.PREDICTED_TAKEN_MEM" \
    "$top.ACTUAL_TAKEN_MEM" \
    "$top.MISPREDICT_MEM" \
    "$top.FLUSH_PIPELINE" \
    "$top.REDIRECT_PC\[15:0\]" \
]
set added [gtkwave::addSignalsFromList $recovery_signals]
puts "README waveform: recovery signals added $added"
gtkwave::highlightSignalsFromList $recovery_signals
gtkwave::/Edit/Color_Format/Red
gtkwave::unhighlightSignalsFromList $recovery_signals
gtkwave::setLeftJustifySigs on

# Values are in ps because the testbench uses a 1 ns / 1 ps timescale.
# This range starts shortly before the branch reaches MEM and includes the
# redirect plus the refill of the correct path.
gtkwave::nop
gtkwave::setZoomRangeTimes 205000 335000
gtkwave::setWindowStartTime 205000
gtkwave::setMarker 255000
gtkwave::setNamedMarker A 255000 "mispredict + redirect"
gtkwave::presentWindow
gtkwave::nop
