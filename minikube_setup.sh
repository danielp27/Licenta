#!/bin/bash

#În caz că script-ul este întrerupt de erori sau Ctrl-C
cleanup() {
        echo -e "\nScript-ul a fost întrerupt neașteptat, datele nu se salvează.\n"
        minikube delete
		exit 1
}

trap cleanup INT TERM ERR

trap 'trap - INT TERM ERR' EXIT

# Verifică dacă Minikube este instalat, instalându-l dacă nu
if ! command -v minikube >/dev/null 2>&1
then
    	echo -e "\nminikube nu este instalat, se instalează...\n"
    	curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    	sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
fi

# Verifică dacă docker este instalat și pornit
if ! command -v docker >/dev/null 2>&1
then
    	echo -e "\nDocker nu este instalat, pentru a folosi acest script, instalați-l și porniți-l.
    	Poate vă ajută acest link: https://docs.docker.com/engine/install/\n"
	exit 1
elif ! docker info > /dev/null 2>&1; then
  	echo -e "\nDocker nu este pornit și/sau nu aveți permisiuni.
	Pentru a folosi acest script trebuie să-l porniți și/sau să vă adăugați utilizatorul în grupul 'docker'.
	Poate vă ajută acest link: https://docs.docker.com/engine/install/\n"
  	exit 1
fi

echo -e "\nSe pornește minikube cu docker...\n"

minikube start --driver=docker

minikube addons enable metrics-server # Se instalează metrics-server ca extensie Minikube

echo -e "\nSe face deploy la operatorul KubeVirt...\n"

export VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt);
echo $VERSION;
minikube kubectl -- create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml" 
minikube kubectl -- create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml"

echo -e "\nSe inițializează componentele KubeVirt (poate dura câteva minute)..."
# Se așteaptă până când componentele au fost inițializate
while [ "$(minikube kubectl -- get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.phase}")" != "Deployed" ]
do
	sleep 5
done

echo -e "\nS-au inițializat componentele KubeVirt."

# Se instalează virtctl dacă nu este instalat
if ! command -v virtctl >/dev/null 2>&1
then
	echo -e "virtctl  nu este instalat, se instalează...\n"
	VERSION=$(minikube kubectl -- get kubevirt.kubevirt.io/kubevirt -n kubevirt -o=jsonpath="{.status.observedKubeVirtVersion}")
	ARCH=$(uname -s | tr A-Z a-z)-$(uname -m | sed 's/x86_64/amd64/') || windows-amd64.exe
echo ${ARCH}
	curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-${ARCH}
	chmod +x virtctl
	sudo install virtctl /usr/local/bin
fi

echo -e "\nSe instalează CDI (Containerized Data Importer)...\n"

export VERSION=$(basename $(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest))
minikube kubectl -- create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
minikube kubectl -- create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml

echo -e "\nSe face deploy la CDI CR (CustomResource)..."
# Se așteaptă până când capsulele CDI au fost inițializate
while [ "$(minikube kubectl -- get cdi cdi -n cdi | awk 'NR==2 {print $3}')" != "Deployed" ]
do
	sleep 5
done

echo -e "\nSa făcut deploy la CDI CR.\n"
echo -e "Mediul de lucru Minikube și KubeVirt a fost instalat/pregătit.\n"
