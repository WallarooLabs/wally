#!/bin/sh

IN1=/tmp/aloc_sink.out.initializer.txnlog
IN=/tmp/aloc_sink.out.initializer.txnlog.short

case "$1" in
	commit)
		PATTERN_GOOD="2-ok"
		PATTERN_BAD="2-rollback"
	;;
	abort)
		PATTERN_GOOD="2-rollback"
		PATTERN_BAD="2-ok"
	;;
	*)
		echo "Usage: $0 commit|abort"
		exit 1
	;;
esac

if [ ! -f $IN1 ]; then
	echo Error: input file $IN1 does not exist
	exit 1
fi

# Clean up the file's transaction names a bit
cat $IN1 | sed 's/-w-initializer-id-[0-9]*:/:/' > $IN

# We expect rollbacks to happen for these checkpoint_ids
for c in 3; do
	pat="'Celsius[^']*c_id=$c.,"
	egrep "$pat" $IN | grep "$PATTERN_BAD" > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo Error: unexpected phase "$PATTERN_BAD" for checkpoint $c
		cat $IN; exit 1
	fi
	egrep "$pat" $IN | grep "$PATTERN_GOOD" > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo Error: phase "$PATTERN_GOOD" found for checkpoint $c
		cat $IN; exit 1
	fi
done

# We expect commits to happen for these checkpoint_ids
# There may be more checkpoints after 14, but we won't check
# because test timing can affect how many checkpoints may follow.
for c in 14; do
	pat="'Celsius[^']*c_id=$c.,"
	egrep "$pat" $IN | grep '2-rollback' > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo Error: unexpected phase 2-rollback for checkpoint $c
		cat $IN; exit 1
	fi
	egrep "$pat" $IN | grep '2-ok' > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo Error: phase 2-ok not found for checkpoint $c
		cat $IN; exit 1
	fi
done

echo "Validation of $IN1 was successful"
exit 0

