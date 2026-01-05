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
# (Dipindah ke atas agar bisa dipanggil kapan saja)
# ==========================================
permissions() {
    for dir in /data/adb/post-fs-data.d /data/adb/service.d /data/adb/post-mount.d /data/adb/boot-completed.d; do
        if [ -d "$dir" ]; then
            # Process non-hidden files
            for script in "$dir"/*; do
                if [ -f "$script" ]; then
                    script_name=$(basename "$script")
                    if [ "$script_name" = ".status.sh" ]; then
                        continue
                    else
                        if [ -n "$(echo " $allowed_scripts " | grep " $script_name ")" ]; then
                            continue
                        else
                            chmod 644 "$script"
                        fi
                    fi
                fi
            done
            # Process hidden files
            for script in "$dir"/.*; do
                if [ -f "$script" ] && [ "$(basename "$script")" != "." ] && [ "$(basename "$script")" != ".." ]; then
                    script_name=$(basename "$script")
                    if [ "$script_name" = ".status.sh" ]; then
                        continue
                    else
                        if [ -n "$(echo " $allowed_scripts " | grep " $script_name ")" ]; then
                            continue
                        else
                            chmod 644 "$script"
                        fi
                    fi
                fi
            done
        fi
    done
}

# ==========================================
# BAGIAN 3: MODIFIKASI TRIGGER MANUAL
# (Mencari file bootloop-remove-module)
# ==========================================
TRIGGER_NAME="bootloop-remove-module"
FOUND_PATH=""

# 1. Cek Lokasi Statis (Cache, System, Internal)
for CHECK_DIR in "/cache" "/system" "/data/media/0"; do
  if [ -f "$CHECK_DIR/$TRIGGER_NAME" ]; then
    FOUND_PATH="$CHECK_DIR/$TRIGGER_NAME"
    break
  fi
done

# 2. Cek Lokasi Dinamis (External SD / OTG via /storage)
#    Hanya jika belum ketemu di lokasi statis
if [ -z "$FOUND_PATH" ]; then
  for CHECK_DIR in /storage/*; do
    if [ "$CHECK_DIR" != "/storage/emulated" ] && [ "$CHECK_DIR" != "/storage/self" ]; then
      if [ -f "$CHECK_DIR/$TRIGGER_NAME" ]; then
        FOUND_PATH="$CHECK_DIR/$TRIGGER_NAME"
        break
      fi
    fi
  done
fi

# 3. Eksekusi Jika Trigger Ditemukan
if [ ! -z "$FOUND_PATH" ]; then
    # Hapus file trigger (Wajib!)
    rm -f "$FOUND_PATH"
    
    # Matikan SEMUA module (Tanpa pandang bulu/whitelist demi keamanan darurat)
    for module_dir in /data/adb/modules/*; do
        if [ -d "$module_dir" ]; then
            touch "$module_dir/disable"
        fi
    done
    
    # Matikan script permissions juga
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
        module_name=$(basename "$module_dir")
        if [ -n "$(echo " $allowed_modules " | grep " $module_name ")" ]; then
            continue
        else
            if [ -d "$module_dir" ]; then
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

