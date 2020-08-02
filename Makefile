TARGET = gd32vf103
DEBUG = 1
OPT = -O2
BUILD_DIR = build

FIRMWARE_DIR := sdk
SYSTEM_CLOCK := 8000000U

C_SOURCES =  \
$(wildcard $(FIRMWARE_DIR)/GD32VF103_standard_peripheral/Source/*.c) \
$(wildcard $(FIRMWARE_DIR)/GD32VF103_standard_peripheral/*.c) \
$(wildcard $(FIRMWARE_DIR)/RISCV/stubs/*.c) \
$(wildcard $(FIRMWARE_DIR)/RISCV/drivers/*.c) \
$(wildcard $(FIRMWARE_DIR)/RISCV/env_Eclipse/*.c) \
$(wildcard board/*.c) \
$(wildcard ./*.c) 

ASM_SOURCES =  \
$(FIRMWARE_DIR)/RISCV/env_Eclipse/start.s \
$(FIRMWARE_DIR)/RISCV/env_Eclipse/entry.s

PERIFLIB_SOURCES = \
# $(wildcard lib/*.a)

PREFIX = riscv64-unknown-elf-
CC = $(PREFIX)gcc
AS = $(PREFIX)gcc -x assembler-with-cpp
CP = $(PREFIX)objcopy
AR = $(PREFIX)ar
SZ = $(PREFIX)size
OD = $(PREFIX)objdump
HEX = $(CP) -O ihex
BIN = $(CP) -O binary -S

ARCH = -march=rv32imac -mabi=ilp32 -mcmodel=medlow

AS_DEFS = 

C_DEFS =  \
-DUSE_STDPERIPH_DRIVER \
-DHXTAL_VALUE=$(SYSTEM_CLOCK) \

AS_INCLUDES = 

C_INCLUDES =  \
-I. \
-I$(FIRMWARE_DIR)/GD32VF103_standard_peripheral/Include \
-I$(FIRMWARE_DIR)/GD32VF103_standard_peripheral \
-I$(FIRMWARE_DIR)/RISCV/drivers 

ASFLAGS := $(CFLAGS) $(ARCH) $(AS_DEFS) $(AS_INCLUDES) $(OPT) -Wl,-Bstatic#, -ffreestanding -nostdlib

CFLAGS := $(CFLAGS) $(ARCH) $(C_DEFS) $(C_INCLUDES) $(OPT) -Wl,-Bstatic  -ffunction-sections -fdata-sections # -ffreestanding -nostdlib

ifeq ($(DEBUG), 1)
CFLAGS += -g -gdwarf-2
endif

CFLAGS += -std=gnu11 -MMD -MP #.deps/$(notdir $(<:.c=.d)) -MF$(@:%.o=%.d) -MT$(@:%.o=%.d)

LDSCRIPT = $(FIRMWARE_DIR)/RISCV/env_Eclipse/GD32VF103x8.lds

LIBDIR = 
LDFLAGS = $(OPT) $(ARCH) -T$(LDSCRIPT) $(LIBDIR) $(LIBS) $(PERIFLIB_SOURCES) -Wl,--cref -Wl,--no-relax -Wl,--gc-sections -Wl,-M=$(BUILD_DIR)/$(TARGET).map -nostartfiles #-ffreestanding -nostdlib

all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin


OBJECTS = $(addprefix $(BUILD_DIR)/,$(notdir $(ASM_SOURCES:.s=.o)))
vpath %.s $(sort $(dir $(ASM_SOURCES)))
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(C_SOURCES:.c=.o)))
vpath %.c $(sort $(dir $(C_SOURCES)))


$(BUILD_DIR)/%.o: %.c Makefile | $(BUILD_DIR) .deps
	@echo "CC $<"
	@$(CC) -c $(CFLAGS) -MMD -MP \
		-MF .deps/$(notdir $(<:.c=.d)) \
		-Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) $< -o $@

$(BUILD_DIR)/%.o: %.s Makefile | $(BUILD_DIR) .deps
	@echo "AS $<"
	@$(AS) -c $(CFLAGS) -MMD -MP  \
		-MF .deps/$(notdir $(<:.s=.d)) $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) Makefile
	@echo "LD $@"
	@$(CC) $(OBJECTS) $(LDFLAGS) -o $@
	@echo "OD $@"
	@$(OD) $(BUILD_DIR)/$(TARGET).elf -xS > $(BUILD_DIR)/$(TARGET).s $@
	@echo "SIZE $@"
	@$(SZ) $@

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@echo "OBJCOPY $@"
	@$(HEX) $< $@
	
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@echo "OBJCOPY $@"
	@$(BIN) $< $@	
	
$(BUILD_DIR):
	mkdir $@

.deps:
	mkdir $@

clean:
	-rm -fR .deps $(BUILD_DIR)
flash: all
	-./openocd -f ./openocd_gdlink.cfg -c init -c " flash protect 0 0 last off; \
			program {$(BUILD_DIR)/$(TARGET).elf} verify; mww 0xe004200c 0x4b5a6978; mww 0xe0042008 0x01; resume; exit 0;"

dfu: all
	dfu-util -d 28e9:0189 -a 0 --dfuse-address 0x08000000:leave -D $(BUILD_DIR)/$(TARGET).bin

uart: all
	stm32flash -w $(BUILD_DIR)/$(TARGET).bin /dev/ttyUSB0

-include $(shell mkdir .deps 2>/dev/null) $(wildcard .deps/*)
