#!/bin/bash

#În caz că script-ul este întrerupt de erori sau Ctrl-C, se șterg toate fișierele sau componentele create dacă au fost create
cleanup() {
	echo ""
	echo -e "\nScript-ul a fost întrerupt neașteptat, datele nu se salvează.\n"
	if minikube kubectl -- get vmi 2>/dev/null | grep -qw "$vm_name"; then
		minikube kubectl -- delete -f $vm_name"_pvc.yml"
	fi
	if minikube kubectl -- get svc 2>/dev/null | grep "$vm_name"; then
		minikube kubectl -- delete svc $vm_name-ssh
	fi
	if minikube kubectl -- get pvc 2>/dev/null | grep -qw "$dv_name"; then
        	minikube kubectl -- delete -f dv_$dv_name.yml
	fi
	if [ -f "$vm_name'_pvc.yml'" ]; then
        	rm "$vm_name'_pvc.yml'"
	fi
	if [ -f "dv_$dv_name.yml" ]; then
        	rm "dv_$dv_name.yml"
	fi
	exit 1
}

trap cleanup INT TERM ERR

trap 'trap - INT TERM ERR' EXIT

# Introducerea numelui unui chiriaș
echo ""
while true; do
	read -p "Introduceți numele chiriașul acestei mașini virtuale (ex. client1): " tenant

	if [[ -z "$tenant" || "$tenant" =~ ^[[:space:]]*$ ]]; then # Verifică dacă variabilă este goală sau conține doar spațiu
    		echo -e "\nNumele nu poate fi gol!"
	else
    		break
	fi
done

echo -e "\nSe creează volumul de date care va fi folosit pentru crearea mașinii virtuale.\n"

# Introducerea numelui volumului de date
while true; do
    	read -p "Introduceți numele volumului de date (ex. fedora1): " dv_name

	if [[ -z "$dv_name" || "$dv_name" =~ ^[[:space:]]*$ ]]; then # Verifică dacă variabilă este goală sau conține doar spațiu
                echo -e "\nNumele nu poate fi gol!"
        elif minikube kubectl -- get pvc 2>/dev/null | grep -qw "$dv_name"; then # Verifică dacă există deja un volum de date cu numele introdus
        	echo -e "\nExistă un volum de date cu acest nume, introduceți altul."
    	else
        	break
    	fi
done

# Introducere cantitate stocare pentru mașina virtuală
disk_free=$(df -BG / | awk 'NR==2 { print $4 }' | sed 's/G//') # Extrage stocarea valabilă pe dispozitiv
disk_gib=$((disk_free*1000000000/1073741824)) # Convertește stocarea din Gigabytes în Gibibytes (reține doar partea întreagă)
echo -e "\nStocare valabilă pe dispozitivul dvs.: $disk_gib Gib (număr întreg, fără zecimale)."
echo "Introduceți mărimea stocării mașinii virtuale în GiB (doar Enter pentru default - 5 GiB, care este și cantitatea minimă)." 
while true; do
	read -p "Stocare = " dv_size
	dv_size=${dv_size:-5}
	if  ! [[ "$dv_size" =~ ^[0-9]+$ ]]; then # Verifică dacă valoarea introdusă nu este cifră
                echo -e "\nValoare invalidă!"
	elif [[ $dv_size -lt 5 ]]; then
		echo -e "\nCantitate prea mică!"
	elif [[ $dv_size -ge 5 ]] && [[ $dv_size -le $disk_gib ]]; then
		break
	elif [[ $dv_size -gt $disk_gib ]]; then
		echo -e "\nCantitate mai mare decât dispune dispozitivul dvs!"
	else
		echo -e "\nValoare invalidă!"
	fi
done
echo ""

# Creează și scrie fișierul .yml ce va fi folosit pentru crearea volumului de date
cat <<EOF > dv_$dv_name.yml
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: "$dv_name"
  labels:
    tenant: "$tenant"
spec:
  storage:
    resources:
      requests:
        storage: ${dv_size}Gi
  source:
    http:
      url: "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
EOF

minikube kubectl -- create -f dv_$dv_name.yml # Se crează volumul de date

echo -e "\nSe importează și instalează imaginea volumului de date (Fedora 42 Cloud)...\n"

sleep 4

# Verifică starea capsulelor CDI și așteaptă până acestea rulează
while [ "$(minikube kubectl -- get pod | awk 'NR==2 {print $3}')" != "Running" ]
do
        sleep 2
done

importer_name=$(minikube kubectl -- get pod | awk 'NR==2 {print $1}') # Extrage numele importatorului volumului de date

minikube kubectl -- logs -f $importer_name # Comanda pentru importarea și instalarea imaginii volumului de date

# Introducerea numelui mașinii virtuale
echo ""
while true; do
	read -p "Numele mașinii virtuale (ex. vm1): " vm_name

	if [[ -z "$vm_name" || "$vm_name" =~ ^[[:space:]]*$ ]]; then # Verifică dacă variabilă este goală sau conține doar spațiu
                echo -e "\nNumele nu poate fi gol!"
        elif minikube kubectl -- get vmi 2>/dev/null | grep -qw "$vm_name"; then # Verifică dacă există deja o mașină virtuală cu numele introdus
        	echo -e "\nExistă o mașină virtuală cu acest nume, introduceți altul."
    	else
        	break
    	fi
done

