#!/bin/sh

IN1=/tmp/aloc_sink.out.initializer.txnlog
IN=/tmp/aloc_sink.out.initializer.txnlog.short

if [ ! -f $IN1 ]; then
	echo Error: input file $IN1 does not exist
	exit 1
fi

# Clean up the file's transaction names a bit
cat $IN1 | sed 's/worker-initializer-id-[0-9]*://' > $IN

# We expect rollbacks to happen for these checkpoint_ids
for c in 3 6 9 15; do
	pat="'Celsius[^']*c_id=$c.,"
	egrep "$pat" $IN | grep '2-ok' > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo Error: unexpected phase 2-ok for checkpoint $c
		cat $IN; exit 1
	fi
	egrep "$pat" $IN | grep '2-rollback' > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo Error: phase 2-rollback not found for checkpoint $c
		cat $IN; exit 1
	fi
done

# We expect commits to happen for these checkpoint_ids
# There may be more checkpoints after 18, but we won't check
# because test timing can affect how many checkpoints may follow.
# Also, 18 is the last checkpoint that aloc_sink.abort-rules
# will affect.
# We skip 19 because a race condition that we can't control
# may/may not cause a gap in Wallaroo's output and thus a
# Phase 1 abort vote by the sink.
# We check 20 because checkpointing should continue
# after 18 (some bugs related to 18's scenario can prevent
# future checkpoints).
for c in 1 2 4 5 7 8 11 12 13 14 16 17 18 20; do
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

