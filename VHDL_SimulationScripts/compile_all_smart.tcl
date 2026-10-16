# User parameters
set SRC_PATH "../VHDL_Implementation"
set BUILD_DIR "./build"
set VCOM_VERSION 93

# Select which file to use as top level
# set TESTBENCH_FILE "..\\VHDL_Testbenches\\TB_DLX.vhd" 

# Set MEM_FILE to the input memory file relative to current directory
# set MEM_FILE "../../asm_example/test_jump.mem"

# Pass --clean to the do command to force a complete recompile and wipe the cache/work dir
set FORCE_CLEAN 0
if {[info exists do_argv] && [lsearch -exact $do_argv "--clean"] >= 0} {
    set FORCE_CLEAN 1
}

# Cache file configuration
set CACHE_FILE ".compile_cache"

# Script setup, clear previous result
quit -sim

puts "Entering [file dirname [info script]]"
cd "[file dirname [info script]]"

# Set the full datapaths with the "normalize" command
set WORK_DIR [file normalize "$BUILD_DIR/work"]
set CACHE_FILE [file normalize "$BUILD_DIR/$CACHE_FILE"]

# Handle manual clean flag or missing work library
if {$FORCE_CLEAN == 1} {
    puts "FORCE_CLEAN enabled: Purging work library"
    if {[file exists $WORK_DIR]} {
        vdel -lib $WORK_DIR -all -quiet
        file delete -force $WORK_DIR
    }

    foreach path [glob -nocomplain "wlf*"] {
        if {[catch {file delete -force -- $path} error_message]} {
            puts stderr "WARNING: Unable to delete locked waveform $path: $error_message"
        } else {
            puts "Deleted $path"
        }

    }

}

set work_existed [file exists $WORK_DIR]

# If the work library was freshly created, ensure no stale cache survives
if {!$work_existed && [file exists $CACHE_FILE]} {
    puts "FORCE_CLEAN enabled: Purging cache file"
    file delete -force $CACHE_FILE

    # Remove compile_cache in memory 
    if {[info exists compile_cache]} {
        unset compile_cache
}
}

# Re initialize the work dir
vlib $WORK_DIR
vmap work $WORK_DIR

# ==========================================
# INCREMENTAL COMPILATION FUNCTION
# ==========================================
proc vcom_smart {file} {
    global compile_cache CACHE_FILE VCOM_VERSION
    
    # Lazy initialization: load cache from disk on the very first call
    if {![info exists compile_cache]} {
        set compile_cache [dict create]
        if {[file exists $CACHE_FILE]} {
            set f [open $CACHE_FILE r]
            while {[gets $f line] >= 0} {
                if {[regexp {^(\d+)\s+(.*)$} $line -> mtime filepath]} {
                    dict set compile_cache $filepath $mtime
                }
            }
            close $f
        }
    }

    set norm_file [file normalize $file]
    set current_mtime [file mtime $norm_file]

    # Get cached mtime (default to 0 if missing)
    if {[dict exists $compile_cache $norm_file]} {
        set cached_mtime [dict get $compile_cache $norm_file]
    } else {
        set cached_mtime 0
    }
    
    # Compile only if the source file is newer than the cached timestamp
    if {$current_mtime > $cached_mtime} {
        if {[catch {quietly vcom -quiet -work work $file -$VCOM_VERSION} error_message]} {
            puts stderr "ERROR: Failed to compile $file"
            return -code error $error_message
        }
        dict set compile_cache $norm_file $current_mtime
    } else {
        puts "Up-to-date: $file"
    }
}

# Save cache mapping to disk
proc save_compile_cache {} {
    global compile_cache CACHE_FILE
    if {[info exists compile_cache]} {
        set f [open $CACHE_FILE w]
        dict for {filepath mtime} $compile_cache {
            puts $f "$mtime $filepath"
        }
        close $f
    }
}

proc compile_source_tree {directory} {
    set directory [file normalize $directory]
    puts "Compiler entering $directory"
    
    # List all directories in the current directory
    foreach subdirectory [lsort -dictionary [glob -nocomplain -types d -directory $directory *]] {
        compile_source_tree $subdirectory
    }
    # Compile all files in the current directory, once all sub directories have been compiled
    foreach source_file [lsort -dictionary [glob -nocomplain -types f -directory $directory *.vhd *.vhdl]] {
        
        vcom_smart $source_file
    }

}

# Copy memory file if modified
if {$MEM_FILE ne ""} {
    set mem_src [file normalize $MEM_FILE]
    if {[file exists $mem_src]} {
            file copy -force $mem_src "$BUILD_DIR/iram.mem"
            # Suppress informational output.
    } else {
        puts stderr "ERROR: memory file not found: $mem_src"
    }
}

try {
    # Compile the VHDL source
    compile_source_tree $SRC_PATH
    # Compile the testbench
    vcom_smart $TESTBENCH_FILE
} finally {
    save_compile_cache
}
