if [[ ! -e  /ansible/Playbooks/k8s_deploy/scripts/var/generate_var ]];then
echo -e "\e[1;41m Variate file LOST !! \e[0m";exit 
fi


if [[ ! -e /ansible/Playbooks/k8s_deploy/scripts/Cert_function.sh  ]];then
echo -e  "\e[1;41m Function file LOST !! \e[0m";exit 
fi


source   /ansible/Playbooks/k8s_deploy/scripts/var/generate_var
source   /ansible/Playbooks/k8s_deploy/scripts/Cert_function.sh

saving_history(){
echo "workdir=$workdir"  >>$history_var/$token.var
echo "etcd_workdir=$etcd_workdir"  >>$history_var/$token.var
echo "kube_workdir=$kube_workdir"  >>$history_var/$token.var
echo "ansible_etcdfile=$ansible_etcdfile" >>$history_var/$token.var
echo "ansible_kubefile=$ansible_kubefile" >>$history_var/$token.var
echo "ansible_nodefile=$ansible_kubefile" >>$history_var/$token.var
}

check_cfssl(){
which cfssl 2>&1 1>/dev/null
if  [[  $? -ne 0  ]];then
        install_cfssl
else
        echo -e "\e[1;40m cfssl was existed your computer [❤️] \e[0m"
fi
}


confirm_(){
echo -e "\e[1;45m [NOTICE]: The token of this operation is $token \e[0m"
echo -e "\e[1;45m [NOTICE]: Please check the cluster_ip in the file:\nCertdir of etcd: $etcd_workdir\nCertdir of kube: $kube_workdir \e[0m"
echo -e "\e[1;40m [NOTICE]: Use Token:$token to execute the script \"Cert_continue.sh\"  manually after confirming the configuration \e[0m"
}

auto_(){
mkdir_workdir
saving_history
check_cfssl
down_cert_template
sed_etcdCSR
sed_kubeapiCSR
etcd_self_sign
kube_self_sign
}

manual_(){
mkdir_workdir
saving_history
check_cfssl
down_cert_template
sed_etcdCSR
sed_kubeapiCSR
confirm_
}

main(){
case $1 in 
 --auto|-a)
   auto_
   ;;
 --manual|-m)
   manual_
   ;;
 --help|-h)
   echo -e "\e[1;40m [Usage]: ./$0 [--option] \n --auto     -a   Auto-deploy, do not confirm configuration\n --manual   -m   Manually deploy after confirmed the configuration \e[0m"
   ;;
   *)
   echo -e "\e[1;40m [Usage]: ./$0 [--option] \e[0m"
   exit 
esac
}

main $1
