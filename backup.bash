#!/usr/bin/env bash

usage() {
	cat <<- EOF
	Usage: $0 [-h] [-o OUTPUT] -b|-r [FILE1 FILE2 ...]
	  -h              Output this message.

	  -o OUTPUT       In backup mode, this means the name of the output file
	                  and is, by default, "data_backup.tar.gpg".
	                  In recover mode, this means the directory where files are
	                  output and is, by default, the present working directory.

	  -b              Backup files and encrypt.

	  -r              Decrypt and recover files.

	  Backup mode takes multiple files and gives a single encrypted blob.
	  Recover mode takes multiple files and decrypts each one respectively.

	  If input files are not given, this implies that input files are in the 
	  directory from where the script is being called, i.e., pwd.
	EOF
}

# Return program execution time in seconds.
timeit() {
	# /usr/bin/time differentiates between the program and the shell built-in.
	echo $(/usr/bin/time -p $1 2>&1 | grep real | cut -d ' ' -f 2)
}

# Securely delete the target file. Use shred, otherwise fall back to dd.
#
# Most modern journal filesystems (ext3/4, ntfs) will only journal metadata, 
# not actual data.
# A quick way to check for this with ext4:
#   $ mount | grep 'data=journal'
#
# Obviously the files you are encrypting are untouched, but should you choose
# to delete them, you won't have to worry about the tar file that was created.
# Secure deletion of files is hard, but we try here anyways. For true secure
# deletion, you should also consider if your files previously existed elsewhere
# on disk, or if they are cached by any other processes.
securerm() {
	if $(which shred >& /dev/null); then
		shred "$1"
		sync # Sync random bytes first.
		shred -n 0 -u -z "$1"
		sync
	else
		bytes=$(stat -c '%s' "$1")
		dd if=/dev/urandom of="$1" bs=$bytes count=1 conv=notrunc >& /dev/null
		sync
		dd if=/dev/zero of="$1" bs=$bytes count=1 conv=notrunc >& /dev/null
		sync
		rm "$1"
		sync
	fi
}

#=============================================================================#

OUTPUT=
MODE=
FILES=

if [[ $# -lt 1 ]]; then
	echo "$0: You must choose either backup mode or recovery mode."
	usage
	exit 1
fi

while getopts "ho:br" OPT; do
	case $OPT in
		h)
			usage
			exit 0 ;;
		o)
			OUTPUT="$OPTARG" ;;
		b)
			if [[ -n $MODE ]]; then
				echo "$0: Please choose only one mode."
				usage
				exit 1
			fi
			MODE="backup" ;;
		r)
			if [[ -n $MODE ]]; then
				echo "$0: Please choose only one mode."
				usage
				exit 1
			fi
			MODE="recover" ;;
		*)
			usage
			exit 1 ;;
	esac
done
shift $((OPTIND - 1)) # Shift over to parse any input files arguments.

# Use files in pwd if no input files are given.
# This will backup all the files from where the script is run.
if [[ -z "$@" ]]; then
	FILES="*"
else
	FILES="$@"

	# Check if these files exist.
	for file in $FILES; do
		if [[ -e "$file" ]]; then
			continue
		else
			echo "$0: "$file" does not exist!"
			exit 1
		fi
	done
fi

if [[ $MODE == "backup" ]]; then
	# Set output file name.
	if [[ -z $OUTPUT ]]; then
		OUTPUT="data_backup.tar"
	else
		OUTPUT+=".tar"
	fi

	echo "Beginning archival process ..."
	exectime=$(timeit "tar -cf "$OUTPUT" $FILES --exclude="$OUTPUT.gpg"")

	if [[ $? -ne 0 ]]; then
		echo "$0: tar failed!"
		exit 1
	fi

	echo -e "Archiving finished in $exectime seconds.\n"

	echo "Enter encryption key:"
	gpg --cipher-algo AES256 --symmetric $OUTPUT

	securerm "$OUTPUT" # Delete intermediate tar file.
else
	# Set output directory.
	if [[ -z $OUTPUT ]]; then
		OUTPUT="."
	fi

	for file in $FILES; do
		# Skip non-GPG encrypted files.
		file "$file" | cut -d ' ' -f 2- | grep -i 'gpg' > /dev/null
		if [[ $? -ne 0 ]]; then
			continue
		fi

		out=${file%.gpg} # Strip .gpg file extension.

		echo "Enter decryption key for $file:"
		gpg --output $out --decrypt $file
		echo

		# Skip non-tar archived files.
		file "$out" | cut -d ' ' -f 2- | grep -i 'tar' > /dev/null
		if [[ $? -ne 0 ]]; then
			continue
		fi

		echo -e "Beginning de-archival process ..."
		exectime=$(timeit "tar -xf "$out" -C "$OUTPUT"")

		if [[ $? -ne 0 ]]; then
			echo "$0: tar failed!"
			exit 1
		fi

		echo -e "De-archiving finished in $exectime seconds."
		done

		securerm "$out"
fi
