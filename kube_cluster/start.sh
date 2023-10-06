#!/bin/env bash


# load scripts var 
# 指定工作目录，加载脚本变量

work_dir="/ansible/Playbooks/k8s_deploy"
roles_dir="${work_dir}/roles"
etcd_dir="${roles_dir}/install_etcd"
master_dir="${roles_dir}/install_master"
node_dir="${roles_dir}/install_node"
now=`date +%H%M%S`
cd $work_dir

# ----------------------------------------

# all of nodes  
# 从inventory中读取所有节点IP
master_counts=`grep master   $work_dir/_new.hosts |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'| wc -l `
node_counts=`grep node   $work_dir/_new.hosts |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'|wc -l`
etcd_counts=`grep etcd   $work_dir/_new.hosts |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'|wc -l`

master_ip=(`grep master   $work_dir/_new.hosts |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'`)
node_ip=(`grep node   $work_dir/_new.hosts |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'`)
etcd_ip=(`grep etcd   $work_dir/_new.hosts |egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}'`)

all_cluster_ip=(`egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}' $work_dir/_new.hosts | sort -n |uniq `)
all_cluster_counts=(`egrep -o  '([0-9]{1,3}\.){1,3}[0-9]{1,3}' $work_dir/_new.hosts| sort -n |uniq  | wc -l `)
# ----------------------------------------
# Check cluster inventroy
# 检查集群角色是否完备: master\node\etcd
check_inventory(){
if [[ ${master_counts} -eq 0  ]];then 
   echo "Please check whether there are master devices for inventory ! ";exit 
fi

if [[ ${node_counts} -eq 0  ]];then 
   echo "Please check whether there are node devices for inventory ! ";exit 
fi

if [[ ${etcd_counts} -eq 0  ]];then 
   echo "Please check whether there are etcd devices for inventory ! ";exit 
fi
}

