#!/bin/bash

#Docker Multi Daemon

# DEFAULTS

DOCKER_ROOTDIR="${DOCKER_ROOTDIR:=/var/lib/docker}"
DOCKER_RUNDIR="${DOCKER_RUNDIR:=/var/run}"
DOCKER_CONFIGDIR="${DOCKER_CONFIGDIR:=/etc/docker}"
DOCKER_LOGDIR="${DOCKER_LOGDIR:=/var/log/docker}"

# SUBNET
SUBNET="172.18"
MASK="24"

# DNS
DOCKER_DNS="8.8.8.8"

# ENGINE NAMES
ENGINE_NAMES[0]="infra"
ENGINE_NAMES[1]="service"


ErrorMessage(){

  echo "$(date +%Y/%m/%d-%H:%M:%S) ERROR: $*"
  exit 1
}

# Check for bridge-utils
# Ubuntu/debian
if ! dpkg -l bridge-utils >/dev/null 2>&1
then
  apt-get install -qq bridge-utils >/dev/null 2>&1
  [ $? -ne 0 ] && ErrorMessage "Can not install 'bridge-utils', exiting..."
fi


COUNT=0
for ENGINE in ${ENGINE_NAMES[@]}
do
  echo "Docker Daemon '${ENGINE}' Configuration:"
  ENGINE_BRIDGE="br_${ENGINE}"
  ENGINE_SUBNET="${SUBNET}.${COUNT}.0/${MASK}"
  ENGINE_LABEL="docker-${ENGINE}-daemon"


  brctl addbr ${ENGINE_BRIDGE}
  ip addr add ${ENGINE_SUBNET} dev ${ENGINE_BRIDGE}
  ip link set dev ${ENGINE_BRIDGE} up

  if ! iptables -t nat -C POSTROUTING -j MASQUERADE -s ${ENGINE_SUBNET} -d 0.0.0.0/0
  then
    echo "Adding POSTROUTING NAT Iptables Rules"
    iptables -t nat -A POSTROUTING -j MASQUERADE -s ${ENGINE_SUBNET} -d 0.0.0.0/0
    echo "iptables -t nat -A POSTROUTING -j MASQUERADE -s ${ENGINE_SUBNET} -d 0.0.0.0/0"
  fi

  #Docker Daemon Working Dir
  ENGINE_ROOTDIR=${DOCKER_ROOTDIR}-${ENGINE}
  mkdir -p ${ENGINE_ROOTDIR}

  #Docker Daemon Configuration Dir
  ENGINE_CONFIGDIR=${DOCKER_CONFIGDIR}-${ENGINE}
  mkdir -p ${ENGINE_CONFIGDIR}
  if [ -f ${ENGINE_CONFIGDIR}/daemon.json ]
  then
    ENGINE_CONFIG="--config-file=${ENGINE_CONFIGDIR}/daemon.json"
  fi
  #Docker Daemon Logging Dir
  ENGINE_LOGDIR=${DOCKER_LOGDIR}-${ENGINE}
  mkdir -p ${ENGINE_LOGDIR}

  nohup docker daemon -D \
    -g ${ENGINE_ROOTDIR}/g \
    --exec-root=${ENGINE_ROOTDIR}/e \
    -b ${ENGINE_BRIDGE} \
    --dns=${DOCKER_DNS} \
    --iptables=false \
    ${ENGINE_CONFIG} \
    -H unix://${DOCKER_RUNDIR}/docker-${ENGINE}.sock \
    -p ${DOCKER_RUNDIR}/docker-${ENGINE}.pid > ${ENGINE_LOGDIR}/docker.log 2>&1 </dev/null &

    COUNT=$(($COUNT+1))
done
