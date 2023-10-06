#------------------------------
# 工作目录创建
mkdir_workdir(){
mkdir -p $workdir/{etcd,k8s}
mkdir -p $etcd_workdir
mkdir -p $kube_workdir
echo -e "\e[1;40m workdir is $workdir\e[0m"
}
#------------------------------
# cfssl 工具下载
install_cfssl(){
downprefix=/opt/tools/cfssl
mkdir -p ${downprefix}
echo "please wait ..."
which unzip 2>&1 >/dev/null
([[ $? -ne 0  ]] &&  yum -y install unzip &>/dev/null) || echo "please down the unzip tool"
wget -c https://gitee.com/hukenis/tools/raw/main/cfssl/cfssl_tools.zip -P  ${downprefix}
unzip ${downprefix}/cfssl_tools.zip  -d  ${downprefix}
chmod +x ${downprefix}/cfssl-certinfo_linux-amd64
chmod +x ${downprefix}/cfssljson_linux-amd64
chmod +x ${downprefix}/cfssl_linux-amd64

ln -s ${downprefix}/cfssl-certinfo_linux-amd64   /usr/local/bin/cfssl-certinfo
ln -s ${downprefix}/cfssljson_linux-amd64        /usr/local/bin/cfssljson
ln -s ${downprefix}/cfssl_linux-amd64            /usr/local/bin/cfssl
}


#------------------------------
# 证书模板下载-01
down_cert_template(){
mkdir -p  $workdir/{etcd,k8s}
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/etcd_/ca-config.json"     -O ${etcd_workdir}/ca-config.json
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/etcd_/ca-csr.json"        -O ${etcd_workdir}/ca-csr.json
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/etcd_/etcd-csr.json.tmp"  -O ${etcd_workdir}/etcd-csr.json.tmp

wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/kube_/ca-config.json" -O ${kube_workdir}/ca-config.json
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/kube_/ca-csr.json"    -O ${kube_workdir}/ca-csr.json
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/kube_/k8s-csr.json.tmp"                       -O ${kube_workdir}/k8s-csr.json.tmp
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/kube_/kube-controller-manager-csr.json"       -O ${kube_workdir}/kube-controller-manager-csr.json 
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/kube_/kube-scheduler-csr.json"                -O ${kube_workdir}/kube-scheduler-csr.json  
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/kube_/admin-csr.json"                         -O ${kube_workdir}/admin-csr.json
wget -c   "https://gitee.com/hukenis/tools/raw/main/cert_template/kube_/kube-proxy-csr.json"                    -O ${kube_workdir}/kube-proxy-csr.json
}

#------------------------------
# 证书模板下载-02 
main_downcerttemp(){
echo "downfile path is /opt/cert/$now"
echo "please wait , downloading ca & csr template file   ....."
down_cert_template &>/dev/null ; echo "downloading ...... "
}


#------------------------------
# 生成适用于当前etcd集群的证书
sed_etcdCSR(){
tempfile=$etcd_workdir/etcd-csr.json.tmp
generate_file=$etcd_workdir/etcd-csr.json
etcd_counts=`grep etcd   $inventory |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'|wc -l`
etcd_ip=(`grep etcd   $inventory |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'`)
max_count=$(( $etcd_counts -1    ))

# echo $etcd_counts
# echo ${etcd_ip[@]}

cp -rf $tempfile $generate_file
for count in `seq 0 $max_count`
do
    cluster_ip=${etcd_ip[${count}]}
    first_ip=${etcd_ip[0]}
    if [[ $count -ne $max_count ]];then
    sed -ri "/host/a\    \"$cluster_ip\","  $generate_file
    else
    sed -ri "/],/i\    \"$cluster_ip\""  $generate_file
    fi
done
echo -e "\e[1;45m [NOTICE]: Etcd cluster's Cert configure is Generated , please use command \"cat\" or \"vim\" to confirm here : $generate_file .\e[0m"
echo -e "\e[1;45m [NOTICE]: Currently only adaptive adjustments are made to inventory addresses \e[0m"
echo -e "\e[1;45m [NOTICE]: If you want to reserve future expandable addresses for your cluster, be sure to manually add and confirm them \e[0m "
}

#------------------------------
# 生成适用于当前kube-apiserver集群的证书
sed_kubeapiCSR(){
tempfile=$kube_workdir/k8s-csr.json.tmp
generate_file=$kube_workdir/k8s-csr.json
master_counts=`egrep 'master|node'   $inventory  |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'|sort | uniq |wc -l`
master_ip=(`egrep 'master|node'   $inventory  |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'`)
# 此处变量虽写是master，实际是所有kube集群的ip

max_count=$(( $master_counts -1    ))

# echo $master_counts
# echo ${master_ip[@]}


cp -rf $tempfile $generate_file
for count in `seq 0 $max_count`
do
    cluster_ip=${master_ip[${count}]}
#     if [[ $count -eq $max_count ]];then
#     sed -ri  "/  \"kubernetes\"/i\      \"${cluster_ip}\" "      $generate_file
#     else
      sed -ri  "/  \"kubernetes\"/i\      \"${cluster_ip}\", "     $generate_file
#     fi
done
echo -e "\e[1;45m [NOTICE]: Kube cluster's Cert configure is Generated , please use command \"cat\" or \"vim\" to confirm here : $generate_file .\e[0m"
echo -e "\e[1;45m [NOTICE]: Currently only adaptive adjustments are made to inventory addresses \e[0m"
echo -e "\e[1;45m [NOTICE]: If you want to reserve future expandable addresses for your cluster, be sure to manually add and confirm them \e[0m "
}

#------------------------------
# 自签ETCD 证书
# Self -signed certificate
etcd_self_sign(){
cd $etcd_workdir
pem_list="
ca-key.pem
ca.pem
etcd-key.pem
etcd.pem
"
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www etcd-csr.json | cfssljson -bare etcd
for i in $pem_list
do 

  if  [[ -z  `ls $i`  ]];then
	echo -e "\e[1;41m [ERROR]: SelfSign Cert is abnormal, Fail to generate $i ,Exiting soon, please manually check and implement! \e[0m"
	exit 
  fi
  echo -e "\e[1;45m Etcd selfSign Certfile $i is generated\e[0m"
done 
cp -rf *.pem $ansible_etcdfile/files/etcd_cert/
cp -rf *.pem $ansible_kubefile/files/etcd_cert/
}

#------------------------------
# 自签KUBE 证书
# Self -signed certificate
kube_self_sign(){
cd $kube_workdir
pem_list="
admin-key.pem
admin.pem
ca-key.pem
ca.pem
k8s-key.pem
k8s.pem
kube-controller-manager-key.pem
kube-controller-manager.pem
kube-proxy-key.pem
kube-proxy.pem
kube-scheduler-key.pem
kube-scheduler.pem
"
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes k8s-csr.json | cfssljson -bare k8s
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
cp -rf *.pem $ansible_kubefile/files/k8s_cert/
for i in $pem_list
do 

  if  [[ -z  `ls $i`  ]];then
	echo -e "\e[1;41m [ERROR]: SelfSign Cert is abnormal, Fail to generate $i ,Exiting soon, please manually check and implement! \e[0m"
	exit 
  fi
  echo -e "\e[1;45m Kube selfSign Certfile $i is generated\e[0m"
done 
cp -rf *.pem $ansible_kubefile/files/k8s_cert/
cp -rf *.pem $ansible_nodefile/files/k8s_cert/

}