# ----------------------------------------
# Adaptiving hosts file 
# 生成适用于当前集群的hosts解析文件
adaptiving_host(){
save_path=$work_dir/roles/env_prepare/files
for master_count in `seq 0 $((${master_counts}-1)) `
do 
 ip=${master_ip[$master_count]}
 ip_Last_two=${ip##*.}
 echo "$ip     k8s-master-${ip_Last_two}"  >$save_path/_hosts.txt
 ssh $ip "hostnamectl set-hostname k8s-master-${ip_Last_two}"
done 


for node_count in `seq 0 $((${node_counts}-1)) `
do 
 ip=${node_ip[$node_count]}
 ip_Last_two=${ip##*.}
 echo "$ip     k8s-node-${ip_Last_two}"  >>$save_path/_hosts.txt
 ssh $ip "hostnamectl set-hostname k8s-node-${ip_Last_two}"
done 


for etcd_count in `seq 0 $((${etcd_counts}-1)) `
do 
 ip=${etcd_ip[$etcd_count]}
 ip_Last_two=${ip##*.}
 echo "$ip     k8s-node-${ip_Last_two}"  >>$save_path/_hosts.txt
#  ssh $ip "hostnamectl set-hostname k8s-etcd-${ip_Last_two}"     #主机名设定说明：etcd集群与k8s集群耦合时禁用 ; etcd集群与k8s集群解耦时开启。
done 
}

# ----------------------------------------
# adaptiving etcd template configure
# 生成适用于当前etcd集群的配置模板文件
adaptiving_etcd_cfg(){
cluster_urls=()
# cluster_netcard=`ansible -i $work_dir/_new.hosts etcd -m setup -a 'filter=*interface*' | egrep  'ens|eth|eno'  | cut -d '"' -f 2`
for cluster_count in `seq 0 $(( ${etcd_counts} -1   ))`
do
   cluster_ip=${etcd_ip[$cluster_count]}
   cluster_ip_lasttwo=${cluster_ip##*.}
   # cluster_urls=([$cluster_count]="etcd-${cluster_ip_lasttwo}=https://${cluster_ip}:2380,")
   cluster_url="etcd-${cluster_ip_lasttwo}=https://${cluster_ip}:2380,"   
   cluster_urls[${cluster_count}]=${cluster_url}
done 
cluster_urls=`echo ${cluster_urls[*]}|sed 's/ //g'| awk -F ',' '{sub(/.$/,"")}1'`
# sed -r -e "s/cluster_node/etcd-${cluster_ip_lasttwo}/"  -e "s|clusters-2380|${cluster_urls}|"  ${etcd_dir}/files/etcd_cfg.tmp > ${etcd_dir}/templates/etcd.conf.j2
sed -r  "s|clusters-2380|${cluster_urls}|"  ${etcd_dir}/files/etcd_cfg.tmp > ${etcd_dir}/templates/etcd.conf.j2
}


# ----------------------------------------
# adaptiving apiserver template configure
# 生成适用于当前apiserver集群的配置模板文件
adaptiving_apiserver_cfg(){  
cluster_etcd_urls=()
# cluster_apiserver_netcard=`ansible -i $work_dir/_new.hosts master -m setup -a 'filter=*interface*' | egrep  'ens|eth|eno'  | cut -d '"' -f 2`
for cluster_etcd_count in `seq 0 $(( ${etcd_counts} -1   ))`
do
   cluster_etcd_ip=${etcd_ip[$cluster_count]}
   cluster_etcd_url="https://${cluster_ip}:2379," 
   cluster_etcd_urls[${cluster_etcd_count}]=${cluster_etcd_url}
done
cluster_etcd_urls=`echo ${cluster_etcd_urls[*]}|sed 's/ //g'| awk -F ',' '{sub(/.$/,"")}1'`
# sed -r -e "s|etcd_all_cluster|${cluster_etcd_urls}|" -e "s|ens3|${cluster_apiserver_netcard}|g"  ${master_dir}/files/apiserver_config.tmp  > ${master_dir}/templates/kube-apiserver.conf.j2
sed -r "s|etcd_all_cluster|${cluster_etcd_urls}|"  ${master_dir}/files/apiserver_config.tmp  > ${master_dir}/templates/kube-apiserver.conf.j2
token=`head -c 16 /dev/urandom | od -An -t x | tr -d ' '`
echo "${token},kubelet-bootstrap,10001,\"system:node-bootstrapper\"" > ${master_dir}/files/token.csv
sed -ir "s/^bootstrap_token.*$/bootstrap_token: ${token}/g"  ${master_dir}/vars/main.yaml
}


# ----------------------------------------
# 生成kubelet和kube-proxy授权文件，并拉回
pull_master_kubecfgfile(){
cluster_ip=${master_ip[0]}
cluster_ip_lastnum=${cluster_ip##*.}
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m shell -a "bash /opt/tools/bootstrap_kubecfg.sh"
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m shell -a "bash /opt/tools/kube-proxy_kubecfg.sh"

ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m synchronize -a "mode=pull  src=/opt/k8s/kubernetes/cfg/bootstrap.kubeconfig dest=${work_dir}/roles/install_node/files/"
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m synchronize  -a "mode=pull src=/opt/k8s/kubernetes/cfg/kube-proxy.kubeconfig dest=${work_dir}/roles/install_node/files/"
}


# ----------------------------------------
# 授权 kubelet 加入集群 以及 kubectl 权限
master_authorization(){
cluster_ip=${master_ip[0]}
cluster_ip_lastnum=${cluster_ip##*.}
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m shell -a "bash /opt/tools/authorization_bootstrap.sh || echo '执行异常'"
sleep 2
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m shell -a "bash /opt/tools/approve_node.sh || echo '执行异常!'"
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m shell -a "kubectl create clusterrolebinding apiserver-kubelet-admin --user=kubernetes --clusterrole=system:kubelet-api-admin || echo '执行异常!'"     
}


# ----------------------------------------
# 部署cni、coredns 组件
master_apply_network_plugin(){
cluster_ip=${master_ip[0]}
cluster_ip_lastnum=${cluster_ip##*.}
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m shell -a "kubectl apply -f  /opt/k8s/kubernetes/cni/calico.yaml || echo '执行异常!'"     
ansible -i $work_dir/_new.hosts k8s-master-${cluster_ip_lastnum}  -m shell -a "kubectl apply -f  /opt/k8s/kubernetes/coredns/coredns.yaml || echo '执行异常!'"     
}


#------------------------------------------
# 检测集群重启
fping_cluster(){
count=0
until (fping -q ${all_cluster_ip[*]})
do
       if [[ $count -le 900  ]];then
         let count+=1
         fping -q -t 100 ${all_cluster_ip[*]} && break
       else
	 echo -e "\e[1;41m The device reboot  time has overed 15 Minutes, Please manually Check all devices \e[0m" && exit 
       fi
done 
}

check_inventory
(cd  scripts && . Cert_Generate.sh  --auto)
adaptiving_host
adaptiving_etcd_cfg
adaptiving_apiserver_cfg
# ansible-playbook -i  $work_dir/_new.hosts   initialize.yaml 
# echo -e "\e[1;40m kernel is upgrade, machines are reboot, please waiting ....\e[0m" && sleep 30
fping_cluster 
ansible-playbook -i  $work_dir/_new.hosts   install_etcd.yaml 
ansible-playbook -i  $work_dir/_new.hosts   install_master.yaml
pull_master_kubecfgfile
ansible-playbook -i  $work_dir/_new.hosts   install_node.yaml
master_authorization
master_apply_network_plugin
