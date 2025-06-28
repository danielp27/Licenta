#!/bin/bash

while true; do
	echo -e "\nOpțiuni mașini virtuale:"

	PS3="Selectați o opțiune: "
	options=("Crează o mașină virtuală" "Afișează chiriașii existenți" "Afișează mașinile virtuale existente" "Intră într-o mașină virtuală" "Șterge o mașină virtuală" "Șterge toate mașinile virtuale" "Fă deploy la un server nginx pe o mașină virtuală" "Meniul anterior")

	COLUMNS=1

	select opt in "${options[@]}"; do
		case $opt in
			"Crează o mașină virtuală")
				./vm_creation.sh
				echo -e "\n"
				break
				;;
			"Afișează chiriașii existenți")
				echo ""
				# Pune lista de chiriași într-o variabilă
				tenants=$(minikube kubectl -- get vms -o jsonpath="{.items[*].metadata.labels.tenant}" | tr ' ' '\n' | sort -u)

				# Verifică dacă lista e goală, dacă nu o afișează
				if [[ -z "$tenants" ]]; then
					echo "Nu există chiriași!"
				else
					echo "$tenants"
				fi
				break
				;;
			"Afișează mașinile virtuale existente")
				# Pune lista de mașini virtuale într-o variabilă
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')

				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo -e "\nNu există mașini virtuale!"
				else
					echo -e "\nToate sau doar pentru un singur chiriaș?"
					echo "1 - toate"
					echo "2 - pentru un singur chiriaș"
					echo "Orice alt input, inclusiv Enter, pentru a vă întoarce la meniu."
					read -p "Alegeți o opțiune: " x
					if ! [[ "$x" =~ ^[0-9]+$ ]]; then # Verifică dacă variabila x nu este cifră
						break
					elif [[ $x -eq 1 ]]; then
						echo ""
						minikube kubectl -- get vmi
					elif [[ $x -eq 2 ]]; then
						echo ""
						read -p "Introduceți un chiriaș: " tenant
						# Verifică dacă există mașini virtuale care aparțin de chirașul introdus și le pune într-o variabile
						tenant_exists=$(minikube kubectl -- get vms -l tenant="$tenant" -o name 2>/dev/null)

						# Verifică dacă variabila este goală, adică nu există chiriașul introdus
						if [[ -z "$tenant_exists" ]]; then
							echo -e "\nChiriașul '$tenant' nu există."
							break
						else
							echo ""
							minikube kubectl -- get vmi -l tenant=$tenant
						fi
					else
						break
					fi
				fi
				break
				;;
			"Intră într-o mașină virtuală")
				# Pune lista de mașini virtuale într-o variabilă
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')

				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo -e "\nNu există mașini virtuale!"
				else
					read -p "Numele mașinii virtuale: " vm_name
					ssh -i ~/.ssh/id_ed25519 fedora@$(minikube ip) -p $(minikube kubectl -- get svc $vm_name-ssh -o=jsonpath='{.spec.ports[0].nodePort}')
				fi
				break
				;;
			"Șterge o mașină virtuală")
				# Pune lista de mașini virtuale într-o variabilă
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')

				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo -e "\nNu există mașini virtuale!"
				else
					read -p "Numele mașinii virtuale: " vm_name
					# Verifică dacă există mașina virtuală introdusă
					if minikube kubectl -- get vms 2>/dev/null | grep -qw "$vm_name"; then
						while true; do
							# Cere utilizatorului să confirme ștergerea mașinii virtuale
							read -p "Sunteți sigur că vreți să ștergeți mașina virtuală '$vm_name'? (da/nu):  " conf
							if [[ "${conf,,}" == "da" ]]; then
								# Se șterge mașina virtuală împreună cu volumul său de date și fișierele folosite la crearea acesteia
								dv_name=$(awk '/claimName/ {print $2}' $vm_name"_pvc.yml")
								echo ""
								minikube kubectl -- delete -f $vm_name"_pvc.yml"
								minikube kubectl -- delete svc $vm_name-ssh
								minikube kubectl -- delete -f dv_$dv_name.yml
								rm $vm_name"_pvc.yml"
								rm dv_$dv_name.yml
								break
							elif [[ "${conf,,}" == "nu" ]]; then
								break
							else
								echo -e "\nRăspundeți cu da sau nu."
							fi
						done
					else
						echo -e "\nMașina virtuală $vm_name nu există.\n"
						break
					fi
				fi
				break
				;;
			"Șterge toate mașinile virtuale")
				# Pune lista de mașini virtuale într-o variabilă
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')

				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo -e "\nNu există mașini virtuale!"
				else
					echo -e "\nToate sau doar pentru un singur chiriaș?"
					echo "1 - toate"
					echo "2 - pentru un singur chiriaș"
					echo "Orice alt input, inclusiv Enter, pentru a vă întoarce la meniu."
					read -p "Alegeți o opțiune: " x
					if ! [[ "$x" =~ ^[0-9]+$ ]]; then # Verifică dacă variabila x nu este cifră
						break
					elif [[ $x -eq 1 ]]; then
						while true; do
							# Cere confirmare
							read -p "Sunteți sigur că vreți să ștergeți toate mașinile virtuale? (da/nu):  " conf
							if [[ "${conf,,}" == "da" ]]; then
								echo -e "\nSe șterg toate mașinile virtuale...\n"
								# Se șterg toate mașinile virtuale cu tot ce a fost folosit pentru a le crea
								for vm in $(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}'); do
									dv=$(awk '/claimName/ {print $2}' $vm"_pvc.yml")
									minikube kubectl -- delete -f $vm"_pvc.yml"
									minikube kubectl -- delete svc $vm-ssh
									minikube kubectl -- delete -f dv_$dv.yml
									rm $vm"_pvc.yml"
									rm dv_$dv.yml
								done
								break
							elif [[ "${conf,,}" == "nu" ]]; then
								break
							else
								echo -e "\nRăspundeți cu da sau nu."
							fi
						done
					elif [[ $x -eq 2 ]]; then
						read -p "Introduceți un chiriaș: " tenant
						# Verifică dacă există mașini virtuale care aparțin de chirașul introdus și le pune într-o variabile
						tenant_exists=$(minikube kubectl -- get vms -l tenant="$tenant" -o name 2>/dev/null)

						# Verifică dacă variabila este goală, adică nu există chiriașul introdus
						if [[ -z "$tenant_exists" ]]; then
							echo -e "\nChiriașul '$tenant' nu există."
							break
						else
							while true; do
								# Cere confirmare
								read -p "Sunteți sigur că vreți să ștergeți toate mașinile virtuale pentru $tenant? (da/nu):  " conf
								if [[ "${conf,,}" == "da" ]]; then
									echo -e "\nSe șterg toate mașinile virtuale pentru $tenant...\n"
									# Șterge toate mașinile virtuale pentru chiriașul ales
									for vm in $(minikube kubectl -- get vms -l tenant=$tenant 2>/dev/null | awk 'NR>1 {print $1}'); do
										dv=$(awk '/claimName/ {print $2}' $vm"_pvc.yml")
										minikube kubectl -- delete -f $vm"_pvc.yml"
										minikube kubectl -- delete svc $vm-ssh
										minikube kubectl -- delete -f dv_$dv.yml
										rm $vm"_pvc.yml"
										rm dv_$dv.yml
									done
									break
								elif [[ "${conf,,}" == "nu" ]]; then
									break
								else
									echo -e "\nRăspundeți cu da sau nu."
								fi
							done
						fi
					else
						break
					fi
				fi
				break
				;;
			"Fă deploy la un server nginx pe o mașină virtuală")
				# Pune lista de mașini virtuale într-o variabilă
				vms=$(minikube kubectl -- get vms 2>/dev/null | awk 'NR>1 {print $1}')

				# Verifică dacă lista e goală
				if [[ -z "$vms" ]]; then
					echo -e "\nNu există mașini virtuale!"
				else
					echo -e "\nCu pagină implicită sau site personalizat?"
					echo "1 - pagină implicită"
					echo "2 - cu site personalizat"
					echo "Orice alt input, inclusiv Enter, pentru a vă întoarce la meniu."
					read -p "Alegeți o opțiune: " x
					if ! [[ "$x" =~ ^[0-9]+$ ]]; then # Verifică dacă variabila x nu este cifră
						break
					elif [[ $x -eq 1 ]]; then
						echo ""
						./deploy_nginx_to_vm.sh
					elif [[ $x -eq 2 ]]; then
						echo ""
						./deploy_custom_site.sh
					else
						break
					fi
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
