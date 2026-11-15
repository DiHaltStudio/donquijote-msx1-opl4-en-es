# Asset generation only: run the unmodified original renderer in an isolated
# emulator. CPU/register writes below are deliberate generation fixtures;
# they are never presented as input-only gameplay validation.
set save_settings_on_exit false
set throttle off
set mute on
set out $::env(QUIJOTE_VRAM_OUT)
source [file join $out plans.tcl]
set log [open [file join $out generation.tsv] w]
puts $log "scene\tseconds\toutside_unchanged\tname_table_unchanged"
set started 0
set scene_index 0
proc write_binary {path data} {
 set f [open $path wb]; fconfigure $f -translation binary
 puts -nonewline $f $data;close $f
}
proc vram_string {bytes} {binary format cu* $bytes}
proc v_next {} {
 if {$::scene_index >= [llength $::plans]} {
  close $::log
  write_binary [file join $::out finished.txt] "PASS [llength $::plans] scenes\n"
  exit
 }
 lassign [lindex $::plans $::scene_index] ::scene_name streams
 incr ::scene_index
 set code {205 115 223 205 205 223}
 foreach pointer $streams {
  lappend code 33 [expr {$pointer&255}] [expr {$pointer>>8}] 34 248 247 205 [expr {$::v_renderer&255}] [expr {$::v_renderer>>8}]
 }
 lappend code 195 208 239
 debug write_block memory 0xe900 [vram_string $code]
 reg SP 0xf200
 reg PC 0xe900
 set ::scene_started [machine_info time]
}
proc v_ready {} {
 if {$::started || [binary encode hex [debug read_block memory 0x712f 3]] ne "218473"} {return}
 set ::started 1
 set ::outside_before "[debug read_block VRAM 0x1000 4096][debug read_block VRAM 0x3000 4096]"
 set ::names_before [debug read_block VRAM 0x1800 512]
 write_binary [file join $::out initial-vram.bin] [debug read_block VRAM 0 16384]
 v_next
}
proc v_done {} {
 if {!$::started || [reg PC]!=0xefd0} {return}
 set data "[debug read_block VRAM 0 4096][debug read_block VRAM 0x2000 4096]"
 set outside "[debug read_block VRAM 0x1000 4096][debug read_block VRAM 0x3000 4096]"
 set names [debug read_block VRAM 0x1800 512]
 set unchanged [expr {$outside eq $::outside_before}]
 set names_same [expr {$names eq $::names_before}]
 puts $::log "$::scene_name\t[expr {[machine_info time]-$::scene_started}]\t$unchanged\t$names_same"
 flush $::log
 write_binary [file join $::out "$::scene_name.bin"] $data
 if {!$unchanged || !$names_same} {
  write_binary [file join $::out failed-vram.bin] [debug read_block VRAM 0 16384]
  close $::log
  write_binary [file join $::out finished.txt] "FAIL $::scene_name outside changed\n"
  exit
 }
 v_next
}
debug set_bp 0x712f {} v_ready
debug set_bp 0xefd0 {} v_done
after time 2 {type_via_keybuf "run\"cas:\"\r"}
after time 1200 {
 catch {close $::log}
 write_binary [file join $::out finished.txt] "FAIL timeout PC=[reg PC]\n"
 exit
}
