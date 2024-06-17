#!/bin/bash

MODEM_PATH=/oran/5gs/OAI-5G/cmake_targets/ran_build/build/nr-uesoftmodem
UE_CONFIG_PATH=/oran/5gs/OAI-5G-Docker/nr-rfsim/nr-ues

# Check if a number of namespaces is provided as an argument
if [ $# -eq 0 ]; then
  echo "Usage: $0 <number_of_namespaces>"
  exit 1
fi

# Get the number of namespaces from the argument
num_namespaces=$1
BASE_IP=200

# Construct namespace name (e.g., ue1, ue2, ue3)
for i in $(seq 1 $num_namespaces); do
  name="ue$i"
  ue_id=$i
  echo "creating namespace for UE ID ${ue_id} name ${name}"
  ip netns add $name
  ip link add v-eth$ue_id type veth peer name v-ue$ue_id
  ip link set v-ue$ue_id netns $name
  BASE_IP=$((200+ue_id))
  ip addr add 10.$BASE_IP.1.100/24 dev v-eth$ue_id
  ip link set v-eth$ue_id up
  iptables -t nat -A POSTROUTING -s 10.$BASE_IP.1.0/255.255.255.0 -o lo -j MASQUERADE
  iptables -A FORWARD -i lo -o v-eth$ue_id -j ACCEPT
  iptables -A FORWARD -o lo -i v-eth$ue_id -j ACCEPT
  ip netns exec $name ip link set dev lo up
  ip netns exec $name ip addr add 10.$BASE_IP.1.$ue_id/24 dev v-ue$ue_id
  ip netns exec $name ip link set v-ue$ue_id up
done

#open namespaces and execute the UE
BASE_IP=200
for i in $(seq 1 $num_namespaces); do
  namespace="ue$i"
  ip_address="10.$((BASE_IP + i)).1.100"
  server_addr="$ip_address"
  inner_command="$MODEM_PATH \
      -E \
      -r 106 \
      --numerology 1 \
      --band 78 \
      -C 3619200000 \
      -O $UE_CONFIG_PATH/nrue$i.uicc.conf \
      --rfsimulator.serveraddr \
      $server_addr \
      --sa \
      --rfsim"
  echo "Executing nohup ip netns exec "$namespace" bash -c "$inner_command" > "ue$i.log" 2>&1 &"
  nohup ip netns exec "$namespace" bash -c "$inner_command" > "ue$i.log" 2>&1 &
done
