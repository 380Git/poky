#!/bin/bash
#
# Copyright (c) 2011, Intel Corporation.
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# DESCRIPTION
# This script operates on the .dat file generated by bb-matrix.sh. It tolerates
# the header by skipping the first line, but error messages and bad data records
# need to be removed first. It will generate three views of the plot, and leave
# an interactive view open for further analysis.
#
# AUTHORS
# Darren Hart <dvhart@linux.intel.com>
#

# Setup the defaults
DATFILE="bb-matrix.dat"
XLABEL="BB\\\\_NUMBER\\\\_THREADS"
YLABEL="PARALLEL\\\\_MAKE"
FIELD=3
DEF_TITLE="Elapsed Time (seconds)"
PM3D_FRAGMENT="unset surface; set pm3d at s hidden3d 100"
SIZE="640,480"

function usage {
CMD=$(basename $0)
cat <<EOM
Usage: $CMD [-d datfile] [-f field] [-h] [-t title] [-w]
  -d datfile    The data file generated by bb-matrix.sh (default: $DATFILE)
  -f field      The field index to plot as the Z axis from the data file
                (default: $FIELD, "$DEF_TITLE")
  -h            Display this help message
  -s W,H        PNG and window size in pixels (default: $SIZE)
  -t title      The title to display, should describe the field (-f) and units
                (default: "$DEF_TITLE")
  -w            Render the plot as wireframe with a 2D colormap projected on the
                XY plane rather than as the texture for the surface
EOM
}

# Parse and validate arguments
while getopts "d:f:hs:t:w" OPT; do
	case $OPT in
	d)
		DATFILE="$OPTARG"
		;;
	f)
		FIELD="$OPTARG"
		;;
	h)
		usage
		exit 0
		;;
	s)
		SIZE="$OPTARG"
		;;
	t)
		TITLE="$OPTARG"
		;;
	w)
		PM3D_FRAGMENT="set pm3d at b"
		W="-w"
		;;
	*)
		usage
		exit 1
		;;
	esac
done

# Ensure the data file exists
if [ ! -f "$DATFILE" ]; then
	echo "ERROR: $DATFILE does not exist"
	usage
	exit 1
fi
PLOT_BASENAME=${DATFILE%.*}-f$FIELD$W

# Set a sane title
# TODO: parse the header and define titles for each format parameter for TIME(1)
if [ -z "$TITLE" ]; then
	if [ ! "$FIELD" == "3" ]; then
		TITLE="Field $FIELD"
	else
		TITLE="$DEF_TITLE"
	fi
fi

# Determine the dgrid3d mesh dimensions size
MIN=$(tail -n +2 "$DATFILE" | cut -d ' ' -f 1 | sed 's/^0*//' | sort -n | uniq | head -n1)
MAX=$(tail -n +2 "$DATFILE" | cut -d ' ' -f 1 | sed 's/^0*//' | sort -n | uniq | tail -n1)
BB_CNT=$[${MAX} - $MIN + 1]
MIN=$(tail -n +2 "$DATFILE" | cut -d ' ' -f 2 | sed 's/^0*//' | sort -n | uniq | head -n1)
MAX=$(tail -n +2 "$DATFILE" | cut -d ' ' -f 2 | sed 's/^0*//' | sort -n | uniq | tail -n1)
PM_CNT=$[${MAX} - $MIN + 1]


(cat <<EOF
set title "$TITLE"
set xlabel "$XLABEL"
set ylabel "$YLABEL"
set style line 100 lt 5 lw 1.5
$PM3D_FRAGMENT
set dgrid3d $PM_CNT,$BB_CNT splines
set ticslevel 0.2

set term png size $SIZE
set output "$PLOT_BASENAME.png"
splot "$DATFILE" every ::1 using 1:2:$FIELD with lines ls 100

set view 90,0
set output "$PLOT_BASENAME-bb.png"
replot

set view 90,90
set output "$PLOT_BASENAME-pm.png"
replot

set view 60,30
set term wxt size $SIZE
replot
EOF
) | gnuplot --persist
