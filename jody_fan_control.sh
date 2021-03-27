#!/usr/bin/env sh

# Mac fan control service script
#
# Copyright (C) 2021 by Jody Bruchon <jody@jodybruchon.com>
#
VER=1.0
VERDATE="2021-03-26"

# The MIT License (MIT)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy 
# of this software and associated documentation files (the "Software"), to 
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:  The above 
# copyright notice and this permission notice shall be included in all copies 
# or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
# IN THE SOFTWARE.


# This script is meant to be placed in /usr/local/bin along with the "smc"
# command, and to run as a service under launchd. You'll also need to copy the
# file com.jodybruchon.fancontrol.plist into /Library/LaunchDaemons and set
# permissions on all files appropriately, and load into launchd. For example:
#
# sudo bash
# cd /Users/user_account_name/Downloads/jody-fan-control
# mkdir -p /usr/local/bin
# cp smc jody_fan_control.sh /usr/local/bin
# cp com.jodybruchon.fancontrol.plist /Library/LaunchDaemons
# chown root:wheel /usr/local/bin/smc /usr/local/bin/jody_fan_control.sh
# chmod 755 /usr/local/bin/smc /usr/local/bin/jody_fan_control.sh
# chown root:wheel /Library/LaunchDaemons/com.jodybruchon.fancontrol.plist
# chmod 644 /Library/LaunchDaemons/com.jodybruchon.fancontrol.plist
# launchctl load -w -F /Library/LaunchDaemons/com.jodybruchon.fancontrol.plist
#
# This installs the files and activates the service with launchd. If your Mac
# fans are racing due to sensor issues, you should hear them quiet down a few
# seconds after running the launchctl command; otherwise, you can verify that
# the script is now running by typing "pgrep -l jody_fan_control.sh" and
# a number appearing.
#
# You may need to modify the script below to suit your specific machine. It
# was originally made for an iMac 27-Inch Core i7 2.8 (Late 2009) with three
# fans. You can use "smc -f" to see how many fans you have. To get the core
# counts, run "smc -t | grep 'TC.C'" and look for the highest number. For the
# computer this was written to work with, the highest entry was TC1C, so the
# cores should be "0 1", while a machine with 4 core temperatures will go to
# TC3C and cores should be "0 1 2 3" instead. You may want to experiment with
# temperature thresholds and fan speeds; these are for a Gen 1 Core i7, but
# different CPUs will hit different temperatures at different loads. RPM is
# specified in HEXADECIMAL, NOT DECIMAL, so halfway between 1000 and 2000 is
# 1800, not 1500.
#
# You'll also need to modify "Set fans to forced mode" if you don't have 3
# fans. Use 0001 for 1, 0003 for 2, 0007 for 3, 000f for 4, 0010 for 5, 0011
# for 6, 0013 for 7, 0017 for 8, and so on. The value is a bit mask in hex.
#
# If you change the poll interval, be careful; setting it too low will cause
# very frequent polling and may have a small impact on computer performance,
# while setting it too high will cause rseponse to changing temperatures to
# be too slow and possibly cause overheating and hardware damage. The default
# of 5 seconds is generally a good choice.
#
# Running with -D will cause debugging info to be printed during execution.
# This should be left off for use as a launchd service.
#
# If for some reason you need to recompile or modify the smc binary, its
# source code was included in the archive beside this script; simply cd to
# smc-command and type "make" to build. You'll need the Xcode command-line
# tools (and should be prompted to install them if you don't have them.)


# Poll interval
INTERVAL=5

# CPU setup - cores, thresholds, and hex values for smc
CORES="0 1"
MID_T=43
HIGH_T=50
LOW_RPM=1600
MID_RPM=2000
HIGH_RPM=4000

# Fan setup - number of fans (use A-J for 10+) and check interval in seconds
FANS="0 1 2"

# Set fans to forced mode
smc -k "FS! " -w 0007

# Force initialization
STATE="x"
NEW_SPEED=0

# Set debug mode - prints debug messages
[[ $1 = "-D" ]] && D=1

while true
	do
	AVG=0; AVGC=0
	# Get all CPU core temperatures and average them together
	for X in $CORES
		do
		T="$(smc -r -k "TC${X}C")"
		T="${T/%.*/}"
		T="${T/#* /}"
		AVG=$((AVG + T)); AVGC=$((AVGC + 1))
		[[ $D = 1 ]] && echo "Core $X temp $T"
	done
	T=$((AVG / AVGC))
	[[ $D = 1 ]] && echo "Average core temp $T"
	# Choose new speed based on temperature
	[[ $T -lt $MID_T && $STATE != "low" ]] && NEW_SPEED=$LOW_RPM && STATE=low
	[[ $T -ge $MID_T && $STATE != "mid" ]] && NEW_SPEED=$MID_RPM && STATE=mid
	[[ $T -ge $HIGH_T && $STATE != "high" ]] && NEW_SPEED=$HIGH_RPM && STATE=high

	# Set new speed if one was chosen
	if [[ $NEW_SPEED -gt 0 ]]
		then
		[[ $D = 1 ]] && echo "temp $T, new speed $STATE:$NEW_SPEED"
		for X in $FANS
			do smc -k "F${X}Tg" -w $NEW_SPEED
		done
	fi
	NEW_SPEED=0
	sleep $INTERVAL
done
