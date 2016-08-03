#!/bin/bash -e

echo -e "\033[0;31m"WARNING! This is a hacky script and not guaranteed to work. It is run with set -e and will exit on the first error encountered.'\033[0m'

if ! which crudini > /dev/null ; then
  echo "Please install crudini. 'pip install crudini'"
  exit 1
fi

if [ $# -lt 3 ]; then
  echo "Must supply at least the following arguments:"
  echo "1: custom command; ex: '/usr/bin/time -v -o @@SECTION@@.out'"
  echo "2: dagon ini file"
  echo "3..n: normal dagon arguments (not including ini file arguments)"
  echo
  echo "Examples:"
  echo "  Run double-divide in linux with /usr/bin/time writing output to @@SECTION@@.time.out (i.e. leader.time.out)"
  echo "    ./scratch/misc/run_dagon_with_custom_app.sh '/usr/bin/time -v -o @@SECTION@@.time.out' ./apps/double-divide/double-divide.ini --phone-home=127.0.0.1:8080 --timeout=10"
  echo
  echo "  Run double-divide in linux with /usr/bin/time writing output to standard output"
  echo "    ./scratch/misc/run_dagon_with_custom_app.sh '/usr/bin/time -v' ./apps/double-divide/double-divide.ini --phone-home=127.0.0.1:8080 --timeout=10"
  echo
  echo "  Run double-divide in mac os x with /usr/bin/time writing output to standard output"
  echo "    ./scratch/misc/run_dagon_with_custom_app.sh '/usr/bin/time -l' ./apps/double-divide/double-divide.ini --phone-home=127.0.0.1:8080 --timeout=10"
  echo
  echo "  Run double-divide in mac os x with /usr/bin/instruments writing output to @@SECTION@@.inst.trace (i.e. leader.inst.trace) using template 'Time Profiler'"
  echo "    ./scratch/misc/run_dagon_with_custom_app.sh '/usr/bin/instruments -D @@SECTION@@.inst.trace -t \"Time Profiler\"' ./apps/double-divide/double-divide.ini --phone-home=127.0.0.1:8080 --timeout=10"
  echo
  exit 1
fi

if [ ! -x ./dagon/dagon ]; then
  echo "Couldn't find dagon (or it's not executable): ./dagon/dagon"
  exit 1
fi

declare -a 'wrapper_app=('"${1}"')'
shift
ini_file=${1}
new_ini_file=tmp_`basename ${1}`
shift

echo wrapper_app is "${wrapper_app[@]}"
echo ini_file is ${ini_file}
echo dagon args are "$@"
echo -e temporary ini_file is ${new_ini_file} "\033[0;31m(you'll have to delete it manually if there's an error)\033[0m"

cp ${ini_file} ${new_ini_file}

for section in `crudini --get ${new_ini_file}`
do
  if [ ${section} == docker ]; then
    continue
  fi
  if [ ${section} == docker-env ]; then
    continue
  fi
  old_path=`crudini --get ${new_ini_file} ${section} path`
  i=0
  for a in "${wrapper_app[@]}"
  do
    arg=${a/@@SECTION@@/$section}
    arg=`echo ${a} | sed "s/@@SECTION@@/${section}/g"`
    if [ ${i} -eq 0 ]; then
      crudini --set ${new_ini_file} ${section} wrapper_path "${arg}"
    else
      crudini --set ${new_ini_file} ${section} wrapper_args_${i} "${arg}"
    fi
    i=$((i+1))
  done
done

i=0
for a in "${wrapper_app[@]}"
do
  wrapper[i]=`echo ${a} | sed "s/@@SECTION@@/dagon/g"`
  i=$((i+1))
done

echo running dagon with the following arguments: "${wrapper[@]}" ./dagon/dagon "$@" --filepath=${new_ini_file}
"${wrapper[@]}" ./dagon/dagon "$@" --filepath=${new_ini_file}

echo deleting temporary ini_file ${new_ini_file}
rm ${new_ini_file}

