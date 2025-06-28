#!/bin/bash

while true; do
	echo -e "\nOpțiuni Minikube:"
	PS3="Selectați o opțiune: "
	options=("Creează mediul de lucru (Minikube și Kubevirt)" "Verifică starea clusterului minikube" "Pornește clusterul minikube" "Oprește clusterul minikube" "Șterge clusterul minikube" "Afișați capsulele (pods) existente" "Meniul anterior")

	COLUMNS=1

        select opt in "${options[@]}"; do
                case $opt in
                        "Creează mediul de lucru (Minikube și Kubevirt)")
                                # Verifică dacă există deja un cluster minikube
                                if minikube status 2>/dev/null | grep -q "host"; then
                                        echo -e "\nExistă un cluster minikube, dacă doriți să creați sau să recreați mediul de lucru, ștergeți mai întâi cluster-ul existent cu opțiunea 5) sau comanda 'minikube delete'.\n"
                                else
                                        set -e  # Pentru ca să se poată ieși din script-uri imbricate cu exit 1
                                        ./minikube_setup.sh
                                fi
                                break
                                ;;
                        "Verifică starea clusterului minikube")
                                echo ""
                                minikube status
                                echo ""
                                break
                                ;;
                        "Pornește clusterul minikube")
                                echo ""
                                minikube start --driver=docker
                                echo ""
                                break
                                ;;
                        "Oprește clusterul minikube")
                                echo ""
                                minikube stop
                                echo ""
                                break
                                ;;
                        "Șterge clusterul minikube")
                                echo ""
                                # Verifică dacă există mașini virtuale, ștergându-le în caz afirmativ fișierele .yml folosite pentru crearea acestora
                                if minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}'; then
                                        for vm in $(minikube kubectl -- get vmi 2>/dev/null | awk 'NR>1 {print $1}'); do
                                                dv=$(awk '/claimName/ {print $2}' $vm"_pvc.yml")
                                                rm $vm"_pvc.yml"
                                                rm dv_$dv.yml
                                	done
                                fi
                                minikube delete
                                echo "" > ~/.ssh/known_hosts # Șterge lista de hosturi pentru a nu o supraîncărca
                                echo ""
                                break
                                ;;
                        "Afișați capsulele (pods) existente")
                                echo ""
                                minikube kubectl -- get pods
                                echo ""
                                break
                                ;;
                        "Meniul anterior")
                                exit && ./main.sh
                                ;;
                        *) echo "Opțiune greșită $REPLY" ;;
                esac
        done
done
