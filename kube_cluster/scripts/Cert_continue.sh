#!/bin/env bash
if [[ -z $1 ]];then
	echo -e "\e[1;40m [Usage]: $0 [token] \e[0m";exit
fi
token=$1
varfile=${token}.var

if [[ -z  `ls history | grep -o  $varfile` ]];then
     echo -e "\e[1;41m  $varfile is not exist, please confirm your token\e[0m";exit
else
     source history/$varfile
fi


source   Cert_function.sh

etcd_self_sign
kube_self_sign
