TARGET  = giveMeRoot
OUTDIR ?= bin
MAC ?= 0

ifeq ($(SILEO_PLATFORM),darwin-arm64)
CC             ?= xcrun -sdk macosx cc -arch arm64
TAGET_CODESIGN ?= 
else ifeq ($(SILEO_PLATFORM),darwin-amd64)
CC             ?= xcrun -sdk macosx cc -arch x86_64
TAGET_CODESIGN ?= 
else 
CC             ?= xcrun -sdk iphoneos cc -arch arm64
TAGET_CODESIGN ?= ldid
endif


CFLAGS         ?= -Wall

.PHONY: all clean

all: $(OUTDIR)/$(TARGET)

DEBUG ?= 0
NIGHTLY ?= 0
BETA ?= 0

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

$(OUTDIR):
	@mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): giveMeRoot.c | $(OUTDIR)
	@$(CC) -o $@ $^ $(CFLAGS)
	@$(TAGET_CODESIGN) -SEntitlements.plist $@

clean:
	@rm -rf ./$(OUTDIR)
