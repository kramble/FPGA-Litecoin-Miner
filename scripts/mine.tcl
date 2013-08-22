##
#
# Copyright (c) 2011 fpgaminer@bitcoin-mining.com
#
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 
##


## TODO: Long polling.
## TODO: --verbose option for debugging issues.
## TODO: Handle multiple FPGAs at once.


package require http
package require json
package require base64

source utils.tcl
source json_rpc.tcl
source jtag_comm.tcl

# Configuration
# -------------
# Additional DEBUG output getwork and current nonce ...
set verbose 0
# Reads getwork (including nonce) from a file ...
set testmode 0
# Delay between getwork requests (in seconds) ...
set ask_rate 20
			
set total_accepted 0
set total_rejected 0

set test_total 0
set test_matches 0
set test_errors 0
set test_prevnonce 0
set prevtarget "none"
# Diff is just used for reporting, calculated from target so this is overwritten
set diff 32

proc say_line {msg} {
	set t [clock format [clock seconds] -format "%D %T"]
	puts "\[$t\] $msg"
}

proc say_error {msg} {
	set t [clock format [clock seconds] -format "%D %T"]
	puts stderr "\[$t\] $msg"
}

proc say_status {rate est_rate accepted rejected curnonce} {
	global verbose
	set submitted [expr {$rejected + $accepted}]

	if {$submitted == 0} {
		set rej_rate [expr {$rejected * 100.0}]
	} else {
		set rej_rate [expr {$rejected * 100.0 / $submitted}]
	}

	# BTC ...
	# say_line [format "%.2f MH/s (~%.2f MH/s) \[Rej: %i/%i (%.2f%%)\]" $rate $est_rate $rejected $submitted $rej_rate]
	
	# LTC ...
	if { $verbose } {
		say_line [format "%.2f kH/s (~%.2f kH/s) \[Rej: %i/%i (%.2f%%)\] n=%08x" $rate $est_rate $rejected $submitted $rej_rate $curnonce]
	} else {
		say_line [format "%.2f kH/s (~%.2f kH/s) \[Rej: %i/%i (%.2f%%)\]" $rate $est_rate $rejected $submitted $rej_rate]
	}
}

# Loop until a new share is found, or timeout seconds have passed.
# Prints status updates every second.
proc wait_for_golden_ticket {timeout} {
	global total_accepted
	global total_rejected
	global global_start_time
	global diff
	
	#puts "Current nonce"
	#set current_nonce [read_instance GNON]
	#puts $current_nonce
	set last_nonce [get_current_fpga_nonce]
	set begin_time [clock clicks -milliseconds]

	#puts "FPGA is now searching for lottery ticket..."

	while {$timeout > 0} {
		set golden_nonce [get_result_from_fpga]

		if {$golden_nonce != -1} {
			return $golden_nonce
		}

		# TODO: We may need to sleep for a small amount of time to avoid taxing the CPU
		# Or the JTAG comms might throttle back our CPU usage anyway.
		# If the FPGA had a proper results queue we could just sleep for a second, but
		# for now we might as well loop as fast as possible
		
		set now [clock clicks -milliseconds]
		if { [expr {$now - $begin_time}] >= 2000 } {
			incr timeout -2

			set current_nonce [get_current_fpga_nonce]
			set dt [expr {$now - $begin_time}]
			set begin_time $now

			if {$current_nonce < $last_nonce} {
				set nonces [expr {$current_nonce + (0xFFFFFFFF - $last_nonce) + 1}]
			} else {
				set nonces [expr {$current_nonce - $last_nonce + 1}]
			}

			set last_nonce $current_nonce

			if {$dt == 0} {
				set dt 1
			}

			# set rate [expr {$nonces / ($dt * 1000.0)}]
			set rate [expr {$nonces / ($dt * 1.0)}]
			set current_time [clock seconds]
			
			# Adding 0.00001 to the denom is a quick way to avoid divide by zero :P
			
			# BTC: each share is worth ~(2^32 / 1,000,000) MH/s
			# set est_rate [expr {($total_accepted + $total_rejected) * 4294.967296 / ($current_time - $global_start_time + 0.00001)}]
			
			# LTC: each share is worth ~(2^32 / 0x7ff / 1,000) kH/s ... sort of a guess really
			# Difficulty is calculated from target ...
			set est_rate [expr {($total_accepted + $total_rejected) * 65.59 * $diff / ($current_time - $global_start_time + 0.00001)}]

			say_status $rate $est_rate $total_accepted $total_rejected $current_nonce
		}
	}

	return -1
}

