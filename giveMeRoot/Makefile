TARGET  = giveMeRoot
OUTDIR ?= bin
CC             ?= xcrun -sdk iphoneos clang -arch arm64 -mios-version-min=11.0

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


ifeq ($(PREBOOT), 1)
	CFLAGS += -D PREBOOT
endif

$(OUTDIR):
	@mkdir -p $(OUTDIR)

$(OUTDIR)/$(TARGET): giveMeRoot.c | $(OUTDIR)
	@$(CC) -o $@ $^ $(CFLAGS)
	@$(TAGET_CODESIGN) -SEntitlements.plist $@

clean:
	@rm -rf ./$(OUTDIR)
