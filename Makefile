# Debug
DEBUG = 1
JOYSTICK = 0

# Path
MAME_SAVESTATE_PATH = C:\MameNew\sta\phc25
TO_COMPRESS_PATH = res_to_compress
TO_EXTRACT_AND_COMPRESS_PATH = bmp_to_extract_and_compress
TO_EXTRACT_AND_COMPRESS_GS_PATH = grayscale_bmp_to_extract_and_compress
TO_EXTRACT_AND_COMPRESS_COLOR_PATH = color_bmp_to_extract_and_compress
BMP_TO_EXTRACT_PATH = bmp_to_extract
RESOURCES_RAW = res_raw
CIRCUITS_PATH = circuits
OUTPUT_PATH = .
PRECOMP_PATH = precomp
COMPRESSION_PATH = rlh
TOOLS_PATH = tools
OBJ_PATH = obj
INC_PATH = inc
COMPRESSION_STRATEGY_CACHE_FILE = _rlh_decomp.strat

# Tools
AS="$(TOOLS_PATH)/vasmz80_mot_win32.exe"
LD="$(TOOLS_PATH)/vlink.exe"
INJECT=dotnet $(TOOLS_PATH)/InjectPhcInSaveState.dll
HUFF80=dotnet $(TOOLS_PATH)/HuffmanZ80.dll
APPLY_PHC_MASK=dotnet $(TOOLS_PATH)/ApplyPhcFileBitMask.dll
EXTRACT_RAW_IMAGE_DATA=dotnet $(TOOLS_PATH)/ExtractRawImageData.dll
EXTRACT_COLOR_IMAGE_DATA=dotnet $(TOOLS_PATH)/Extract2BitColorImage.dll
EXTRACT_GS_IMAGE_DATA=dotnet $(TOOLS_PATH)/Extract2BitGrayScaleImage.dll

# Assembler flags
ASFLAGS=-chklabels -nocase -Fvobj -Dvasm=1 -quiet
LDFLAGS=-brawbin1 -Tmain.ld

# Target and intermediate files
TARGET=turbo.phc
SAVESTATE=turbo.sta
STUFFING_SAVESTATE=stuffing.sta
SECTION_MAP_FILE=sectionmap.txt
RLH_COMPRESSOR_SOURCE_FILE=_rlh_decomp.s
COMPRESSED_FILES_INCLUDER=_compressedfiles.s