# Introducere număr thread-uri CPU pentru mașina virtuală
cpus=$(lscpu | grep -E 'Model name|Socket|Thread|NUMA|CPU\(s\)' | awk 'NR==1 {print $2}') # Extrage numărul de thread-uri valabile pe dispozitiv
echo -e "\nAveți $cpus thread-uri CPU valabile pe dispozitivul dvs." 
echo "Introduceți numărul de thread-uri pe care îl alocați mașinii virtuale (doar Enter pentru default - 2 thread-uri)."
while true; do
        read -p "Thread-uri = " vm_cpus
        vm_cpus=${vm_cpus:-2}
        if ! [[ "$vm_cpus" =~ ^[0-9]+$ ]]; then # Verifică dacă valoarea introdusă nu este cifră
                echo -e "\nValoare invalidă!" 
        elif [[ $vm_cpus -lt 1 ]]; then
                echo -e "\nCantitate prea mică!"
        elif [[ $vm_cpus -ge 1 ]] && [[ $vm_cpus -le $cpus ]]; then
                break
        elif [[ $vm_mem_size -gt $cpus ]]; then
                echo -e "\nCantitate mai mare decât dispune dispozitivul dvs!"
        else
                echo -e "\nValoare invalidă!"
        fi
done

# Introducere cantitate memorie pentru mașina virtuală
mem_mb=$(free -m | awk '/Mem:/ { print $7 }') # Extrage memoria valabilă (la un moment dat) pe dispozitiv
mem_gib=$((mem_mb*1000000/1073741824)) # Convertește memoria valabilă din Megabytes în Gibibytes (reține doar partea întreagă)
echo -e "\nMemorie valabilă pe dispozitivul dvs.: $mem_gib GiB (număr întreg, fără zecimale)."
echo "Introduceți mărimea memoriei mașinii virtuale în GiB (doar Enter pentru default - 1 GiB, care este și cantitatea minimă)."
while true; do
        read -p "Stocare = " vm_mem_size
	vm_mem_size=${vm_mem_size:-1}
        if ! [[ "$vm_mem_size" =~ ^[0-9]+$ ]]; then # Verifică dacă valoarea introdusă nu este cifră
                echo -e "\nValoare invalidă!" 
	elif [[ $vm_mem_size -lt 1 ]]; then
                echo -e "\nCantitate prea mică!"
        elif [[ $vm_mem_size -ge 1 ]] && [[ $vm_mem_size -lt $mem_gib ]]; then
                break
        elif [[ $vm_mem_size -ge $mem_gib ]]; then
                echo -e "\nCantitate mai mare decât dispune dispozitivul dvs!"
        else
                echo -e "\nValoare invalidă!"
        fi
done
echo ""

# Se creează și scrie fișierul .yml ce va folosi pentru crearea mașini virtuale, care de asemenea instalează K3s și metrics-server în mașina virtuală respectivă
cat <<EOF > $vm_name"_pvc.yml"
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  creationTimestamp: 2018-07-04T15:03:08Z
  generation: 1
  labels:
    kubevirt.io/os: linux
    tenant: $tenant
  name: $vm_name
spec:
  runStrategy: Always
  template:
    metadata:
      creationTimestamp: null
      labels:
        kubevirt.io/domain: $vm_name
        tenant: $tenant
    spec:
      domain:
        cpu:
          cores: $vm_cpus
        devices:
          disks:
          - disk:
              bus: virtio
            name: disk0
          - cdrom:
              bus: sata
              readonly: true
            name: cloudinitdisk
        machine:
          type: q35
        resources:
          requests:
            memory: ${vm_mem_size}Gi
      volumes:
      - name: disk0
        persistentVolumeClaim:
          claimName: $dv_name
      - cloudInitNoCloud:
          userData: |
            #cloud-config
            hostname: $vm_name
            ssh_pwauth: True
            disable_root: false
            ssh_authorized_keys:
            - ssh-rsa YOUR_SSH_PUB_KEY_HERE
            runcmd:
            - curl -sfL https://get.k3s.io | sh -
            - mkdir -p /home/fedora/.kube
            - cp /etc/rancher/k3s/k3s.yaml /home/fedora/.kube/config
            - chown -R fedora:fedora /home/fedora/.kube
            - echo "export KUBECONFIG=/home/fedora/.kube/config" >> /home/fedora/.bashrc
            - source /home/fedora/.bashrc
            - kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        name: cloudinitdisk
EOF

# Verifică dacă există fișierul cu cheia SSH care se va folosi la accesarea mașinii virtuale fără parolă
file=~/.ssh/id_ed25519.pub
if [ ! -f "$file" ]; then
	echo -e "\nSe generează cheia ssh (apăsați doar Enter la orice introducere)...\n"
	ssh-keygen # Creează cheia SSH
fi
PUBKEY=`cat ~/.ssh/id_ed25519.pub` # Pune cheia SSH într-o variabilă
sed -i "s%ssh-rsa.*%$PUBKEY%" $vm_name"_pvc.yml" # Modifică fișierul .yml al mașinii virtuale, introducând cheia la locul său specific
minikube kubectl -- create -f $vm_name"_pvc.yml" # Creează mașina virtuală

echo -e "\nSe așteaptă ca instanța VM ($vm_name) să fie creată...\n"
until minikube kubectl -- get vmi "$vm_name" >/dev/null 2>&1; do
  sleep 2
done

# Funcție pentru a alege un port liber aleatoriu
pick_free_port() {
  while :; do
    port=$(shuf -i 20000-40000 -n 1)
    ! ss -tuln | grep -q ":$port " && echo $port && return
  done
}

free_port=$(pick_free_port)

# Expune mașina virtuala pentru a putea fi accesată direct de pe host
virtctl expose vmi $vm_name --name=$vm_name-ssh --port=$free_port --target-port=22 --type=NodePort

echo -e "\nMașina virtuală a fost creată și expusă, puteți vedea porturile și nodeport-urile pentru serviciile ssh ale acestora cu comanda 'minikube kubectl -- get svc'."
