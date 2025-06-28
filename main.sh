#!/bin/bash

# Verifică dacă comanda ssh există și dacă serviciul sshd este pornit
if ! command -v ssh >/dev/null 2>&1
then
    	echo -e "\nssh nu este instalat, instalați-l și porniți serviciul pentru acesta, dacă este nevoie.\n"
    	exit 1 
elif [[ "$(systemctl is-active sshd)" != "active" ]]; then
	echo -e "\nssh nu este activ, de obicei se activează cu 'sudo systemctl start sshd.service', 'sudo systemctl enable sshd.service' pentru a-l face permanent.\n"
	exit 1
fi

# Verifică dacă comanda curl există
if ! command -v curl >/dev/null 2>&1
then
	echo -e "curl nu este instalat, instalați-l cu manager-ul de pachete al distribuției dvs.\n"
    	exit 1
fi

# Meniul principal
while true; do
	echo -e "\nMeniul principal:"

	PS3="Selectați o opțiune: "
	options=("Opțiuni Minikube" "Opțiuni mașini virtuale" "Afișați resursele utilizate de componente" "Ieșire")

	COLUMNS=1

	select opt in "${options[@]}"; do
		case $opt in
			"Opțiuni Minikube")
				set -e # Pentru ca să se poată ieși din script-uri imbricate cu exit 1
				./minikube_options.sh
				echo -e "\n"
				break
				;;
			"Opțiuni mașini virtuale")
				# Verifică dacă există un cluster minikube
				if minikube status 2>/dev/null | grep -q "host"; then
					# Dacă există, verifică dacă este oprit
					if [ "$(minikube status 2>/dev/null | grep "host" | awk '{print $2}')" = "Stopped" ]; then	
							echo -e "Cluster-ul minikube este oprit, se pornește...\n"
						minikube start --driver=docker
						# Verifică dacă KubeVirt este instalat în clusterul existent
						if [ "$(minikube kubectl -- get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.phase}" 2>/dev/null)" = "Deployed" ]; then
											./vm_options.sh
						else
							echo -e "\nClusterul existent nu a fost inițializat cu KubeVirt, ștergeți-l din meniul cu opțiuni Minikube sau cu comanda 'minikube delete' și creați-l cu prima opțiune din acel meniu."
						fi
					# Dacă este pornit, verifică dacă KubeVirt este instalat
					elif [ "$(minikube kubectl -- get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.phase}" 2>/dev/null)" = "Deployed" ]; then
						./vm_options.sh
					else
						echo -e "\nClusterul existent nu a fost inițializat cu KubeVirt, ștergeți-l din meniul cu opțiuni Minikube sau cu comanda 'minikube delete' și creați-l cu prima opțiune din acel meniu."
					fi
				else
					echo -e "\nSetup-ul Minikube cu KubeVirt nu a fost creat, creați-l cu prima opțiune din meniul cu opțiuni Minikube."
					fi
				break
				;;
			"Afișați resursele utilizate de componente")
				./resource_metrics.sh
				break
				;;
			"Ieșire")
				exit 1
				;;
			*) echo "Opțiune greșită $REPLY" ;;
		esac
	done
done
