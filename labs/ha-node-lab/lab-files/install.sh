#!/usr/bin/env bash

#Placeholder for variables
#Filenames should you need to update
SQL_FILENAME="sqljdbc_6.4.0.0_enu.tar.gz"
SQL_FOLDERNAME="sqljdbc_6.4"
SQL_DRIVERNAME="mssql-jdbc-6.4.0.jre8.jar"
ZOOKEEP_FILENAME="apache-zookeeper-3.6.3-bin.tar.gz"
ZOOKEEP_FOLDERNAME="apache-zookeeper-3.6.3-bin"
ARTEMIS_FILENAME="apache-artemis-2.6.2-bin.tar.gz"
ARTEMIS_FOLDERNAME="apache-artemis-2.6.2"
CORDA_UTILITIES="corda-tools-ha-utilities-4.8.jar"
CORDA_FIREWALL="corda-firewall-4.8.jar"
CORDA_HEALTH_SURVEY="corda-tools-health-survey-4.8.jar"
CORDA_BOOTSTRAP="corda-tools-network-bootstrapper-4.8.jar"

#IP and Port for the various appliances
P2P_IPPORT="<Load Balancer URL for Party A and C>:10005"
FLOAT_IPPORT="<vmInfra1 Private IP>:12005"
FLOATLST_IPPORT="<vmInfra1 Private IP>:10005"
FLOATPRIME_IPPORT="<vmInfra2 Private IP>:12005"
FLOATPRIMELST_IPPORT="<vmInfra2 Private IP>:10005"
ZOO1_IPPORT="<vmInfra1 Private IP>:11105"
ZOO2_IPPORT="<vmInfra2 Private IP>:11105"
ZOO3_IPPORT="<vmInfra3 Private IP>:11105"
ARTEMISMASTER_IPPORT="<vmInfra1 Private IP>:11005"
ARTEMISSLAVE_IPPORT="<vmInfra2 Private IP>:11005"
#(OPTIONAL)
PARTYBP2P_IPPORT="<Party B P2P URL>:10008"

#Identities used and network services
PARTYA_IDENTITY="<Party A X500 Identity>"
PARTYC_IDENTITY="<Party C X500 Identity>"
SQL_DATABASE_HOST="<SQL Database Host>"
PARTYA_DATABASE_NAME="<PartyA Database Name>"
PARTYC_DATABASE_NAME="<PartyC Database Name>"
DOORMAN_URL="<Doorman URL and PORT>"
NETWORK_MAP_URL="<Network Map URL and PORT>"

#JKS Keystore passwords should you want to change, you would need to update the corresponding config files
ARTEMIS_STOREPASS="artemisStorePass"
ARTEMIS_TRUSTPASS="artemisTrustpass"
TUNNEL_SSLPASS="tunnelStorePass"
TUNNEL_PRIVATEPASS="tunnelTrustpass"
BRIDGE_SSLPASS="bridgeKeyStorePassword"
PARTYA_STOREPASS="cordacadevpass"
PARTYA_TRUSTPASS="trustpass"
PARTYC_STOREPASS="cordacadevpass"
PARTYC_TRUSTPASS="trustpass"

HOME_LAB="$HOME/Lab2"
PARSED_DOORMAN_URL=$(echo $DOORMAN_URL | sed 's;/;\\/;g')
PARSED_NETMAP_URL=$(echo $NETWORK_MAP_URL | sed 's;/;\\/;g')

#Supporting functions
msg () {
     printf ' \e[0m%-6s\e[m \n' " ${1} "
}
#Placeholder for messages
message() {
	msg "=========================================================================="
	msg ""
	msg "++++++++Created by Ben Tan August 2019 for learning purposes only+++++++++"
	msg "Welcome to this Corda hot-cold setup with external artemis and zookeeper"
	msg "To hunt or to keep, that is the contention"	
	msg ""
	msg "=========================================================================="
}

#Unzip all the files under Temp
run_unzipFiles() {
	tar -C $HOME_LAB/Temp/ -zxvf $HOME_LAB/Temp/$SQL_FILENAME
	tar -C $HOME_LAB/Temp/ -zxvf $HOME_LAB/Temp/$ZOOKEEP_FILENAME
	tar -C $HOME_LAB/Temp/ -zxvf $HOME_LAB/Temp/$ARTEMIS_FILENAME
}

