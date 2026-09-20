# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

SIM ?= icarus
FST ?= -fst
TOPLEVEL_LANG ?= verilog

SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v

ifneq ($(GATES),yes)

# ------------------------------------------------------------
# RTL simulation
# ------------------------------------------------------------

SIM_BUILD = sim_build/rtl

VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

# ------------------------------------------------------------
# Gate-level simulation
# ------------------------------------------------------------

SIM_BUILD = sim_build/gl

COMPILE_ARGS += -DGL_TEST
COMPILE_ARGS += -DFUNCTIONAL
COMPILE_ARGS += -DSIM

# IHP SG13G2 standard-cell library
IHP_STDCELL = $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

# Simulation copy of the standard-cell library.
# The original zero-delay sg13g2_dlygate4sd2_1 definition
# is removed from this copy and replaced by our delayed model.
IHP_STDCELL_SIM = $(SIM_BUILD)/sg13g2_stdcell_sim.v

# Create the modified standard-cell library before compilation.
$(shell mkdir -p "$(SIM_BUILD)" && \
        sed '/module sg13g2_dlygate4sd2_1/,/endmodule/d' \
        "$(IHP_STDCELL)" > "$(IHP_STDCELL_SIM)")

# IHP IO library
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v

# Modified IHP standard-cell library
VERILOG_SOURCES += $(IHP_STDCELL_SIM)

# Simulation-only replacement for sg13g2_dlygate4sd2_1
VERILOG_SOURCES += $(PWD)/ihp_delay_cells.v

# Gate-level netlist copied in by the Tiny Tapeout GDS action
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# ------------------------------------------------------------
# Common testbench settings
# ------------------------------------------------------------

COMPILE_ARGS += -I$(SRC_DIR)

VERILOG_SOURCES += $(PWD)/tb.v

TOPLEVEL = tb
COCOTB_TEST_MODULES = test

include $(shell cocotb-config --makefiles)/Makefile.sim
