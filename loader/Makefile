# Path
MAME_SAVESTATE_PATH = C:\MameNew\sta\phc25
OUTPUT_PATH = .
PRECOMP_PATH = precomp
TOOLS_PATH = ../tools
OBJ_PATH = obj
INC_PATH = inc

# Tools
AS="$(TOOLS_PATH)/vasmz80_mot_win32.exe"
LD="$(TOOLS_PATH)/vlink.exe"
INJECT=dotnet $(TOOLS_PATH)/InjectPhcInSaveState.dll

# Assembler flags
ASFLAGS=-chklabels -nocase -Fvobj -Dvasm=1 -quiet
LDFLAGS=-brawbin1 -Tmain.ld

# Target and intermediate files
TARGET=turbo_loader.phc
SAVESTATE=turbo_loader.sta
STUFFING_SAVESTATE=../stuffing.sta

# Makefile targets definition
OBJ = $(patsubst %.s,$(OBJ_PATH)/%.o,$(wildcard *.s))

all:
	make sta

phc:
	make $(OUTPUT_PATH)/$(TARGET)

sta:
	make $(OUTPUT_PATH)/$(SAVESTATE)

rebuild:
	make clean
	make all

$(OUTPUT_PATH)/$(SAVESTATE): $(OUTPUT_PATH)/$(TARGET) $(STUFFING_SAVESTATE)
	$(INJECT) $(STUFFING_SAVESTATE) $(OUTPUT_PATH)/$(TARGET) $(OUTPUT_PATH)/$(SAVESTATE)
	copy $(OUTPUT_PATH)\$(SAVESTATE) $(MAME_SAVESTATE_PATH)

$(OUTPUT_PATH)/$(TARGET): $(OUTPUT_PATH) $(OBJ_PATH) $(OBJ) main.ld
	$(LD) $(LDFLAGS) -o $(OUTPUT_PATH)/$(TARGET) $(OBJ)

$(OBJ_PATH)/%.o: %.s $(INC) $(PRECOMP_PATH)
	$(AS) $(ASFLAGS) -L $(PRECOMP_PATH)/$<.txt -o $@ $<

# Directories creation
$(OUTPUT_PATH):
	mkdir $(OUTPUT_PATH)

$(OBJ_PATH):
	mkdir $(OBJ_PATH)

$(PRECOMP_PATH):
	mkdir $(PRECOMP_PATH)

clean:
ifneq ($(wildcard $(PRECOMP_PATH)),)
	rmdir /S /Q $(PRECOMP_PATH)
endif
ifneq ($(wildcard $(OBJ_PATH)),)
	rmdir /S /Q $(OBJ_PATH)
endif
ifneq ($(wildcard $(TARGET)),)
	del $(TARGET)
endif
ifneq ($(wildcard $(SAVESTATE)),)
	del $(SAVESTATE)
endif
