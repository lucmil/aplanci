#!/bin/sh -e

genkeys() {
	while [ "$#" -gt 0 ]; do
		s=".keys/$1"
		if ! [ -f "$s" ] && ! [ -f "$s".pub ]; then
			wg genkey | tee "$s" | wg pubkey > "$s".pub
			chmod u=rw "$s" "$s".pub
		else
			echo Key "$s" or "$s.pub" already exists. Skipping...
		fi
	   shift
	done
}

mkdir -p .keys
umask 077
[ -r .keys/psk ] || wg genpsk > .keys/psk

if [ $# -eq 0 ]; then
	genkeys client server
else
	genkeys $@
fi


