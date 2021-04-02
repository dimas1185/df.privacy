#!/bin/bash
EOSIO_CONTRACTS_DIRECTORY="$HOME/Work/eosio.contracts/build/contracts"
EOSIO_PRIVACY_CONTRACT_DIR="$HOME/Work/eosio.templates/build/templates"
#EOSIO_CONTRACTS_DIRECTORY="$HOME/Downloads/build/contracts"
EOS_TEST_CONTRACTS="$HOME/Work/eos/unittests/test-contracts"
NUMBER_OF_NODES=10
NUMBER_OF_PRODUCERS=8
CHAINBASE_PRODS=$NUMBER_OF_PRODUCERS
IDLE_TIME=120
#producer nuber used for boost bios sequence
GEN_PROD_NUM=1
#producer number to provide command line arguments that can be used to start it in debugger
DEBUG_PROD_NUM=-1
EOS_PATH=$HOME/Work/eos/build
OLD_EOS_PATH=$HOME/Work/eos_copy/build
#1bln
ISSUE_AMT=1000000000

function backing_store {
   if [ $1 -le $CHAINBASE_PRODS ]
   then
      echo "chainbase"
   else
      echo "rocksdb"
   fi
}

function producer_name {
   if [ $1 -le 5 ]
   then
      NAME="prod.$1"
   else
      CNT=$1
      NAME="prod.5"
      while [ $CNT -gt 5 ]
      do
         CNT=$(( $CNT - 5 ))
         if [ $CNT -gt 5 ]
         then
            NAME="${NAME}.5"
         else
            NAME="${NAME}.${CNT}"
         fi
      done
   fi

   echo $NAME
}

function normalized-name {
   if [ $2 -le 5 ]
   then
      NAME=$(sed "s/{NUMBER}/$2/" <<< "$1")
   else
      CNT=$2
      NUM="5"
      while [ $CNT -gt 5 ]
      do
         CNT=$(( $CNT - 5 ))
         if [ $CNT -gt 5 ]
         then
            NUM="${NUM}.5"
         else
            NUM="${NUM}.${CNT}"
         fi
      done
      NAME=$(sed "s/{NUMBER}/$NUM/" <<< "$1")
   fi

   echo $NAME
}

function get_priv_key {
   cat $1 | sed -n -e 's/Private key: //p'
}

function get_pub_key {
   cat $1 | sed -n -e 's/Public key: //p'
}

function activate_feature {
   curl --request POST \
      --url http://127.0.0.1:$1/v1/producer/schedule_protocol_feature_activations \
      -d "{\"protocol_features_to_activate\": [\"$2\"]}" | python -m json.tool
}

function send_trx {
   curl --request POST \
        --url http://127.0.0.1:$1/v1/chain/send_transaction \
        -d ''"$2"'' | python -m json.tool
}

function peers_cl {
   PARAM_PREF=""
   PARAM_SUF=""
   if [ $4 == 1 ]
   then
      #params will be generated for VS Code
      PARAM_PREF=\"
      PARAM_SUF=\",
   fi
   BASE_PORT=$3
   for i in $(seq 1 $2)
   do
      if [ $i -ne $1 ]
      then
         PORT=$(( $BASE_PORT + $i ))
         echo "${PARAM_PREF}--p2p-peer-address${PARAM_SUF} ${PARAM_PREF}0.0.0.0:${PORT}${PARAM_SUF} "
      fi
   done
}

function prods-cl {
   PARAM_PREF=""
   PARAM_SUF=""
   if [ $3 == 1 ]
   then
      #params will be generated for VS Code
      PARAM_PREF=\"
      PARAM_SUF=\",
   fi

   if [ $(is-producer $1) ]
   then
      echo "${PARAM_PREF}-e${PARAM_SUF} ${PARAM_PREF}-p${PARAM_SUF} ${PARAM_PREF}$2${PARAM_SUF}"
   else
      echo ""
   fi
}

function old_nodeos {
   echo ""
   # if [ $1 -le $(( $NUMBER_OF_PRODUCERS / 2 )) ]
   # then
   #    echo 1
   # fi
}

function nodeos_path {
   if [ $(old_nodeos $1) ]
   then
      echo "$OLD_EOS_PATH/bin/nodeos"
   else
      echo "$EOS_PATH/bin/nodeos"
   fi
}

function chain_id {
   cleos get info | sed -n 's/[[:space:]]*\"chain_id\":[[:space:]]*\"\(.*\)\",[[:space:]]*/\1/p'
}

