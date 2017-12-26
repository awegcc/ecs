#!/bin/sh
#
# getopts function can be used to parse long options by putting a dash character followed by a colon into the OPTSPEC

function usage()
{
    echo "basename $0"
    echo " --loglevel"
    echo " -h"
    echo " -v"
    echo " -f filename"
}

OPTSPEC=':hvf:-:'
while getopts $OPTSPEC opt
do
    case $opt in
        -)# parse long options
            case "$OPTARG" in
                loglevel)
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    echo "Parsing option: '--${OPTARG}', value: '${val}'"
                    ;;
                loglevel=*)
                    val=${OPTARG#*=}
                    opt=${OPTARG%=$val}
                    echo "Parsing option: '--${opt}', value: '${val}'"
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${OPTSPEC:0:1}" != ":" ]
                    then
                        echo "Unknown option --${OPTARG}"
                    fi
                    ;;
            esac
        ;;
        h)
        usage
        ;;
        v)
        echo "version 1.0.1"
        ;;
        f)
        echo "optarg $OPTARG"
        ;;
        ?) echo 'error'
        ;;
    esac
done
