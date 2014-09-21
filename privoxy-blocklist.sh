#!/bin/bash
#
######################################################################
#
#                  Author: Andrwe Lord Weber
#                  Mail: lord-weber-andrwe <at> andrwe <dot> org
#                  Version: 0.3
#                  URL: http://andrwe.dyndns.org/doku.php/scripting/bash/privoxy-blocklist
#
##################
#
#                  Sumary:
#                   This script downloads, converts and installs
#                   AdblockPlus lists into Privoxy
#
######################################################################

######################################################################
#
#                 TODO:
#                  - implement:
#                     domain-based filter
#                     id->class combination
#                     class->id combination
#
######################################################################

DBG=1
URLS=("https://easylist-downloads.adblockplus.org/easylist.txt")
TMPDIR=/tmp/privoxy-blocklist

rm -rf $TMPDIR
mkdir $TMPDIR

function usage()
{
  echo "${TMPNAME} is a script to convert AdBlockPlus-lists into Privoxy-lists and install them."
  echo " "
  echo "Options:"
  echo "      -h:    Show this help."
  echo "      -q:    Don't give any output."
  echo "      -v 1:  Enable verbosity 1. Show a little bit more output."
  echo "      -v 2:  Enable verbosity 2. Show a lot more output."
  echo "      -v 3:  Enable verbosity 3. Show all possible output and don't delete temporary files.(For debugging only!!)"
  echo "      -r:    Remove all lists build by this script."
}

function debug()
{
  [ ${DBG} -ge ${2} ] && echo -e "${1}"
}