# Makefile targets definition
OBJ = $(patsubst %.s,$(OBJ_PATH)/%.o,$(wildcard *.s))
INC = $(wildcard $(INC_PATH)/*.inc)

# Compressed files management
TO_COMPRESS_ALL = $(wildcard $(TO_COMPRESS_PATH)/*)
TO_COMPRESS_BMP = $(wildcard $(TO_COMPRESS_PATH)/*.png)
TO_COMPRESS_OTHER = $(filter-out %.png,$(TO_COMPRESS_ALL))
GENERATED_RESOURCE_CODE_FILE = $(COMPRESSED_FILES_INCLUDER)
TO_EXTRACT_BMP = $(wildcard $(BMP_TO_EXTRACT_PATH)/*.png)
EXTRACTED_BMP = $(patsubst $(BMP_TO_EXTRACT_PATH)/%.png,$(RESOURCES_RAW)/%.raw,$(TO_EXTRACT_BMP))
TO_EXTRACT_AND_COMPRESS_BMP = $(wildcard $(TO_EXTRACT_AND_COMPRESS_PATH)/*.png)
EXTRACTED_TO_COMPRESS = $(patsubst $(TO_EXTRACT_AND_COMPRESS_PATH)/%.png,$(TO_COMPRESS_PATH)/%.raw,$(TO_EXTRACT_AND_COMPRESS_BMP))
GS_IMAGES_BMP = $(wildcard $(TO_EXTRACT_AND_COMPRESS_GS_PATH)/*.png)
GS_IMAGES_RAW = $(patsubst $(TO_EXTRACT_AND_COMPRESS_GS_PATH)/%.png,$(TO_COMPRESS_PATH)/%.raw,$(GS_IMAGES_BMP))
COLOR_IMAGES_BMP = $(wildcard $(TO_EXTRACT_AND_COMPRESS_COLOR_PATH)/*.png)
COLOR_IMAGES_RAW = $(patsubst $(TO_EXTRACT_AND_COMPRESS_COLOR_PATH)/%.png,$(TO_COMPRESS_PATH)/%.raw,$(COLOR_IMAGES_BMP))
CIRCUITS_DATA = $(wildcard $(CIRCUITS_PATH)/*)
CIRCUITS_BIN = $(patsubst $(CIRCUITS_PATH)/%.data,$(TO_COMPRESS_PATH)/%.bin,$(CIRCUITS_DATA))


define RESOURCE_FILE_TEMPLATE
echo 	global rlh_$(basename $(FILE)) >> $(GENERATED_RESOURCE_CODE_FILE) &
echo rlh_$(basename $(FILE)): >> $(GENERATED_RESOURCE_CODE_FILE) &
echo 	incbin "$(COMPRESSION_PATH)/$(basename $(FILE)).rlh" >> $(GENERATED_RESOURCE_CODE_FILE) &
endef

define COLOR_IMAGES_RAW_EXTRACTION_TEMPLATE
$(TO_COMPRESS_PATH)/$(1).raw: $(TO_EXTRACT_AND_COMPRESS_COLOR_PATH)/$(1).png
	$(EXTRACT_COLOR_IMAGE_DATA) $$< $$@
endef

define GS_IMAGES_RAW_EXTRACTION_TEMPLATE
$(TO_COMPRESS_PATH)/$(1).raw: $(TO_EXTRACT_AND_COMPRESS_GS_PATH)/$(1).png
	$(EXTRACT_GS_IMAGE_DATA) $$< $$@
endef

all:
	make sta

phc:
	make $(OUTPUT_PATH)/$(TARGET)

sta:
	make $(OUTPUT_PATH)/$(SAVESTATE)

rebuild:
	make clean
	make all

$(TO_COMPRESS_PATH)/%.bin: $(CIRCUITS_PATH)/%.data $(TO_COMPRESS_PATH)
	$(AS) $< -Fbin -o $@ -quiet

$(OBJ_PATH)/race.o: res_raw/guy_win_1.raw res_raw/guy_win_2.raw res_raw/guy_loose_1.raw res_raw/guy_loose_2.raw
$(OBJ_PATH)/textwrite.o: res_raw/smallfont.raw
$(OBJ_PATH)/circuit_picker.o : res_raw/trophy.raw

$(TO_COMPRESS_PATH)/%.raw: $(TO_EXTRACT_AND_COMPRESS_PATH)/%.png
	$(EXTRACT_RAW_IMAGE_DATA) $< $@

$(RESOURCES_RAW)/%.raw: $(BMP_TO_EXTRACT_PATH)/%.png $(RESOURCES_RAW)
	$(EXTRACT_RAW_IMAGE_DATA) $< $@

$(foreach file,$(notdir $(basename $(COLOR_IMAGES_RAW))),$(eval $(call COLOR_IMAGES_RAW_EXTRACTION_TEMPLATE,$(file))))

$(foreach file,$(notdir $(basename $(GS_IMAGES_RAW))),$(eval $(call GS_IMAGES_RAW_EXTRACTION_TEMPLATE,$(file))))

$(OUTPUT_PATH)/$(SAVESTATE): $(OUTPUT_PATH)/$(TARGET) $(STUFFING_SAVESTATE)
	$(INJECT) $(STUFFING_SAVESTATE) $(OUTPUT_PATH)/$(TARGET) $(OUTPUT_PATH)/$(SAVESTATE)
	copy $(OUTPUT_PATH)\$(SAVESTATE) $(MAME_SAVESTATE_PATH)

$(OUTPUT_PATH)/$(TARGET): $(OUTPUT_PATH) $(OBJ_PATH) $(OBJ) main.ld
	$(LD) $(LDFLAGS) -o $(OUTPUT_PATH)/$(TARGET) $(OBJ) -M > $(SECTION_MAP_FILE)
	$(APPLY_PHC_MASK) $(OUTPUT_PATH)/$(TARGET) $(OUTPUT_PATH)/$(SECTION_MAP_FILE)

$(COMPRESSED_FILES_INCLUDER): $(EXTRACTED_TO_COMPRESS) $(CIRCUITS_BIN) $(GS_IMAGES_RAW) $(COLOR_IMAGES_RAW)

$(OBJ_PATH)/%.o: %.s $(INC) $(PRECOMP_PATH)
	$(AS) $(ASFLAGS) -L $(PRECOMP_PATH)/$<.txt -o $@ $< -DDEBUG=$(DEBUG) -DJOYSTICK=$(JOYSTICK)

$(RLH_COMPRESSOR_SOURCE_FILE) $(COMPRESSED_FILES_INCLUDER) $(COMPRESSED): $(TO_COMPRESS_ALL) $(COMPRESSION_PATH) $(TO_COMPRESS_PATH) $(COLOR_IMAGES_RAW) $(GS_IMAGES_RAW)
	$(HUFF80) $(foreach file,$(notdir $(TO_COMPRESS_BMP)),$(TO_COMPRESS_PATH)/$(basename $(file)).png,$(COMPRESSION_PATH)/$(basename $(file)).rlh,62) $(foreach file,$(notdir $(TO_COMPRESS_OTHER)),$(TO_COMPRESS_PATH)/$(file),$(COMPRESSION_PATH)/$(basename $(file)).rlh) $(RLH_COMPRESSOR_SOURCE_FILE)
	echo ; This file is automatically generated. Please don't change it manually > $(GENERATED_RESOURCE_CODE_FILE)
	echo 	section	compressed,text >> $(GENERATED_RESOURCE_CODE_FILE)
	$(foreach FILE,$(notdir $(TO_COMPRESS_ALL)),$(RESOURCE_FILE_TEMPLATE))

# Directories creation
$(COMPRESSION_PATH):
	mkdir $(COMPRESSION_PATH)

$(OUTPUT_PATH):
	mkdir $(OUTPUT_PATH)

$(OBJ_PATH):
	mkdir $(OBJ_PATH)

$(PRECOMP_PATH):
	mkdir $(PRECOMP_PATH)

$(TO_COMPRESS_PATH):
	mkdir $(TO_COMPRESS_PATH)

$(RESOURCES_RAW):
	mkdir $(RESOURCES_RAW)

clean:
ifneq ($(wildcard $(COMPRESSION_PATH)),)
	rmdir /S /Q $(COMPRESSION_PATH)
endif
ifneq ($(wildcard $(PRECOMP_PATH)),)
	rmdir /S /Q $(PRECOMP_PATH)
endif
ifneq ($(wildcard $(OBJ_PATH)),)
	rmdir /S /Q $(OBJ_PATH)
endif
ifneq ($(wildcard $(SECTION_MAP_FILE)),)
	del $(SECTION_MAP_FILE)
endif
ifneq ($(wildcard $(TARGET)),)
	del $(TARGET)
endif
ifneq ($(wildcard $(SAVESTATE)),)
	del $(SAVESTATE)
endif
ifneq ($(wildcard $(COMPRESSION_STRATEGY_CACHE_FILE)),)
	del $(COMPRESSION_STRATEGY_CACHE_FILE)
endif
	cd $(TO_COMPRESS_PATH) & $(foreach FILE,$(EXTRACTED_TO_COMPRESS),del $(notdir $(FILE)) &)
	cd $(TO_COMPRESS_PATH) & $(foreach FILE,$(COLOR_IMAGES_RAW),del $(notdir $(FILE)) &)
	cd $(TO_COMPRESS_PATH) & $(foreach FILE,$(GS_IMAGES_RAW),del $(notdir $(FILE)) &)
	cd $(TO_COMPRESS_PATH) & $(foreach FILE,$(CIRCUITS_BIN),del $(notdir $(FILE)) &)
	cd $(RESOURCES_RAW) & $(foreach FILE,$(EXTRACTED_BMP),del $(notdir $(FILE)) &)
