TOOLCHAIN_PREFIX ?= riscv-none-elf
RISCV_CC         ?= $(TOOLCHAIN_PREFIX)-gcc
RISCV_OBJCOPY    ?= $(TOOLCHAIN_PREFIX)-objcopy
PYTHON           ?= python

ARCH             ?= rv32i
ABI              ?= ilp32
LINKER           ?= linker/rv32i_flash.ld
BUILD_DIR        ?= build
BIN_DIR          ?= bin

PROGRAMS         := ahb_matrix_soc

COMMON_FLAGS     := -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding
LDFLAGS          := -Wl,-T,$(LINKER) -Wl,--build-id=none

.PHONY: all clean
.SECONDARY: $(PROGRAMS:%=$(BUILD_DIR)/%.elf) $(PROGRAMS:%=$(BIN_DIR)/%.bin)

all: $(PROGRAMS:%=$(BIN_DIR)/%.memh)

$(BUILD_DIR) $(BIN_DIR):
	mkdir $@

$(BUILD_DIR)/%.elf: asm/%.S $(LINKER) | $(BUILD_DIR) $(BIN_DIR)
	$(RISCV_CC) $(COMMON_FLAGS) $(LDFLAGS) -Wl,-Map,$(BIN_DIR)/$*.map -o $@ $<

$(BIN_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BIN_DIR)
	$(RISCV_OBJCOPY) -O binary $< $@

$(BIN_DIR)/%.memh: $(BIN_DIR)/%.bin scripts/bin_to_memh.py | $(BIN_DIR)
	$(PYTHON) scripts/bin_to_memh.py $< $@

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)/*.bin $(BIN_DIR)/*.elf $(BIN_DIR)/*.map