#Create artemis and tunneling keys
run_newArtemisTunnelKeys() {
	msg "===================================================="
	msg "Start create artemis keys"
	msg "++++++++++++++++++++++++++++++++++++++++++++++++++++"
	java -jar $CORDA_UTILITIES generate-internal-artemis-ssl-keystores -p $ARTEMIS_STOREPASS -t $ARTEMIS_TRUSTPASS
	msg "Start create tunnel keys"
	msg "++++++++++++++++++++++++++++++++++++++++++++++++++++"
	java -jar $CORDA_UTILITIES generate-internal-tunnel-ssl-keystores -p $TUNNEL_SSLPASS -e tunnelPrivateKeyPassword -t $TUNNEL_PRIVATEPASS
	msg "++++++++++++++++++++++++++++++++++++++++++++++++++++"
	msg "End create artemis and tunnel keys"
	msg "===================================================="
}

#Create SSL keys for combined partya and partyc
run_combineSSLKeys() {
	msg "===================================================="
	msg "Start insert partya and partyc certs together"
	msg "++++++++++++++++++++++++++++++++++++++++++++++++++++"
	cd $HOME_LAB
	java -jar $CORDA_UTILITIES import-ssl-key --bridge-keystore-password=$BRIDGE_SSLPASS --bridge-keystore=$HOME_LAB/Temp/Bridge/certificates/sslkeystore.jks --node-keystores=$HOME_LAB/Temp/PartyA/certificates/sslkeystore.jks --node-keystore-passwords=$PARTYA_STOREPASS --node-keystores=$HOME_LAB/Temp/PartyC/certificates/sslkeystore.jks --node-keystore-passwords=$PARTYC_STOREPASS #You would need to update the keypass of the nodes as you have configured during bootstrapping
	msg "++++++++++++++++++++++++++++++++++++++++++++++++++++"
	msg "End insert partya and partyc certs together"
	msg "===================================================="
}

