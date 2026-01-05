#!/bin/sh
DIR="${0%/*}"

# ==========================================
# BAGIAN 1: PERSIAPAN & WHITELIST
# ==========================================
file=/data/adb/YABP/allowed-modules.txt
file2=/data/adb/YABP/allowed-scripts.txt
allowed_modules=""

if [ -f "$file" ]; then
    while IFS= read -r line; do
        if [ "${line#\#}" != "$line" ] || [ -z "$line" ]; then
            continue
        else
            allowed_modules="$allowed_modules $line"
        fi
    done <"$file"
fi

allowed_scripts=""
if [ -f "$file2" ]; then
    while IFS= read -r line; do
        if [ "${line#\#}" != "$line" ] || [ -z "$line" ]; then
            continue
        else
            allowed_scripts="$allowed_scripts $line"
        fi
    done <"$file2"
fi

# ==========================================
# BAGIAN 2: FUNGSI PERMISSIONS
# ==========================================
permissions() {
    for dir in /data/adb/post-fs-data.d /data/adb/service.d /data/adb/post-mount.d /data/adb/boot-completed.d; do
        if [ -d "$dir" ]; then
            # Proses file biasa dan file hidden (.*)
            for script in "$dir"/* "$dir"/.*; do
                if [ -f "$script" ] && [ "$(basename "$script")" != "." ] && [ "$(basename "$script")" != ".." ]; then
                    script_name=$(basename "$script")
                    
                    if [ "$script_name" = ".status.sh" ]; then
                        continue
                    fi

                    if [ -n "$(echo " $allowed_scripts " | grep " $script_name ")" ]; then
                        continue
                    else
                        chmod 644 "$script"
                    fi
                fi
            done
        fi
    done
}

# ==========================================
# BAGIAN 3: MODIFIKASI TRIGGER MANUAL
# (Updated: Support /mnt/media_rw)
# ==========================================
TRIGGER_NAME="bootloop-remove-module"
FOUND_PATH=""

# 1. Cek Lokasi Statis (Cache, System, Internal)
for CHECK_DIR in "/cache" "/system" "/product" "/system/ext" "/data/media/0"; do
  if [ -f "$CHECK_DIR/$TRIGGER_NAME" ]; then
    FOUND_PATH="$CHECK_DIR/$TRIGGER_NAME"
    break
  fi
done

# 2. Cek Lokasi Dinamis (/storage DAN /mnt/media_rw)
#    Looping ini sangat ampuh mencari SD Card/OTG yang mount point-nya belum siap
if [ -z "$FOUND_PATH" ]; then
  # Gabungkan pencarian di storage dan mnt/media_rw
  for BASE_DIR in /storage/* /mnt/media_rw/*; do
    # Pastikan direktori itu ada (untuk menghindari error globbing)
    if [ -d "$BASE_DIR" ]; then
        
        # Filter folder yang tidak perlu dicek
        case "$BASE_DIR" in
            *emulated*|*self*|*knox*|*secure*|*asec*|*obb*) 
                continue 
                ;;
        esac
        
        # Cek apakah file trigger ada di sana
        if [ -f "$BASE_DIR/$TRIGGER_NAME" ]; then
            FOUND_PATH="$BASE_DIR/$TRIGGER_NAME"
            break
        fi
    fi
  done
fi

# 3. Eksekusi Jika Trigger Ditemukan
if [ ! -z "$FOUND_PATH" ]; then
    # Hapus file trigger (Wajib!)
    rm -f "$FOUND_PATH"
    
    # Matikan SEMUA module (Emergency Kill)
    for module_dir in /data/adb/modules/*; do
        if [ -d "$module_dir" ]; then
            touch "$module_dir/disable"
        fi
    done
    
    # Matikan script permissions
    permissions
    
    # Reboot system segera
    reboot
    exit 0
fi

# ==========================================
# BAGIAN 4: LOGIKA COUNTER BOOTLOOP ASLI
# ==========================================
if [ -f "$DIR/s1" ] && [ -f "$DIR/s2" ] && [ -f "$DIR/s3" ]; then
    rm -f "$DIR/s1" "$DIR/s2" "$DIR/s3"
    
    # Disable modules (Dengan mengecek Whitelist)
    for module_dir in /data/adb/modules/*/; do
        if [ -d "$module_dir" ]; then
            module_name=$(basename "$module_dir")
            if [ -n "$(echo " $allowed_modules " | grep " $module_name ")" ]; then
                continue
            else
                touch "$module_dir/disable"
            fi
        fi
    done
    
    permissions
    reboot
elif [ -f "$DIR/s2" ]; then
    touch "$DIR/s3"
elif [ -f "$DIR/s1" ]; then
    touch "$DIR/s2"
else
    touch "$DIR/s1"
fi
