#!/bin/bash

while true; do
	echo ""
	PS3="Selectați o opțiune: "
	options=("Resursele utilizate de tot clusterul" "Resursele utilizate de mașinile virtuale" "Resursele utilizate de nodul clusterului unei mașini virtuale" "Resursele utilizate de capsula (pod) clusterului unei mașini virtuale" "Meniul anterior")

	COLUMNS=1

	select opt in "${options[@]}"; do
		case $opt in
			"Resursele utilizate de tot clusterul")
				echo ""
				minikube kubectl -- top nodes
				break
				;;
			"Resursele utilizate de mașinile virtuale")
				echo ""
				# Pune mașinile virtuale într-o variabilă, dacă există
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')
				
				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo "Nu există mașini virtuale!"
				else
					minikube kubectl -- top pods
				fi
				break
				;;
			"Resursele utilizate de nodul clusterului unei mașini virtuale")
				echo ""
				# Pune mașinile virtuale într-o variabilă, dacă există
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')
				
				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo "Nu există mașini virtuale!"
				else
					while true; do
						read -p "Numele mașinii virtuale: " vm_name
						# Verifică dacă mașina virtuală există
						if minikube kubectl -- get vmi | grep -qw "$vm_name"; then
							echo ""
							# Extrage NodePortul aplicației din clusterul mașinii virtuale
							port=$(minikube kubectl -- get svc $vm_name-ssh -o=jsonpath='{.spec.ports[0].nodePort}') 
							
							ip=$(minikube ip)
							ssh -i ~/.ssh/id_ed25519 -p $port fedora@$ip "kubectl top nodes"
							break
						else
							echo -e "\nMașina virtuală $vm_name nu există, introduceți alta."
						fi
					done
				fi
				break
				;;
			"Resursele utilizate de capsula (pod) clusterului unei mașini virtuale")
				echo ""
				# Pune mașinile virtuale într-o variabilă, dacă există
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')
				
				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo "Nu există mașini virtuale!"
				else
					while true; do
						read -p "Numele mașinii virtuale: " vm_name
						# Verifică dacă mașina virtuală există
						if minikube kubectl -- get vmi 2>/dev/null | grep -qw "$vm_name"; then
							echo ""
							# Extrage NodePortul aplicației din clusterul mașinii virtuale
							port=$(minikube kubectl -- get svc $vm_name-ssh -o=jsonpath='{.spec.ports[0].nodePort}')
							
							ip=$(minikube ip)
							ssh -i ~/.ssh/id_ed25519 -p $port fedora@$ip "kubectl top pods"
							break
						else
							echo -e "\nMașina virtuală $vm_name nu există, introduceți alta."
						fi
					done
				fi
				break
				;;
			"Meniul anterior")
				exit && ./main.sh
				;;
			*) echo "Opțiune greșită $REPLY" ;;
		esac
	done
done
