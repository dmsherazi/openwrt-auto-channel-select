#!/bin/ash

# Basic Wi-Fi auto channel selector by PoweredLocal
# (c) 2017 PoweredLocal, Melbourne, Australia
# https://www.poweredlocal.com
#
# Denis Mysenko 20/07/2017

# Modified by Dost M Shah 13/1/2019
# http://dostmuhammad.com 
# 
# checks for ch 4 and 9 as well
# if found networks on 1 , 6 and 11 then will consider 4 and 9 channels as well
# if any of 1 , 6 and 11 have zero networks then 4 and 9 wont be considered
# if the best channel is already being used then wont execute uci command 
# to set the best channel.
#
# No of iterations can be passed as second optional parameter 
# default value is 3



# Config
TEST_INTERVAL=5

# No need to touch anything below, in most cases
if [[ -z $1 ]]; then
  echo "# Basic Wi-Fi auto channel selector by PoweredLocal/DmSherazi"
  echo $0 [interface index] [ITERATIONS]
  exit 1
fi

ITERATIONS=5

if [[ -z $2 ]]; then
  echo "using 3 ITERATIONS by default" 
else
  ITERATIONS=$2
fi

#set up initial values
CHANNEL_1=0
CHANNEL_4=0
CHANNEL_6=0
CHANNEL_9=0
CHANNEL_11=0

INTERFACE_INDEX=$1
SIGNAL=NO

scan() {
 /usr/sbin/iw wlan${INTERFACE_INDEX} scan | grep -E "primary channel|signal" | {
  while read line
  do
    FIRST=`echo "$line" | awk '{ print $1 }'`
    if [[ "$FIRST" == "signal:" ]]; then
      SIGNAL=`echo $line | awk '{ print ($2 < -70) ? "NO" : $2 }'`
      #SIGNAL=`echo $line | awk '{ $2 }'`

    fi

    if [[ "$FIRST" == "*" -a "$SIGNAL" != "NO" ]]; then
      CHANNEL=`echo "$line" | awk '{ print $4 }'`
      eval "CURRENT_VALUE=CHANNEL_$CHANNEL"
      eval "CURRENT_VALUE=$CURRENT_VALUE"
      SUM=$(( $CURRENT_VALUE + 1 ))
      eval "CHANNEL_${CHANNEL}=$SUM"
    fi
  done

  echo $CHANNEL_1 $CHANNEL_4 $CHANNEL_6  $CHANNEL_9  $CHANNEL_11
 }
}

for ITERATION in $(seq 1 1 $ITERATIONS)
do
  [[ -n $DEBUG ]] && echo Iteration $ITERATION
  RESULT=$(scan)
  eval "RESULT_${ITERATION}_1=`echo $RESULT | awk '{ print $1 }'`"
  eval "RESULT_${ITERATION}_4=`echo $RESULT | awk '{ print $2 }'`"
  eval "RESULT_${ITERATION}_6=`echo $RESULT | awk '{ print $3 }'`"
  eval "RESULT_${ITERATION}_9=`echo $RESULT | awk '{ print $4 }'`"
  eval "RESULT_${ITERATION}_11=`echo $RESULT | awk '{ print $5 }'`"

  [[ $ITERATION -lt $ITERATIONS ]] && sleep $TEST_INTERVAL
done

for ITERATION in $(seq 1 1 $ITERATIONS)
do
  for CHANNEL in 1 4 6 9 11
  do
    eval "CURRENT_VALUE=RESULT_${ITERATION}_${CHANNEL}"
    eval "CURRENT_VALUE=$CURRENT_VALUE"
    eval "CURRENT_AVG=AVG_$CHANNEL"
    eval "CURRENT_AVG=$CURRENT_AVG"
    eval "AVG_$CHANNEL=$(( ($CURRENT_AVG + $CURRENT_VALUE + 1) / 2 ))"

    [[ $ITERATION -eq $ITERATIONS -a -n $DEBUG ]] && echo Channel $CHANNEL has an average of $(( ($CURRENT_AVG + $CURRENT_VALUE + 1) / 2 )) networks
  done
done


if [ $AVG_1 -eq 0 ]; then
  CHANNEL=1
elif [ $AVG_6 -eq 0  ]; then
  CHANNEL=6
elif [ $AVG_11 -eq 0 ]; then
  CHANNEL=11
elif [ $AVG_1 -le $AVG_4 -a $AVG_1 -le $AVG_6  -a $AVG_1 -le $AVG_9  -a $AVG_1 -le $AVG_11   ]; then
  CHANNEL=1
elif [ $AVG_4 -le $AVG_1 -a $AVG_4 -le $AVG_6  -a $AVG_4 -le $AVG_9  -a $AVG_4 -le $AVG_11   ]; then
  CHANNEL=4
elif [ $AVG_6 -le $AVG_1 -a $AVG_6 -le $AVG_4  -a $AVG_6 -le $AVG_9  -a $AVG_6 -le $AVG_11   ]; then
  CHANNEL=6
elif [ $AVG_9 -le $AVG_1 -a $AVG_9 -le $AVG_4  -a $AVG_9 -le $AVG_6  -a $AVG_9 -le $AVG_11   ]; then
  CHANNEL=9
elif [ $AVG_11 -le $AVG_1 -a $AVG_11 -le $AVG_4  -a $AVG_11 -le $AVG_6  -a $AVG_11 -le $AVG_9   ]; then
  CHANNEL=11
fi



CUR_CH=$( uci get wireless.radio1.channel )

if [[ -n "$CHANNEL" ]]; then

  if [[ $CHANNEL -eq $CUR_CH ]]; then
    #statements
    echo Channel Already set to $CHANNEL
  else 
  echo Setting channel to $CHANNEL
  /sbin/uci set wireless.radio${INTERFACE_INDEX}.channel="$CHANNEL"
  /sbin/uci commit
  fi
fi
