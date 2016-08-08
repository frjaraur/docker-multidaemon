#!/bin/bash -x

MGMTIP=$1

SERVICEIP=$2

SWARMROLE=$3

#SHARED Between Nodes..
TMPSHARED="/tmp_deploying_stage"
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
ENGINE_NAMES[0]="mgmt"
ENGINE_NAMES[1]="service"

# Not Cool :\
ENGINE_IPS[0]=$MGMTIP
ENGINE_IPS[1]=$SERVICEIP

ErrorMessage(){
  echo "$(date +%Y/%m/%d-%H:%M:%S) ERROR: $*"
  exit 1
}

InfoMessage(){
  echo "$(date +%Y/%m/%d-%H:%M:%S) INFO: $*"
}


if ! dpkg -l docker >/dev/null 2>&1
then
  #Install Engine (This way, we can reprovision)
  InfoMessage "Installing Docker"
  apt-get install -qq curl \
  && curl -sSL https://get.docker.com/ | sh \
  && curl -fsSL https://get.docker.com/gpg | sudo apt-key add - \
  && usermod -aG docker vagrant \
  && service docker stop && update-rc.d docker disable
fi

# Check for bridge-utils
# Ubuntu/debian
if ! dpkg -l bridge-utils >/dev/null 2>&1
then
  InfoMessage "Installing Bridge-Utils"
  apt-get install -qq bridge-utils >/dev/null 2>&1
  [ $? -ne 0 ] && ErrorMessage "Can not install 'bridge-utils', exiting..."
fi


COUNT=0
for ENGINE in ${ENGINE_NAMES[@]}
do
  echo "Docker Daemon '${ENGINE}' Configuration:"
  ENGINE_BRIDGE="br_${ENGINE}"
  ENGINE_SUBNET="${SUBNET}.${COUNT}.0/${MASK}"
  ENGINE_LABEL="engine_type=${ENGINE}-daemon"


  brctl addbr ${ENGINE_BRIDGE}
  ip addr add ${ENGINE_SUBNET} dev ${ENGINE_BRIDGE}
  ip link set dev ${ENGINE_BRIDGE} up

  if ! iptables -t nat -C POSTROUTING -j MASQUERADE -s ${ENGINE_SUBNET} -d 0.0.0.0/0 2>/dev/null
  then
    echo "Adding POSTROUTING NAT Iptables Rules"
    iptables -t nat -A POSTROUTING -j MASQUERADE -s ${ENGINE_SUBNET} -d 0.0.0.0/0
    echo "iptables -t nat -A POSTROUTING -j MASQUERADE -s ${ENGINE_SUBNET} -d 0.0.0.0/0"
  fi

  #Docker Daemon Working Dir
  ENGINE_ROOTDIR=${DOCKER_ROOTDIR}-${ENGINE}
  mkdir -p ${ENGINE_ROOTDIR}

  #Docker Daemon Execution State Files Dir
  ENGINE_EXECDIR=${DOCKER_RUNDIR}-${ENGINE}
  mkdir -p ${ENGINE_EXECDIR}

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

  [ ! -f ${DOCKER_RUNDIR}/docker-${ENGINE}.sock ] \
  && nohup docker daemon -D \
    -g ${ENGINE_ROOTDIR} \
    --exec-root=${ENGINE_EXECDIR} \
    -b ${ENGINE_BRIDGE} \
    --dns=${DOCKER_DNS} \
    --iptables=false \
    ${ENGINE_CONFIG} \
    --label=${ENGINE_LABEL} \
    -H unix://${DOCKER_RUNDIR}/docker-${ENGINE}.sock -H tcp://${ENGINE_IPS[$COUNT]}:2375 \
    -p ${DOCKER_RUNDIR}/docker-${ENGINE}.pid > ${ENGINE_LOGDIR}/docker.log 2>&1 </dev/null &


    sleep 10 # Wait 10 seconds for daemons...
    #SWARM
    InfoMessage "SWARM MODE ROLE [${SWARMROLE}]"
    case ${SWARMROLE} in
      manager)
        [ ! -f ${TMPSHARED}/${ENGINE}.manager.token ] && InfoMessage "Initiating Swarm Cluster [${ENGINE}]" \
        && docker -H ${ENGINE_IPS[$COUNT]}:2375 swarm init --advertise-addr ${ENGINE_IPS[$COUNT]}:2375 --listen-addr ${ENGINE_IPS[$COUNT]}:3375 \
        && docker -H ${ENGINE_IPS[$COUNT]}:2375 swarm join-token manager -q > ${TMPSHARED}/${ENGINE}.manager.token \
        && docker -H ${ENGINE_IPS[$COUNT]}:2375 swarm join-token worker -q > ${TMPSHARED}/${ENGINE}.worker.token \
        && continue

        [ -f ${TMPSHARED}/${ENGINE}.manager.token ] && InfoMessage "Joining Swarm Cluster [${ENGINE}]" \
        && docker swarm join  --advertise-addr ${ENGINE_IPS[$COUNT]}:2375 --listen-addr ${ENGINE_IPS[$COUNT]}:3375 \
        --token $(cat ${TMPSHARED}/${ENGINE}.manager.token)
      ;;

      worker)
        docker swarm join  --advertise-addr ${ENGINE_IPS[$COUNT]}:2375 --listen-addr ${ENGINE_IPS[$COUNT]}:3375 \
        --token $(cat ${TMPSHARED}/${ENGINE}.worker.token)

      ;;

    esac


    COUNT=$(($COUNT+1))
done
