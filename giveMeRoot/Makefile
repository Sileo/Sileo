TARGET  = giveMeRoot
OUTDIR ?= bin

ifeq ($(SILEO_PLATFORM),darwin-arm64)
CC             ?= xcrun -sdk macosx cc -arch arm64
MAC = 1
else ifeq ($(SILEO_PLATFORM),darwin-amd64)
CC             ?= xcrun -sdk macosx cc -arch x86_64
MAC = 1
else 
CC             ?= xcrun -sdk iphoneos cc -arch arm64
endif

TAGET_CODESIGN ?= ldid
CFLAGS         ?= -Wall

.PHONY: all clean

all: $(OUTDIR)/$(TARGET)


NIGHTLY ?= 0
BETA ?= 0
PREBOOT ?= 0

ifeq ($(DEBUG), 1)
    CFLAGS += 
else
    CFLAGS += -O2
endif

ifeq ($(BETA), 1)
	CFLAGS += -D BETA
else ifeq ($(NIGHTLY), 1)
	CFLAGS += -D NIGHTLY
endif

ifeq ($(MAC), 1)
	CFLAGS += -D MAC
endif

ifeq ($(PREBOOT), 1)
	CFLAGS += -D PREBOOT
endif

$(OUTDIR):
	@mkdir -p $(OUTDIR)

ifeq ($(MAC), 0)
$(OUTDIR)/$(TARGET): giveMeRoot.c | $(OUTDIR)
	@$(CC) -o $@ $^ $(CFLAGS)
	@$(TAGET_CODESIGN) -SEntitlements.plist $@
else
$(OUTDIR)/$(TARGET): giveMeRoot.c | $(OUTDIR)
	@$(CC) -o $@ $^ $(CFLAGS)
endif

clean:
	@rm -rf ./$(OUTDIR)
