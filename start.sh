#!/usr/bin/env bash

VPNGATE_URL=https://www.vpngate.net/api/iphone/

DEFAULT_GW=$(ip route | awk '/^default/ {
  print $3
  exit
}')

function health_check {
  hash=$(uuidgen -r)
  curl -s https://ppng.io/$hash
}

# vpn connect func
function connect {
  while :; do 
    echo start
    while read line; do 
      ip=$(echo $line | cut -d ',' -f 2)
      ip route add $ip/32 via $DEFAULT_GW
      line=$(echo $line | cut -d ',' -f 15)
      line=$(echo $line | tr -d '\r')
      openvpn <(echo "$line" | base64 -d) | tee >(awk '/Initialization Sequence Completed/ {
        exit 1
      }' || pkill sleep)
    done < <(curl -s $VPNGATE_URL | grep ,Japan,JP, | grep -v public-vpn- | sort -R )
    echo end
  done
}

# kill switch
while read ip; do
  ip route add $ip/32 via $DEFAULT_GW
  echo $(date +'%F %T') /sbin/ip route add $ip/32 via $DEFAULT_GW
done < <(awk '/^nameserver|^Address: / && $NF~/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
  print $NF
}' <(cat /etc/resolv.conf ; nslookup www.vpngate.net) )
ip route del default

# start proxy
privoxy <(grep -v ^listen-address /etc/privoxy/config ; echo listen-address  0.0.0.0:8118) &

# connect vpn
connect &

# vpn check
while :; do
  sleep 5
  result=$?
  if [ $result -ne 0 ]; then
    health_check
  fi
  pkill openvpn
done