proc submit_nonce {workl golden_nonce} {
	global total_accepted
	global total_rejected
	global url
	global userpass

	array set work $workl

	set share(data) $work(data)
	set share(nonce) $golden_nonce

	if {[submit_work $url $userpass [array get share]] == true} {
		incr total_accepted
	} else {
		incr total_rejected
	}
}

proc parse_work_from_file {line} {
	array unset work

	set work(midstate) "0000000000000000000000000000000000000000000000000000000000000000"
	set work(data) $line
	set work(target) "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff070000"
	
	return [array get work]
}


puts " --- FPGA Mining Tcl Script --- \n\n"

if { $testmode } {
	puts "INFO Running in TEST mode, reading from test_data.txt\n"
	# Short test set
	set testfp [open "test_data.txt" r]
	# 1000 from ltc blockchain all valid
	#set testfp [open "test_data_full.txt" r]
	# Removed nonces > 0x0fffffff for multicore builds
	#set testfp [open "test_data_cut.txt" r]
}

puts "Looking for and preparing FPGAs...\n"
if {[fpga_init] == -1} {
	puts stderr "No mining FPGAs found."
	puts "\n\n --- Shutting Down --- \n\n"
	exit
}

set fpga_name [get_fpga_name]
puts "Mining FPGA Found: $fpga_name\n\n"

if {[get_current_fpga_nonce] == -1} {
	puts "WARNING: The FPGA's mining firmware does not report a hashrate. Status messages will show 0.00 MH/s, but the FPGA should still be running. Check the estimated rate for approximate hashing rate after shares have been submitted.\n\n"
}

source config.tcl
set userpass [::base64::encode $userpass]
set global_start_time [clock seconds]


set work -1

while {1} {
	# Get new work
	if { $testmode } {
		if { [gets $testfp line]	< 0 } {
			puts "EOF on test data"
			puts "$test_matches OK, $test_errors errors out of $test_total tested"
			break
		}
		# Status each time is useful for large test files
		puts "$test_matches OK, $test_errors errors out of $test_total tested"
		set newwork [parse_work_from_file $line]
		set test_total [expr $test_total + 1]
	} else {
		set newwork [get_work $url $userpass]
	}

	if {$newwork != -1} {
		# Check to see if the FPGA completed any results while we were getting new work.
		set golden_nonce [get_result_from_fpga]

		if {$golden_nonce != -1 && [array exists work]} {
			submit_nonce [array get work] $golden_nonce
		}

		push_work_to_fpga $newwork
		unset work
		array set work $newwork
	}

	# Even if we couldn't get new work above, we should still loop looking for results,
	# because the FPGA will (currently) continue to mine.
	# TODO: In the future the FPGA will go idle once it completes its work.
	
	# We wait 20 seconds, because after 20 seconds we should go get new work from the pool.
	# Getting new work every 20 seconds helps prevent stale shares.
	# TODO: Implement Long Polling ... :P

	# kramble: now using $ask_rate set at top of file
	set golden_nonce [wait_for_golden_ticket $ask_rate]

	if {$golden_nonce == -1 || ![array exists work]} {
		continue
	}

	if { $testmode } {
		# Check golden_nonce
		set gn [string range [reverseHex $work(data)] 96 103]
		if { [format "%08x" $golden_nonce] != $gn } {
			puts [format "ERROR golden nonce %08x does not match expected $gn" $golden_nonce]
			set test_errors [expr $test_errors + 1]
		} else {
			puts [format "OK golden nonce correct %08x" $golden_nonce]
			set test_matches [expr $test_matches + 1]
		}
		
	} else {
		submit_nonce [array get work] $golden_nonce
	}
}


puts "\n\n --- Shutting Down --- \n\n"