function is-producer {
   [ $1 -le $NUMBER_OF_PRODUCERS ] && echo 1
}

function cleanup {
   pkill nodeos
   rm -rf ./data* ./protocol_features* ./*.keys ./gen_conf* ./*trx.json

   pkill keosd
   rm -rf ~/eosio-wallet/df*
}
cleanup

trap "cleanup" EXIT

keosd > keosd.log 2>&1 &

cleos wallet create -n df -f ./wallet.keys
WALLET_PASSWORD=$(cat ./wallet.keys)

#eosio private key
cleos wallet import -n df --private-key 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3

declare -a PRIV_KEYS=()
declare -a PUB_KEYS=()

for i in $(seq 1 $NUMBER_OF_NODES)
do
   echo "creating keys for producer number $i"
   cleos create key -f "./eosio.prods${i}.keys"
   PRIV_KEYS[$i]=$(get_priv_key ./eosio.prods${i}.keys)
   PUB_KEYS[$i]=$(get_pub_key ./eosio.prods${i}.keys)
   cleos wallet import -n df --private-key ${PRIV_KEYS[$i]}
done

cleos create key -f ./eosio.bpay.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.bpay.keys)
cleos create key -f ./eosio.msig.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.msig.keys)
cleos create key -f ./eosio.names.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.names.keys)
cleos create key -f ./eosio.ram.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.ram.keys)
cleos create key -f ./eosio.ramfee.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.ramfee.keys)
cleos create key -f ./eosio.saving.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.saving.keys)
cleos create key -f ./eosio.stake.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.stake.keys)
cleos create key -f ./eosio.token.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.token.keys)
cleos create key -f ./eosio.vpay.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.vpay.keys)
cleos create key -f ./eosio.rex.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.rex.keys)
cleos create key -f ./eosio.secgrp.keys
cleos wallet import -n df --private-key $(get_priv_key ./eosio.secgrp.keys)

cleos wallet open -n df
cleos wallet unlock -n df --password $WALLET_PASSWORD

#generate genesis. starting from 1st as it is 2.1 nodeos
echo "generating genesis..."
cat ./genesis_template.json | sed -e "s/REPLACE_WITH_PRIVATE_KEY/${PUB_KEYS[${GEN_PROD_NUM}]}/g" > ./genesis.json

echo "generating config..."
for i in $(seq 1 $NUMBER_OF_NODES)
do
   mkdir -p ./gen_conf${i}
   mkdir -p ./conf${i}
   echo "generating genesis config for producer number $i with backing-store $(backing_store $i)"
   cat ./genesis_config_template.ini | sed -e "s/PUB_KEY/${PUB_KEYS[$i]}/g" | sed -e "s/PRIV_KEY/${PRIV_KEYS[$i]}/g" | sed -e "s/BK_STORE/$(backing_store $i)/g" > ./gen_conf${i}/config.ini
   if [ $(old_nodeos $i) ]
   then
      cat ./gen_conf${i}/config.ini | sed -e "s/backing-store/#backing-store/g" > ./gen_conf${i}/config2.ini
      cp ./gen_conf${i}/config2.ini ./gen_conf${i}/config.ini
   fi
   cat ./config_template.ini | sed -e "s/PUB_KEY/${PUB_KEYS[$i]}/g" | sed -e "s/PRIV_KEY/${PRIV_KEYS[$i]}/g" | sed -e "s/BK_STORE/$(backing_store $i)/g" > ./conf${i}/config.ini
   if [ $(old_nodeos $i) ]
   then
      cat ./conf${i}/config.ini | sed -e "s/backing-store/#backing-store/g" > ./conf${i}/config2.ini
      cp ./conf${i}/config2.ini ./conf${i}/config.ini
   fi
done


echo "creating new blockchain from genesis..."
for i in $(seq 1 $NUMBER_OF_NODES)
do
   echo "producer $i"
   echo "using nodeos: $(nodeos_path $i)"
   $(nodeos_path $i) --genesis-json ./genesis.json \
          --data-dir ./data${i}     \
          --protocol-features-dir ./protocol_features${i} \
          --config-dir ./gen_conf${i} \
          > nodeos_${i}.log 2>&1 &
done
sleep 3
pkill nodeos

#generating certificates
printf "$(cd $EOS_PATH/tests; ./generate-certificates.sh -d 365 -s $NUMBER_OF_NODES)\n"

echo "starting eosio on 1st producer"
echo "using nodeos: $(nodeos_path $GEN_PROD_NUM)"
$(nodeos_path $GEN_PROD_NUM) -e -p eosio \
  --data-dir ./data${GEN_PROD_NUM}     \
  --protocol-features-dir ./protocol_features${GEN_PROD_NUM} \
  --config-dir ./conf${GEN_PROD_NUM} \
  --contracts-console   \
  --disable-replay-opts \
  --http-server-address 0.0.0.0:8888 \
  --p2p-listen-endpoint 0.0.0.0:9876 \
  --state-history-endpoint 0.0.0.0:8788 \
  --max-transaction-time 1000 \
  --p2p-tls-security-group-ca-file "$EOS_PATH/tests/CA_cert.pem" \
  --p2p-tls-own-certificate-file "$EOS_PATH/tests/$(normalized-name node{NUMBER} $i).crt" \
  --p2p-tls-private-key-file "$EOS_PATH/tests/$(normalized-name node{NUMBER}_key $i).pem" \
  -l ./logging.json \
  > nodeos_${GEN_PROD_NUM}.log 2>&1 &
sleep 3

echo "creating system accounts..."
cleos create account eosio eosio.bpay $(get_pub_key eosio.bpay.keys) #-p eosio@active
cleos create account eosio eosio.msig $(get_pub_key eosio.msig.keys) #-p eosio@active
cleos create account eosio eosio.names $(get_pub_key eosio.names.keys) #-p eosio@active
cleos create account eosio eosio.ram $(get_pub_key eosio.ram.keys) #-p eosio@active
cleos create account eosio eosio.ramfee $(get_pub_key eosio.ramfee.keys) #-p eosio@active
cleos create account eosio eosio.saving $(get_pub_key eosio.saving.keys) #-p eosio@active
cleos create account eosio eosio.stake $(get_pub_key eosio.stake.keys) #-p eosio@active
cleos create account eosio eosio.token $(get_pub_key eosio.token.keys) #-p eosio@active
cleos create account eosio eosio.vpay $(get_pub_key eosio.vpay.keys) #-p eosio@active
cleos create account eosio eosio.rex $(get_pub_key eosio.rex.keys) #-p eosio@active
cleos create account eosio eosio.secgrp $(get_pub_key eosio.secgrp.keys) #-p eosio@active

#PREACTIVATE_FEATURE
activate_feature 8888 "0ec7e080177b2c02b278d5088611686b49d739925a92d9bfcacd7fc6b74053bd"

sleep 3

cleos set contract eosio $EOSIO_CONTRACTS_DIRECTORY/eosio.boot/

sleep 5

#KV_DATABASE
cleos push action eosio activate '["825ee6288fb1373eab1b5187ec2f04f6eacb39cb3a97f356a07c91622dd61d16"]' -p eosio@active
#WTMSIG_BLOCK_SIGNATURES
cleos push action eosio activate '["299dcb6af692324b899b39f16d5a530a33062804e41f09dc97e9f156b4476707"]' -p eosio@active
#ACTION_RETURN_VALUE
cleos push action eosio activate '["c3a6138c5061cf291310887c0b5c71fcaffeab90d5deb50d3b9e687cead45071"]' -p eosio@active
#PRIVACY
cleos push action eosio activate '["ded2e25adcd78cbb94fa7f63a8f80a9af2b1a905e551a6e124e7d7829da1ea02"]' -p eosio@active
sleep 5

cleos set contract eosio $EOSIO_CONTRACTS_DIRECTORY/eosio.system/
sleep 3
cleos set contract eosio.msig $EOSIO_CONTRACTS_DIRECTORY/eosio.msig/
sleep 3
cleos set contract eosio.token $EOSIO_CONTRACTS_DIRECTORY/eosio.token/
sleep 3
cleos set contract eosio.secgrp $EOSIO_PRIVACY_CONTRACT_DIR/eosio.secgrp/
sleep 3

cleos push action eosio.token create "[ \"eosio\", \"$(($ISSUE_AMT * 2)).0000 SYS\" ]" -p eosio.token
cleos push action eosio.token issue "[ \"eosio\", \"${ISSUE_AMT}.0000 SYS\", \"memo\" ]" -p eosio
cleos push action eosio init '["0", "4,SYS"]' -p eosio@active

cleos push action eosio setpriv '["eosio.msig", 1]' -p eosio
cleos push action eosio setpriv '["eosio.secgrp", 1]' -p eosio
sleep 3


for i in $(seq 1 $NUMBER_OF_PRODUCERS)
do
   PROD_NAME=$(producer_name $i)
   
   #100mm
   STAKE_AMT=$(( $ISSUE_AMT / $NUMBER_OF_PRODUCERS / 4 ))
   echo "$PROD_NAME stake amount = $STAKE_AMT"
   cleos system newaccount eosio --transfer $PROD_NAME ${PUB_KEYS[$i]} --stake-net "${STAKE_AMT}.0000 SYS" --stake-cpu "${STAKE_AMT}.0000 SYS" --buy-ram-kbytes 8192
   cleos system regproducer $PROD_NAME ${PUB_KEYS[$i]} https://dimon${i}.io 840 -p $PROD_NAME
   cleos system voteproducer prods $PROD_NAME $PROD_NAME -p $PROD_NAME
done

cleos transfer eosio prod.1 "1000.0000 SYS" -p eosio
cleos transfer eosio prod.2 "1000.0000 SYS" -p eosio

cleos system listproducers

#resign eosio and other system accounts
cleos push action eosio updateauth '{"account": "eosio", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio.prods", "permission": "active"}}]}}' -p eosio@owner
cleos push action eosio updateauth '{"account": "eosio", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio.prods", "permission": "active"}}]}}' -p eosio@active

cleos push action eosio updateauth '{"account": "eosio.bpay", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.bpay@owner
cleos push action eosio updateauth '{"account": "eosio.bpay", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.bpay@active

cleos push action eosio updateauth '{"account": "eosio.msig", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.msig@owner
cleos push action eosio updateauth '{"account": "eosio.msig", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.msig@active

cleos push action eosio updateauth '{"account": "eosio.names", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.names@owner
cleos push action eosio updateauth '{"account": "eosio.names", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.names@active

cleos push action eosio updateauth '{"account": "eosio.ram", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.ram@owner
cleos push action eosio updateauth '{"account": "eosio.ram", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.ram@active

cleos push action eosio updateauth '{"account": "eosio.ramfee", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.ramfee@owner
cleos push action eosio updateauth '{"account": "eosio.ramfee", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.ramfee@active

cleos push action eosio updateauth '{"account": "eosio.saving", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.saving@owner
cleos push action eosio updateauth '{"account": "eosio.saving", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.saving@active

cleos push action eosio updateauth '{"account": "eosio.stake", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.stake@owner
cleos push action eosio updateauth '{"account": "eosio.stake", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.stake@active

cleos push action eosio updateauth '{"account": "eosio.token", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.token@owner
cleos push action eosio updateauth '{"account": "eosio.token", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.token@active

cleos push action eosio updateauth '{"account": "eosio.vpay", "permission": "owner", "parent": "", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.vpay@owner
cleos push action eosio updateauth '{"account": "eosio.vpay", "permission": "active", "parent": "owner", "auth": {"threshold": 1, "keys": [], "waits": [], "accounts": [{"weight": 1, "permission": {"actor": "eosio", "permission": "active"}}]}}' -p eosio.vpay@active

sleep 3



pkill nodeos

T=$(( $NUMBER_OF_PRODUCERS * 2 / 3 ))
G=$(( 12 * $T - 3 ))
WAIT_LIB=$(( 3 * $G + 24 ))

for i in $(seq 1 $NUMBER_OF_NODES)
do
   if [ $DEBUG_PROD_NUM == $i ]
   then
      DEBUG_PARAMS=1
   else
      DEBUG_PARAMS=0
   fi

   if [ $(is-producer $i) ]
   then
      PROD_NAME=$(producer_name $i)
      echo "starting producer $PROD_NAME"
      PROD_CL=$(prods-cl $i $PROD_NAME $DEBUG_PARAMS)
   else
      echo "starting non-producer $i"
      PROD_CL=""
   fi

   HTTP_PORT=$(( 8887 + $i ))
   LISTEN_ENDPOINT=$(( 9875 + $i ))
   PEERS_CL=$(peers_cl $i $NUMBER_OF_NODES 9875 $DEBUG_PARAMS)
   SH_PORT=$(( 8787 + $i ))

   echo "listen endpoint: $LISTEN_ENDPOINT"
   echo "peers to connect PEERS_CL: ${PEERS_CL}"

   if [ $DEBUG_PARAMS == 1 ]
   then
      echo "start debug nodeos with the following parameters:"
      echo "$PROD_CL
           \"--data-dir\", \"$(pwd)/data${i}\",
           \"--protocol-features-dir\", \"$(pwd)/protocol_features${i}\",
           \"--config-dir\", \"$(pwd)/conf${i}\",
           \"--contracts-console\",
           \"--disable-replay-opts\",
           \"--http-server-address\", \"0.0.0.0:$HTTP_PORT\",
           \"--p2p-listen-endpoint\", \"0.0.0.0:$LISTEN_ENDPOINT\",
           $PEERS_CL
           \"--state-history-endpoint\", \"0.0.0.0:$SH_PORT\",
           \"--p2p-tls-security-group-ca-file\", \"$EOS_PATH/tests/CA_cert.pem\",
           \"--p2p-tls-own-certificate-file\", \"$EOS_PATH/tests/$(normalized-name node{NUMBER} $i).crt\",
           \"--p2p-tls-private-key-file\", \"$EOS_PATH/tests/$(normalized-name node{NUMBER}_key $i).pem\",
           \"--max-transaction-time\", \"1000\",
           \"-l\", \"$(pwd)/logging.json\""
      
      read
      continue
   elif [ $i == $NUMBER_OF_NODES ]
   then
      DELAY_START=$(($WAIT_LIB * 4))
      echo "starting nodeos with delay of $DELAY_START"
      sleep $DELAY_START && $(nodeos_path $i) $PROD_CL \
         --data-dir ./data${i}     \
         --protocol-features-dir ./protocol_features${i} \
         --config-dir ./conf${i} \
         --contracts-console   \
         --disable-replay-opts \
         --http-server-address 0.0.0.0:$HTTP_PORT \
         --p2p-listen-endpoint 0.0.0.0:$LISTEN_ENDPOINT \
         $PEERS_CL \
         --state-history-endpoint 0.0.0.0:$SH_PORT \
         --p2p-tls-security-group-ca-file "$EOS_PATH/tests/CA_cert.pem" \
         --p2p-tls-own-certificate-file "$EOS_PATH/tests/$(normalized-name node{NUMBER} $i).crt" \
         --p2p-tls-private-key-file "$EOS_PATH/tests/$(normalized-name node{NUMBER}_key $i).pem" \
         --max-transaction-time 1000 \
         -l ./logging.json \
         >> nodeos_${i}.log 2>&1 &
      continue
   fi
   echo "using nodeos: $(nodeos_path $i)"
   $(nodeos_path $i) $PROD_CL \
         --data-dir ./data${i}     \
         --protocol-features-dir ./protocol_features${i} \
         --config-dir ./conf${i} \
         --contracts-console   \
         --disable-replay-opts \
         --http-server-address 0.0.0.0:$HTTP_PORT \
         --p2p-listen-endpoint 0.0.0.0:$LISTEN_ENDPOINT \
         $PEERS_CL \
         --state-history-endpoint 0.0.0.0:$SH_PORT \
         --p2p-tls-security-group-ca-file "$EOS_PATH/tests/CA_cert.pem" \
         --p2p-tls-own-certificate-file "$EOS_PATH/tests/$(normalized-name node{NUMBER} $i).crt" \
         --p2p-tls-private-key-file "$EOS_PATH/tests/$(normalized-name node{NUMBER}_key $i).pem" \
         --max-transaction-time 1000 \
         -l ./logging.json \
         >> nodeos_${i}.log 2>&1 &
done


echo "waiting for $WAIT_LIB seconds till LIB starts to move"
sleep $WAIT_LIB

cleos push action eosio.secgrp add '[["node1", "node2"]]' -p eosio.secgrp@active
cleos push action eosio.secgrp publish '["0"]' -p eosio.secgrp@active
sleep 1
cleos get info

ELAPSED=0
while [ $ELAPSED -lt 100 ]
do
   sleep $(( $IDLE_TIME / 100 ))
   ELAPSED=$(( $ELAPSED + 1 ))
   echo -en "\rruning idle blockchain for $IDLE_TIME seconds $(( $ELAPSED ))%..."
done
echo ""

cleos get info
cleos push action eosio.secgrp add '[["node4"]]' -p eosio.secgrp@active
cleos push action eosio.secgrp publish '["0"]' -p eosio.secgrp@active
sleep $IDLE_TIME
cleos get info


pkill nodeos

echo "forks:"
grep "fork or replay" ./nodeos*
echo "errors:"
grep "error" ./nodeos* | grep -v "connection failed" | grep -v "Closing connection"