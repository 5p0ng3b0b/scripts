#!/system/bin/sh
##################################################
#
# Extract DTB from boot.img or boot.PARTITION
# 2020/03/04 5p0ng3b0b
#
##################################################
if [ -z $@ ]; then echo "Usage: $(basename $0) [image file]"; exit; fi
IMG_FILE="$1"
BOOT_MAGIC='ANDROID!'
BOOT_MAGIC_SIZE=8
BYTES=4
if [ ! -e $IMG_FILE ]; then echo "Could not open file ${IMG_FILE}, giving up."; exit; fi
if [ ! $(dd if=$IMG_FILE bs=1 count=$BOOT_MAGIC_SIZE 2>/dev/null) = $BOOT_MAGIC ]; then echo "Android magic not found, giving up"; exit; fi

# Get device board ID
BOARD_ID=$(tr -d '\0' </proc/device-tree/amlogic-dt-id)
# Start extraction
PAGE_SIZE=$((16#$(dd if=$IMG_FILE bs=1 skip=36 count=$BYTES 2>/dev/null | od -tx1 | head -n1 | cut -d ' ' -f 2- | awk '{print $4$3$2$1}')))
KERNEL_SIZE=$((16#$(dd if=$IMG_FILE bs=1 skip=8 count=$BYTES 2>/dev/null | od -tx1 | head -n1 | cut -d ' ' -f 2- | awk '{print $4$3$2$1}')))
RAMDISK_SIZE=$((16#$(dd if=$IMG_FILE bs=1 skip=16 count=$BYTES 2>/dev/null | od -tx1 | head -n1 | cut -d ' ' -f 2- | awk '{print $4$3$2$1}')))
SECOND_SIZE=$((16#$(dd if=$IMG_FILE bs=1 skip=24 count=$BYTES 2>/dev/null | od -tx1 | head -n1 | cut -d ' ' -f 2- | awk '{print $4$3$2$1}')))
n=$((($KERNEL_SIZE + $PAGE_SIZE - 1) / $PAGE_SIZE))
m=$((($RAMDISK_SIZE + $PAGE_SIZE - 1) / $PAGE_SIZE))
o=$((($SECOND_SIZE + $PAGE_SIZE - 1) / $PAGE_SIZE))
KERNEL_OFFSET=$PAGE_SIZE
RAMDISK_OFFSET=$(($KERNEL_OFFSET + ($n * $PAGE_SIZE)))
SECOND_OFFSET=$(($RAMDISK_OFFSET + ($m * $PAGE_SIZE)))
if [ -z "$SECOND_OFFSET" ]; then echo "Could not find second stage boot image, giving up."; exit; fi
dd if="$IMG_FILE" of="${IMG_FILE}-second.gz" bs=1 skip=$SECOND_OFFSET count=$SECOND_SIZE 2>/dev/null
gunzip -f "${IMG_FILE}-second.gz"
DTB_LIST=$(od -Ad -tx1 ${IMG_FILE}-second | grep 'd0 0d fe ed' | awk '{print $1}')
if [ -z "$DTB_LIST" ]; then echo "No DTB headers found, giving up"; exit; fi
for DTB_OFFSET in $DTB_LIST; do
    DTB_LEN=$((16#$(dd if="${IMG_FILE}-second" bs=1 skip=$(($DTB_OFFSET + 4)) count=4 2>/dev/null | od -tx1 | head -n 1 | cut -d ' ' -f 2- | sed 's/ //g' )))
    ID=$(dd if="${IMG_FILE}-second" bs=1 skip=$(($DTB_OFFSET + 96)) count=16 2>/dev/null | sed 's#\x0##g')
	if [ "$ID" = "$BOARD_ID" ]; then 
    dd if="${IMG_FILE}-second" of="${ID}.dtb" bs=1 skip=$DTB_OFFSET count=$DTB_LEN 2>/dev/null
    echo "Extracted: ${ID}.dtb Size: $(du ${ID}.dtb | awk '{print $1}')Kb Offset: $DTB_OFFSET Length: $DTB_LEN"
    fi
    done
rm -f ${IMG_FILE}-second

