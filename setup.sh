#!/bin/bash

cd `dirname "$0"`

if which apm > /dev/null; then
	# This step should fetch and build the dependencies...
	echo "Performing apm install to fetch and build dependent packages..."
	if apm install; then
		# if install was successful, link the repo copy of the package into Atom.
		if [ -d "$HOME/.atom/packages/atomic-halide" ]; then
			echo "Atomic Halide package already installed."
		elif [ -d "$HOME/.atom/packages/" ]; then
			echo "Locally installing atomic-halide package into Atom."
			if ln -s `pwd` ~/.atom/packages/atomic-halide; then
				echo Installed package. Restart Atom or run \"Reload\" in the View menu.
			else
				echo Error creating package symlink in Atom packages.
			fi
		else
			echo "Atom packages directory not found, skipping install."
		fi
	else
		echo "apm install failed!"
		exit 1
	fi
else
	echo No apm shell command found.
	echo Run \"Install Shell Commands\" in the Atom application menu and try again.
	exit 1
fi