#Create backup of the files for restoration
run_createBackupForRestoration() {
    if [[ ! -d $HOME_LAB/.backup ]]
    then
        mkdir -p $HOME_LAB/.backup
        cp -r $HOME_LAB/* $HOME_LAB/.backup/
    fi
}
#Create additional folders in workspace
run_addTempWorkspace() {
	#Putting together the bridge
	if [[ ! -d $HOME_LAB/Temp/Bridge ]]
	then
		mkdir -p $HOME_LAB/Temp/Bridge
		mkdir -p $HOME_LAB/Temp/Bridge/certificates
		mkdir -p $HOME_LAB/Temp/Bridge/bridgecerts
	fi
	#Putting together the float
	if [[ ! -d $HOME_LAB/Temp/Float  ]]
	then
		mkdir -p $HOME_LAB/Temp/Float
		mkdir -p $HOME_LAB/Temp/Float/floatcerts
	fi
	#Putting together the artemis
	if [[ ! -d $HOME_LAB/Temp/Artemis ]]
	then
		mkdir -p $HOME_LAB/Temp/Artemis
		mkdir -p $HOME_LAB/Temp/Artemis/ArtemisDownload
	fi
	#Putting together the zookeeper
	if [[ ! -d $HOME_LAB/Temp/ZooKeeper ]]
	then
		mkdir -p $HOME_LAB/Temp/ZooKeeper
	fi
	#Puttng together the PartyA
	if [[ ! -d $HOME_LAB/Temp/PartyA ]]
	then
		mkdir -p $HOME_LAB/Temp/PartyA
		mkdir -p $HOME_LAB/Temp/PartyA/drivers
	fi
	#Puttng together the PartyC
        if [[ ! -d $HOME_LAB/Temp/PartyC ]]
        then
                mkdir -p $HOME_LAB/Temp/PartyC
                mkdir -p $HOME_LAB/Temp/PartyC/drivers
        fi
	
}
#Assemble PartyA
run_assemblePartyA() {
        cp -r $HOME/Lab1/partya/* $HOME_LAB/Temp/PartyA/
	sudo rm -r $HOME_LAB/Temp/PartyA/node.conf #Removing the node.conf as you would need to replace with one that has ENT params
	sudo rm -r $HOME_LAB/Temp/PartyA/persistence* #Removing the database as it will be replaced with SQL
	cp -r $HOME_LAB/artemis/ $HOME_LAB/Temp/PartyA/
	cp -r $HOME_LAB/Temp/$SQL_FOLDERNAME/enu/$SQL_DRIVERNAME $HOME_LAB/Temp/PartyA/drivers/
}
#Assemble PartyC
run_assemblePartyC() {
        cp -r $HOME/Lab1/partyc/* $HOME_LAB/Temp/PartyC/
        sudo rm -r $HOME_LAB/Temp/PartyC/node.conf #Removing the node.conf as you would need to replace with one that has ENT params
        sudo rm -r $HOME_LAB/Temp/PartyC/persistence* #Removing the database as it will be replaced with SQL
        cp -r $HOME_LAB/artemis/ $HOME_LAB/Temp/PartyC/
        cp -r $HOME_LAB/Temp/$SQL_FOLDERNAME/enu/$SQL_DRIVERNAME $HOME_LAB/Temp/PartyC/drivers/
}
#Assemble Bridge
run_assembleBridge() {
	cp -r $HOME_LAB/artemis/ $HOME_LAB/Temp/Bridge/
	sudo rm -r $HOME_LAB/Temp/Bridge/artemis/artemis-root.jks
	cp -r $HOME_LAB/tunnel/bridge.jks $HOME_LAB/Temp/Bridge/bridgecerts
	cp -r $HOME_LAB/tunnel/tunnel-truststore.jks $HOME_LAB/Temp/Bridge/bridgecerts
	cp -r $HOME_LAB/Temp/PartyA/certificates/truststore.jks $HOME_LAB/Temp/Bridge/certificates
	cp -r $HOME_LAB/$CORDA_FIREWALL $HOME_LAB/Temp/Bridge/
	cp -r $HOME_LAB/Temp/PartyA/network-parameters $HOME_LAB/Temp/Bridge
}

#Assemble Float
run_assembleFloat() {
	cp -r $HOME_LAB/tunnel/float.jks $HOME_LAB/Temp/Float/floatcerts
	cp -r $HOME_LAB/tunnel/tunnel-truststore.jks $HOME_LAB/Temp/Float/floatcerts
	cp -r $HOME_LAB/$CORDA_FIREWALL $HOME_LAB/Temp/Float/
	cp -r $HOME_LAB/Temp/PartyA/network-parameters $HOME_LAB/Temp/Float
}

#Assemble Artemis
run_assembleArtemis() {
	cp -r $HOME_LAB/Temp/$ARTEMIS_FOLDERNAME/* $HOME_LAB/Temp/Artemis/ArtemisDownload/
	cp -r $HOME_LAB/artemis/ $HOME_LAB/Temp/Artemis/
	sudo rm -r $HOME_LAB/Temp/Artemis/artemis/artemis-root.jks
	cp -r $HOME_LAB/$CORDA_UTILITIES $HOME_LAB/Temp/Artemis/
	cp -r $HOME_LAB/configure_artemis.sh $HOME_LAB/Temp/Artemis/
	sed -i "s/artemisStorePass/${ARTEMIS_STOREPASS}/" $HOME_LAB/Temp/Artemis/configure_artemis.sh
	sed -i "s/artemisTrustpass/${ARTEMIS_TRUSTPASS}/" $HOME_LAB/Temp/Artemis/configure_artemis.sh
}

#Assemble Zookeeper
run_assembleZookeeper() {
	cp -r $HOME_LAB/Temp/$ZOOKEEP_FOLDERNAME/* $HOME_LAB/Temp/ZooKeeper/ 

}
#Create the folders for each respective VMs i.e. vminfra1, vmInfra2, vmInfra3 and vmInfra4 (notary and PartyB)
run_createVmInfra() {
	
    	if [[ ! -d $HOME_LAB/vmInfra1 ]]
    	then
        	mkdir -p $HOME_LAB/vmInfra1/ZooKeeperOne	
        	mkdir -p $HOME_LAB/vmInfra1/Artemis      
        	mkdir -p $HOME_LAB/vmInfra1/PartyA        
        	mkdir -p $HOME_LAB/vmInfra1/PartyC
        	mkdir -p $HOME_LAB/vmInfra1/Bridge
		mkdir -p $HOME_LAB/vmInfra1/Float
		cp -r $HOME_LAB/Temp/ZooKeeper/* $HOME_LAB/vmInfra1/ZooKeeperOne/
		mkdir -p $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1
		cp -r $HOME_LAB/Temp/Artemis/* $HOME_LAB/vmInfra1/Artemis/
		cp -r $HOME_LAB/Temp/PartyA/* $HOME_LAB/vmInfra1/PartyA/
		cp -r $HOME_LAB/$CORDA_HEALTH_SURVEY $HOME_LAB/vmInfra1/PartyA
		cp -r $HOME_LAB/Temp/PartyC/* $HOME_LAB/vmInfra1/PartyC/
		cp -r $HOME_LAB/Temp/Bridge/* $HOME_LAB/vmInfra1/Bridge/
		cp -r $HOME_LAB/Temp/Float/* $HOME_LAB/vmInfra1/Float/
		
    	fi

    	if [[ ! -d $HOME_LAB/vmInfra2 ]]
    	then
        	mkdir -p $HOME_LAB/vmInfra2/ZooKeeperTwo
        	mkdir -p $HOME_LAB/vmInfra2/Artemis
        	mkdir -p $HOME_LAB/vmInfra2/PartyAPrime
        	mkdir -p $HOME_LAB/vmInfra2/PartyCPrime
        	mkdir -p $HOME_LAB/vmInfra2/BridgePrime
        	mkdir -p $HOME_LAB/vmInfra2/FloatPrime
        	cp -r $HOME_LAB/Temp/ZooKeeper/* $HOME_LAB/vmInfra2/ZooKeeperTwo/
		mkdir -p $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2
        	cp -r $HOME_LAB/Temp/Artemis/* $HOME_LAB/vmInfra2/Artemis/
        	cp -r $HOME_LAB/Temp/PartyA/* $HOME_LAB/vmInfra2/PartyAPrime/
        	cp -r $HOME_LAB/Temp/PartyC/* $HOME_LAB/vmInfra2/PartyCPrime/
        	cp -r $HOME_LAB/Temp/Bridge/* $HOME_LAB/vmInfra2/BridgePrime/
        	cp -r $HOME_LAB/Temp/Float/* $HOME_LAB/vmInfra2/FloatPrime/
    	fi

    	if [[ ! -d $HOME_LAB/vmInfra3 ]]
    	then
        	mkdir -p $HOME_LAB/vmInfra3/ZooKeeperThree
        	cp -r $HOME_LAB/Temp/ZooKeeper/* $HOME_LAB/vmInfra3/ZooKeeperThree/
		mkdir -p $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3

    	fi
    	if [[ ! -d $HOME_LAB/vmInfra4 ]]
    	then
        	mkdir -p $HOME_LAB/vmInfra4/PartyB
			cp -r $HOME/Lab1/partyb/* $HOME_LAB/vmInfra4/PartyB
    	fi
}
#Configure the various appliances. You would need to make sure your config files are correct
run_config() {
	msg "============================================================================"
	msg "Start copy config files to the respective folder"
	msg "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	if [[ ! -d $HOME_LAB/ConfigFiles  ]]
	then
		echo "Configuration files absent"
		exit
	fi
	#vmInfra1
	cp -r $HOME_LAB/ConfigFiles/PartyA/node.conf $HOME_LAB/vmInfra1/PartyA/
	#Update PartyA config
	sed -i "s/PARTYA_IDENTITY/${PARTYA_IDENTITY}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/P2P_IPPORT/${P2P_IPPORT}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/PARTYA_STOREPASS/${PARTYA_STOREPASS}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/PARTYA_TRUSTPASS/${PARTYA_TRUSTPASS}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/ARTEMIS_MAIN/${ARTEMISMASTER_IPPORT}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/ARTEMIS_BACKUP/${ARTEMISSLAVE_IPPORT}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/ARTEMIS_STOREPASS/${ARTEMIS_STOREPASS}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/ARTEMIS_TRUSTPASS/${ARTEMIS_TRUSTPASS}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	
	sed -i "s/SQL_DATABASE_HOST/${SQL_DATABASE_HOST}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/PARTYA_DATABASE_NAME/${PARTYA_DATABASE_NAME}/" $HOME_LAB/vmInfra1/PartyA/node.conf
	
	sed -i "s/RUN_MIGRATION/true/" $HOME_LAB/vmInfra1/PartyA/node.conf
	sed -i "s/MACHINE_NAME/partyaNodeServer1/" $HOME_LAB/vmInfra1/PartyA/node.conf
	cp -r $HOME_LAB/ConfigFiles/PartyC/node.conf $HOME_LAB/vmInfra1/PartyC/
	#Update PartyC config
	sed -i "s/PARTYC_IDENTITY/${PARTYC_IDENTITY}/" $HOME_LAB/vmInfra1/PartyC/node.conf
	sed -i "s/P2P_IPPORT/${P2P_IPPORT}/" $HOME_LAB/vmInfra1/PartyC/node.conf
        sed -i "s/PARTYC_STOREPASS/${PARTYC_STOREPASS}/" $HOME_LAB/vmInfra1/PartyC/node.conf
        sed -i "s/PARTYC_TRUSTPASS/${PARTYC_TRUSTPASS}/" $HOME_LAB/vmInfra1/PartyC/node.conf
        sed -i "s/ARTEMIS_MAIN/${ARTEMISMASTER_IPPORT}/" $HOME_LAB/vmInfra1/PartyC/node.conf
        sed -i "s/ARTEMIS_BACKUP/${ARTEMISSLAVE_IPPORT}/" $HOME_LAB/vmInfra1/PartyC/node.conf
        sed -i "s/ARTEMIS_STOREPASS/${ARTEMIS_STOREPASS}/" $HOME_LAB/vmInfra1/PartyC/node.conf
        sed -i "s/ARTEMIS_TRUSTPASS/${ARTEMIS_TRUSTPASS}/" $HOME_LAB/vmInfra1/PartyC/node.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra1/PartyC/node.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra1/PartyC/node.conf


	sed -i "s/SQL_DATABASE_HOST/${SQL_DATABASE_HOST}/" $HOME_LAB/vmInfra1/PartyC/node.conf
	sed -i "s/PARTYC_DATABASE_NAME/${PARTYC_DATABASE_NAME}/" $HOME_LAB/vmInfra1/PartyC/node.conf

        sed -i "s/RUN_MIGRATION/true/" $HOME_LAB/vmInfra1/PartyC/node.conf
        sed -i "s/MACHINE_NAME/partycNodeServer1/" $HOME_LAB/vmInfra1/PartyC/node.conf
	cp -r $HOME_LAB/ConfigFiles/Bridge/bridge.conf $HOME_LAB/vmInfra1/Bridge/
	#Update Bridge config
	sed -i "s/ARTEMIS_MAIN/${ARTEMISMASTER_IPPORT}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/ARTEMIS_BACKUP/${ARTEMISSLAVE_IPPORT}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/ARTEMIS_STOREPASS/${ARTEMIS_STOREPASS}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/ARTEMIS_TRUSTPASS/${ARTEMIS_TRUSTPASS}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/FLOAT_MAIN/${FLOAT_IPPORT}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/FLOAT_BACKUP/${FLOATPRIME_IPPORT}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/TUNNEL_SSLPASS/${TUNNEL_SSLPASS}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/TUNNEL_PRIVATEPASS/${TUNNEL_PRIVATEPASS}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/BRIDGE_SSLPASS/${BRIDGE_SSLPASS}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/BRIDGE_TRUSTPASS/${PARTYA_TRUSTPASS}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/ZOO_LSTONE/${ZOO1_IPPORT}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/ZOO_LSTTWO/${ZOO2_IPPORT}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/ZOO_LSTTHREE/${ZOO3_IPPORT}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra1/Bridge/bridge.conf
	cp -r $HOME_LAB/ConfigFiles/Float/float.conf $HOME_LAB/vmInfra1/Float/
	#Update Float config
	sed -i "s/FLOAT_LST/${FLOATLST_IPPORT}/" $HOME_LAB/vmInfra1/Float/float.conf
	sed -i "s/FLOAT_MAIN/${FLOAT_IPPORT}/" $HOME_LAB/vmInfra1/Float/float.conf
	sed -i "s/TUNNEL_SSLPASS/${TUNNEL_SSLPASS}/" $HOME_LAB/vmInfra1/Float/float.conf
	sed -i "s/TUNNEL_PRIVATEPASS/${TUNNEL_PRIVATEPASS}/" $HOME_LAB/vmInfra1/Float/float.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra1/Float/float.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra1/Float/float.conf
	cp -r $HOME_LAB/ConfigFiles/zoo/* $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/
	#Update zoo1 config
	sed -i "s/MY_ID/1/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/myid
	sed -i "s/ZOO_FOLDER/zoo1/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg
	sed -i "s/One/One/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg
	sed -i "s/ZOOONE_LOCAL/0.0.0.0/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg.dynamic
	sed -i "s/ZOOTWO_LOCAL/$(echo ${ZOO2_IPPORT} | cut -f1 -d: )/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg.dynamic
	sed -i "s/ZOOTHREE_LOCAL/$(echo ${ZOO3_IPPORT} | cut -f1 -d: )/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg.dynamic
	sed -i "s/ZOO1_IPPORT/${ZOO1_IPPORT}/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg.dynamic
	sed -i "s/ZOO2_IPPORT/${ZOO2_IPPORT}/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg.dynamic
	sed -i "s/ZOO3_IPPORT/${ZOO3_IPPORT}/" $HOME_LAB/vmInfra1/ZooKeeperOne/conf/zoo1/zoo.cfg.dynamic

	#vmInfra2
	cp -r $HOME_LAB/ConfigFiles/PartyA/node.conf $HOME_LAB/vmInfra2/PartyAPrime/
	#Update PartyA' config
	sed -i "s/PARTYA_IDENTITY/${PARTYA_IDENTITY}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
        sed -i "s/P2P_IPPORT/${P2P_IPPORT}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
        sed -i "s/PARTYA_STOREPASS/${PARTYA_STOREPASS}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
        sed -i "s/PARTYA_TRUSTPASS/${PARTYA_TRUSTPASS}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
        sed -i "s/ARTEMIS_MAIN/${ARTEMISSLAVE_IPPORT}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
        sed -i "s/ARTEMIS_BACKUP/${ARTEMISMASTER_IPPORT}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
        sed -i "s/ARTEMIS_STOREPASS/${ARTEMIS_STOREPASS}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
        sed -i "s/ARTEMIS_TRUSTPASS/${ARTEMIS_TRUSTPASS}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf

    sed -i "s/SQL_DATABASE_HOST/${SQL_DATABASE_HOST}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
	sed -i "s/PARTYA_DATABASE_NAME/${PARTYA_DATABASE_NAME}/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf

	sed -i "s/RUN_MIGRATION/false/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
	sed -i "s/MACHINE_NAME/partyaNodeServer2/" $HOME_LAB/vmInfra2/PartyAPrime/node.conf
	cp -r $HOME_LAB/ConfigFiles/PartyC/node.conf $HOME_LAB/vmInfra2/PartyCPrime/
	#Update PartyC' config
	sed -i "s/PARTYC_IDENTITY/${PARTYC_IDENTITY}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/P2P_IPPORT/${P2P_IPPORT}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/PARTYC_STOREPASS/${PARTYC_STOREPASS}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/PARTYC_TRUSTPASS/${PARTYC_TRUSTPASS}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/ARTEMIS_MAIN/${ARTEMISSLAVE_IPPORT}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/ARTEMIS_BACKUP/${ARTEMISMASTER_IPPORT}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/ARTEMIS_STOREPASS/${ARTEMIS_STOREPASS}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/ARTEMIS_TRUSTPASS/${ARTEMIS_TRUSTPASS}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf

        sed -i "s/SQL_DATABASE_HOST/${SQL_DATABASE_HOST}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
	    sed -i "s/PARTYC_DATABASE_NAME/${PARTYC_DATABASE_NAME}/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf

        sed -i "s/RUN_MIGRATION/false/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
        sed -i "s/MACHINE_NAME/partycNodeServer2/" $HOME_LAB/vmInfra2/PartyCPrime/node.conf
	cp -r $HOME_LAB/ConfigFiles/Bridge/bridge.conf $HOME_LAB/vmInfra2/BridgePrime/
	#Update Bridge' config
        sed -i "s/ARTEMIS_MAIN/${ARTEMISSLAVE_IPPORT}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/ARTEMIS_BACKUP/${ARTEMISMASTER_IPPORT}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/ARTEMIS_STOREPASS/${ARTEMIS_STOREPASS}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/ARTEMIS_TRUSTPASS/${ARTEMIS_TRUSTPASS}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/FLOAT_MAIN/${FLOATPRIME_IPPORT}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/FLOAT_BACKUP/${FLOAT_IPPORT}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/TUNNEL_SSLPASS/${TUNNEL_SSLPASS}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/TUNNEL_PRIVATEPASS/${TUNNEL_PRIVATEPASS}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/BRIDGE_SSLPASS/${BRIDGE_SSLPASS}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/BRIDGE_TRUSTPASS/${PARTYA_TRUSTPASS}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/ZOO_LSTONE/${ZOO2_IPPORT}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/ZOO_LSTTWO/${ZOO1_IPPORT}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        sed -i "s/ZOO_LSTTHREE/${ZOO3_IPPORT}/" $HOME_LAB/vmInfra2/BridgePrime/bridge.conf
        cp -r $HOME_LAB/ConfigFiles/Float/float.conf $HOME_LAB/vmInfra2/FloatPrime/
	#Update Float' config
        sed -i "s/FLOAT_LST/${FLOATPRIMELST_IPPORT}/" $HOME_LAB/vmInfra2/FloatPrime/float.conf
        sed -i "s/FLOAT_MAIN/${FLOATPRIME_IPPORT}/" $HOME_LAB/vmInfra2/FloatPrime/float.conf
        sed -i "s/TUNNEL_SSLPASS/${TUNNEL_SSLPASS}/" $HOME_LAB/vmInfra2/FloatPrime/float.conf
        sed -i "s/TUNNEL_PRIVATEPASS/${TUNNEL_PRIVATEPASS}/" $HOME_LAB/vmInfra2/FloatPrime/float.conf
	sed -i "s/DOORMAN_URL/${PARSED_DOORMAN_URL}/" $HOME_LAB/vmInfra2/FloatPrime/float.conf
	sed -i "s/NETWORK_MAP_URL/${PARSED_NETMAP_URL}/" $HOME_LAB/vmInfra2/FloatPrime/float.conf
	cp -r $HOME_LAB/ConfigFiles/zoo/* $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/
	#Update zoo2 config
        sed -i "s/MY_ID/2/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/myid
        sed -i "s/ZOO_FOLDER/zoo2/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg
	sed -i "s/One/Two/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg
        sed -i "s/ZOOONE_LOCAL/$(echo ${ZOO1_IPPORT} | cut -f1 -d: )/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg.dynamic
        sed -i "s/ZOOTWO_LOCAL/0.0.0.0/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg.dynamic
        sed -i "s/ZOOTHREE_LOCAL/$(echo ${ZOO3_IPPORT} | cut -f1 -d: )/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg.dynamic
        sed -i "s/ZOO1_IPPORT/${ZOO1_IPPORT}/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg.dynamic
        sed -i "s/ZOO2_IPPORT/${ZOO2_IPPORT}/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg.dynamic
        sed -i "s/ZOO3_IPPORT/${ZOO3_IPPORT}/" $HOME_LAB/vmInfra2/ZooKeeperTwo/conf/zoo2/zoo.cfg.dynamic

	#vmInfra3
	cp -r $HOME_LAB/ConfigFiles/zoo/* $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/
	#Update zoo3 config
        sed -i "s/MY_ID/3/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/myid
        sed -i "s/ZOO_FOLDER/zoo3/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg
	sed -i "s/One/Three/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg
        sed -i "s/ZOOONE_LOCAL/$(echo ${ZOO1_IPPORT} | cut -f1 -d: )/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg.dynamic
        sed -i "s/ZOOTWO_LOCAL/$(echo ${ZOO2_IPPORT} | cut -f1 -d: )/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg.dynamic
        sed -i "s/ZOOTHREE_LOCAL/0.0.0.0/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg.dynamic
        sed -i "s/ZOO1_IPPORT/${ZOO1_IPPORT}/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg.dynamic
        sed -i "s/ZOO2_IPPORT/${ZOO2_IPPORT}/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg.dynamic
        sed -i "s/ZOO3_IPPORT/${ZOO3_IPPORT}/" $HOME_LAB/vmInfra3/ZooKeeperThree/conf/zoo3/zoo.cfg.dynamic

	msg "============================================================================"
        msg "End copy config files to the respective folder"
        msg "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

}

run_configReviewer() {
	msg "============================================================================"
        msg ""
	msg "Do you want to review the IP:Port and JKS password in this bash before you"
       	msg "begin?"	
        msg ""
	msg "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	if [[ "$RUN_CONFIG_REVIEW" == ""   ]]
	then
		msg "(yes/no)"
		read RUN_CONFIG_REVIEW
	fi

	if [[ "$RUN_CONFIG_REVIEW" == "yes" ]]
	then
		msg "IP and Port of the appliances"
		msg "===================================================="
		msg "Party A and C P2P = ${P2P_IPPORT}"
		msg "Float = ${FLOAT_IPPORT}"
		msg "Float listening = ${FLOATLST_IPPORT}"
		msg "Float Prime  = ${FLOATPRIME_IPPORT}"
		msg "Float Prime listening = ${FLOATPRIMELST_IPPORT}"
		msg "ZooKeeper One = ${ZOO1_IPPORT}"
		msg "ZooKeeper Two = ${ZOO2_IPPORT}"
		msg "ZooKeeper Three = ${ZOO3_IPPORT}"
		msg "Artemis Master = ${ARTEMISMASTER_IPPORT}"
		msg "Artemis Slave = ${ARTEMISSLAVE_IPPORT}"
		msg "(Optional) Party B P2P = ${PARTYBP2P_IPPORT}"
		msg ""
		msg "Identity, Database and Network connection details"
		msg "===================================================="
		msg "Party A Identity = ${PARTYA_IDENTITY}"
		msg "Party C Identity = ${PARTYC_IDENTITY}"
		msg "SQL Database Host = ${SQL_DATABASE_HOST}"
		msg "Party A Database Name = ${PARTYA_DATABASE_NAME}"
		msg "Party C Database Name = ${PARTYC_DATABASE_NAME}"
		msg "Identity Manager URL = ${DOORMAN_URL}"
		msg "Network Map URL = ${NETWORK_MAP_URL}"
		msg ""
		msg "JKS password"
		msg "===================================================="
		msg "Artemis keystore password = ${ARTEMIS_STOREPASS}"
		msg "Artemis truststore password = ${ARTEMIS_TRUSTPASS}"
		msg "Bridge-float tunnel SSL store password = ${TUNNEL_SSLPASS}"
		msg "Bridge-float tunnel private store password = ${TUNNEL_PRIVATEPASS}"
		msg "Bridge keystore password = ${BRIDGE_SSLPASS}"
		msg "Party A keystore password = ${PARTYA_STOREPASS}"
		msg "Party A truststore password = ${PARTYA_TRUSTPASS}"
		msg "Party C keystore password = ${PARTYC_STOREPASS}"
		msg "Party C truststore password = ${PARTYC_TRUSTPASS}"
		msg ""
		run_continueInstall	
	fi
	if [[ "$RUN_CONFIG_REVIEW" == "no" ]]
	then
		run_continueInstall
	fi
	
}

run_continueInstall() {

	if [[ "$CONTINUE_INSTALL"  == ""   ]]
	then
		msg "Do you wish to continue with install (yes/no)"
		read CONTINUE_INSTALL
	fi

	if [[ "$CONTINUE_INSTALL"  == "yes"   ]]
	then
		msg "Continue installation"
	else
		exit 10
	fi
}

#Main function run
message
run_configReviewer
run_createBackupForRestoration
run_newArtemisTunnelKeys
run_unzipFiles
run_addTempWorkspace
run_assemblePartyA
run_assemblePartyC
run_assembleBridge
run_assembleFloat
run_assembleArtemis
run_assembleZookeeper
run_combineSSLKeys
run_createVmInfra
run_config
