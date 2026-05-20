TOOLCHAIN_PREFIX ?= riscv-none-elf
RISCV_CC         ?= $(TOOLCHAIN_PREFIX)-gcc
RISCV_OBJCOPY    ?= $(TOOLCHAIN_PREFIX)-objcopy
PYTHON           ?= python

ARCH             ?= rv32i
ABI              ?= ilp32
LINKER_FLASH     ?= linker/rv32i_flash.ld
LINKER_ROM0      ?= linker/rv32i_rom0.ld
BUILD_DIR        ?= build
BIN_DIR          ?= bin

FLASH_PROGRAMS   := ahb_matrix_soc ahb_matrix_apb_soc
ROM0_PROGRAMS    := cached_system_smoke cached_ahb_master
PROGRAMS         := $(FLASH_PROGRAMS) $(ROM0_PROGRAMS)

COMMON_FLAGS     := -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding
LDFLAGS          = -Wl,-T,$(LINKER_SCRIPT) -Wl,--build-id=none

.PHONY: all clean
.SECONDARY: $(PROGRAMS:%=$(BUILD_DIR)/%.elf) $(PROGRAMS:%=$(BIN_DIR)/%.bin)

all: $(PROGRAMS:%=$(BIN_DIR)/%.memh)

$(BUILD_DIR) $(BIN_DIR):
	mkdir $@

$(FLASH_PROGRAMS:%=$(BUILD_DIR)/%.elf): LINKER_SCRIPT = $(LINKER_FLASH)
$(ROM0_PROGRAMS:%=$(BUILD_DIR)/%.elf): LINKER_SCRIPT = $(LINKER_ROM0)
$(FLASH_PROGRAMS:%=$(BUILD_DIR)/%.elf): $(LINKER_FLASH)
$(ROM0_PROGRAMS:%=$(BUILD_DIR)/%.elf): $(LINKER_ROM0)

$(BUILD_DIR)/%.elf: asm/%.S | $(BUILD_DIR) $(BIN_DIR)
	$(RISCV_CC) $(COMMON_FLAGS) $(LDFLAGS) -Wl,-Map,$(BIN_DIR)/$*.map -o $@ $<

$(BIN_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BIN_DIR)
	$(RISCV_OBJCOPY) -O binary $< $@

$(BIN_DIR)/%.memh: $(BIN_DIR)/%.bin scripts/bin_to_memh.py | $(BIN_DIR)
	$(PYTHON) scripts/bin_to_memh.py $< $@

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)/*.bin $(BIN_DIR)/*.elf $(BIN_DIR)/*.map
