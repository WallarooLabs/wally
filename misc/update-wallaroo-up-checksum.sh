#! /bin/bash

update_wally_up_checksum() {
  # update checksum in wallaroo-up.sh
  WALLAROO_UP_CHECKSUM_COMMAND=$(grep -Po '(?<=^CALCULATED_MD5="\$\().*(?=\)")' misc/wallaroo-up.sh | sed 's@\$0@misc/wallaroo-up.sh@')
  sed -i "s@^MD5=.*@MD5=\"$(eval $WALLAROO_UP_CHECKSUM_COMMAND)\"@" misc/wallaroo-up.sh
}

update_wally_up_checksum