function main()
{
  for url in ${URLS[@]}
  do
    debug "Processing ${url} ...\n" 0
    file=${TMPDIR}/$(basename ${url})
    actionfile=${file%\.*}.script.action
    filterfile=${file%\.*}.script.filter
    list=$(basename ${file%\.*})

    # download list
    debug "Downloading ${url} ..." 0
    wget -t 3 --no-check-certificate -O ${file} ${url}
    debug "$(cat ${TMPDIR}/wget-${url//\//#}.log)" 2
    debug ".. downloading done." 0
    [ "$(grep -E '^.*\[Adblock.*\].*$' ${file})" == "" ] && echo "The list recieved from ${url} isn't an AdblockPlus list. Skipped" && continue

    # convert AdblockPlus list to Privoxy list
    # blacklist of urls
    debug "Creating actionfile for ${list} ..." 1
    echo -e "{ +block{${list}} }" > ${actionfile}
    sed '/^!.*/d;1,1 d;/^@@.*/d;/\$.*/d;/#/d;s/\./\\./g;s/\?/\\?/g;s/\*/.*/g;s/(/\\(/g;s/)/\\)/g;s/\[/\\[/g;s/\]/\\]/g;s/\^/[\/\&:\?=_]/g;s/^||/\./g;s/^|/^/g;s/|$/\$/g;/|/d' ${file} >> ${actionfile}

    debug "... creating filterfile for ${list} ..." 1
    echo "FILTER: ${list} Tag filter of ${list}" > ${filterfile}
    # set filter for html elements
    sed '/^#/!d;s/^##//g;s/^#\(.*\)\[.*\]\[.*\]*/s@<([a-zA-Z0-9]+)\\s+.*id=.?\1.*>.*<\/\\1>@@g/g;s/^#\(.*\)/s@<([a-zA-Z0-9]+)\\s+.*id=.?\1.*>.*<\/\\1>@@g/g;s/^\.\(.*\)/s@<([a-zA-Z0-9]+)\\s+.*class=.?\1.*>.*<\/\\1>@@g/g;s/^a\[\(.*\)\]/s@<a.*\1.*>.*<\/a>@@g/g;s/^\([a-zA-Z0-9]*\)\.\(.*\)\[.*\]\[.*\]*/s@<\1.*class=.?\2.*>.*<\/\1>@@g/g;s/^\([a-zA-Z0-9]*\)#\(.*\):.*[:[^:]]*[^:]*/s@<\1.*id=.?\2.*>.*<\/\1>@@g/g;s/^\([a-zA-Z0-9]*\)#\(.*\)/s@<\1.*id=.?\2.*>.*<\/\1>@@g/g;s/^\[\([a-zA-Z]*\).=\(.*\)\]/s@\1^=\2>@@g/g;s/\^/[\/\&:\?=_]/g;s/\.\([a-zA-Z0-9]\)/\\.\1/g' ${file} >> ${filterfile}
    debug "... filterfile created - adding filterfile to actionfile ..." 1
    echo "{ +filter{${list}} }" >> ${actionfile}
    echo "*" >> ${actionfile}
    debug "... filterfile added ..." 1

    # create domain based whitelist

    # create domain based blacklist
#    domains=$(sed '/^#/d;/#/!d;s/,~/,\*/g;s/~/;:\*/g;s/^\([a-zA-Z]\)/;:\1/g' ${file})
#    [ -n "${domains}" ] && debug "... creating domainbased filterfiles ..." 1
#    debug "Found Domains: ${domains}." 2
#    ifs=$IFS
#    IFS=";:"
#    for domain in ${domains}
#    do
#      dns=$(echo ${domain} | awk -F ',' '{print $1}' | awk -F '#' '{print $1}')
#      debug "Modifying line: ${domain}" 2
#      debug "   ... creating filterfile for ${dns} ..." 1
#      sed '' ${file} > ${file%\.*}-${dns%~}.script.filter
#      debug "   ... filterfile created ..." 1
#      debug "   ... adding filterfile for ${dns} to actionfile ..." 1
#      echo "{ +filter{${list}-${dns}} }" >> ${actionfile}
#      echo "${dns}" >> ${actionfile}
#      debug "   ... filterfile added ..." 1
#    done
#    IFS=${ifs}
#    debug "... all domainbased filterfiles created ..." 1

    debug "... creating and adding whitlist for urls ..." 1
    # whitelist of urls
    echo "{ -block }" >> ${actionfile}
    sed '/^@@.*/!d;s/^@@//g;/\$.*/d;/#/d;s/\./\\./g;s/\?/\\?/g;s/\*/.*/g;s/(/\\(/g;s/)/\\)/g;s/\[/\\[/g;s/\]/\\]/g;s/\^/[\/\&:\?=_]/g;s/^||/\./g;s/^|/^/g;s/|$/\$/g;/|/d' ${file} >> ${actionfile}
    debug "... created and added whitelist - creating and adding image handler ..." 1
    # whitelist of image urls
    echo "{ -block +handle-as-image }" >> ${actionfile}
    sed '/^@@.*/!d;s/^@@//g;/\$.*image.*/!d;s/\$.*image.*//g;/#/d;s/\./\\./g;s/\?/\\?/g;s/\*/.*/g;s/(/\\(/g;s/)/\\)/g;s/\[/\\[/g;s/\]/\\]/g;s/\^/[\/\&:\?=_]/g;s/^||/\./g;s/^|/^/g;s/|$/\$/g;/|/d' ${file} >> ${actionfile}
    debug "... created and added image handler ..." 1
    debug "... created actionfile for ${list}." 1
  done
}

# loop for options
while getopts ":hrqv:" opt
do
  case "${opt}" in
    "v")
      DBG="${OPTARG}"
      VERBOSE="-v"
      ;;
    "q")
      DBG=-1
      ;;
    "r")
      read -p "Do you really want to remove all build lists?(y/N) " choice
      [ "${choice}" != "y" ] && exit 0
      rm -rf ${PRIVOXY_DIR}/*.script.{action,filter} && \
      sed '/^actionsfile .*\.script\.action$/d;/^filterfile .*\.script\.filter$/d' -i ${PRIVOXY_CONF} && echo "Lists removed." && exit 0
      echo -e "An error occured while removing the lists.\nPlease have a look into ${PRIVOXY_DIR} whether there are .script.* files and search for *.script.* in ${PRIVOXY_CONF}."
      exit 1
      ;;
    ":")
      echo "${TMPNAME}: -${OPTARG} requires an argument" >&2
      exit 1
      ;;
    "h"|*)
      usage
      exit 0
      ;;
  esac
done

debug "URL-List: ${URLS}\nPrivoxy-Configdir: ${PRIVOXY_DIR}\nTemporary directory: ${TMPDIR}" 2
main
