

# ansible-kube集群部署项目简述

## 1.目录要求

介于证书生成文件和一些脚本使用了绝对路径(暂时懒得改)；必须将包解压到对应路径下。

工作路径必须为   `/ansible/Playbooks/k8s_deploy `

## 2.目录结构以及功能概要

```

├── k8s_deploy                         #  项目位置
│   ├── initialize.yaml                # 集群初始化入口
│   ├── install_etcd.yaml              # etcd 安装入口
│   ├── install_master.yaml            # master 安装入口
│   ├── install_node.yaml              # work node 安装入口
│   ├── log_inventroy                  # 历史inventory 备份 
│   ├── _new.hosts                     # 集群inventory 清单 
│   ├── README                         # 自述手册
│   ├── roles                          # 任务路径
│   ├── scripts                        # 证书脚本路径，必须部署之前必须先生成证书！ 
│   ├── start.sh                       # 主要的部署脚本，集合了入口yaml以及一些必要的初始化功能
```

```
├── roles
│   ├── env_prepare      # 所有设备初始化任务
│   ├── install_docker   # worknode 容器部署任务
│   ├── install_etcd     #  etcd 集群部署任务
│   ├── install_master   #  master 集群部署及授权文件生成任务
│   ├── install_node     #  worknode 部署任务
│   ├── kernel_upgrade   # 内核升级任务
├── scripts              # 自签证书脚本
│   ├── Cert_continue.sh     # 手动自签时执行
│   ├── Cert_function.sh     # 函数库导入-脚本主要功能
│   ├── Cert_Generate.sh     # 自签脚本主文件  --auto 自动生成  --manul 人工确认后生成，使用对应token执行Cert_continue，以完成证书自签。
│   ├── history                   # 自签历史记录
│   │   └── ff12c3ef5c4f27d.var   # manul 选项的必要引用变量，文件名为随机token，执行Cert_Generate时生成
│   └── var                       # 函数以及脚本变量位置
│       └── generate_var          # 执行Cert_Generate时被导入。
└── start.sh                      # 主要的部署脚本，集合了入口yaml以及一些必要的初始化功能
```

## 3.脚本说明

### start.sh

`脚本逻辑&执行序列`

> 1. 检查资产清单中集群成员是否齐全
> 2. 生成适用于当前集群的证书
> 3. 生成适用于当前集群的host解析文件
> 4. 生成适用于当前集群的etcd配置文件
> 5. 生成适用于当前集群的apiserver 配置文件
> 6. 对所有集群的成员进行初始化配置，升级内核并重启
> 7. 检测集群是否被正常重启，一旦online，即开始执行下一步。
> 8. 部署etcd 集群
> 9. 部署master 节点
> 10. 在master上生成kubelet 、kube-proxy的集群申请配置，并拉回本地
> 11. 部署node节点
> 12. 在mater上放行work加入集群
> 13. 部署cni 、coredns 插件 

```
check_inventory                                         # 检查资产清单中集群成员是否齐全
# (cd  scripts && Cert_Generate.sh  --auto)             #  生成适用于当前集群的证书
adaptiving_host                                         # 生成适用于当前集群的host解析文件
adaptiving_etcd_cfg                                     # 生成适用于当前集群的etcd配置文件
adaptiving_apiserver_cfg                                # 生成适用于当前集群的apiserver 配置文件
ansible-playbook -i  $work_dir/_new.hosts   initialize.yaml  #  对所有集群的成员进行初始化配置 
echo -e "\e[1;40m kernel is upgrade, machines are reboot, please waiting ....\e[0m" && sleep 30 
fping_cluster                                           # 内核升级后会被重启，检测集群是否被正常重启，一旦online，即开始执行下一步。
ansible-playbook -i  $work_dir/_new.hosts   install_etcd.yaml           # 部署etcd 集群
ansible-playbook -i  $work_dir/_new.hosts   install_master.yaml         # 部署master 节点 
pull_master_kubecfgfile		   									  # 在master上生成kubelet 、kube-proxy的集群申请配置，并拉回本地
ansible-playbook -i  $work_dir/_new.hosts   install_node.yaml  # 部署node节点
master_authorization			      							  # 在mater上放行work加入集群
master_apply_network_plugin    							   # 部署cni 、coredns 插件 
```

### scripts/

#### Cert_function.sh

```
系 Cert_Generate.sh 的函数库，是自签证书脚本的灵魂。
```

#### Cert_Generate.sh

```
自适应生成当前集群的证书自签文件，有两个选项
./Cert_Generate.sh    --auto        -a    自动生成 ,不预留检查步骤
./Cert_Generate.sh    --manul     -m   生成自签配置后结束，除了CA外，不生成任何证书
执行 --manul -m 参数后会给出一个token，可以使用此token执行Cert_continue.sh ，完成集群的证书自签。
```

#### Cert_continue.sh

```
必须以 Cert_Generate.sh 脚本所生产的token作为参数执行，会导入此token同名的历史变量，执行证书自签功能
./Cert_continue.sh   [token]  
```

#### var/generate_var

```
系 所有脚本的变量依赖，与函数库脚本同样重要。
```

#### history/token.var

```
执行证书自签时，会将每次的任务变量存储到此处；Cert_continue.sh 将以此文件来区别执行自签任务。
```

#### 证书存放点

```
于CA服务器的 /opt/cert/日期+token 的目录中；可以在history中查到。
```



### yaml入口

> 介于kube集群的复杂部署，分出四个负责不同部署阶段的入口yaml。yaml入口会被start.sh脚本集成，辅以start.sh内置的功能，共同组成完备的部署序列。

- **initialize.yaml**  `所有集群的初始化任务，内核升级、基础软件安装、调优等等`
- **install_etcd.yaml**  `etcd 集群的部署入口`
- **install_master.yaml**  `master 节点的部署入口`
- **install_node.yaml** `node 节点的部署入口`

### 4.role 角色说明

- **env_prepare**            `所有集群节点的初始化任务`
- **kernel_upgrade**       `内核升级任务` 
- **install_etcd**              `etcd 集群部署任务`
- **install_master**          `master集群的部署任务`
- **install_docker**          `docker环境部署`
- **install_node**             `work节点部署`

​                                                                               

# 触发顺序：

> 证书自签后，在不同任务的部署过程中对应发放。

​      start.sh ==>  证书自签 ==> 生成自适应配置 ==> 初始化所有设备 ==> 安装etcd集群 ==> 安装master集群 ==> 安装work节点 ==> 加载cni插件以及coredns

#  配置备注项：

- 如果使用的10网段，service网段建议改成192；反则亦然。
- coredns 解析测试失败，可以重启pod再测试。

# 部署后测试：

```
- 部署一个busybox，可以另立命名空间；使用busybox容器中的nslookup命令解析kebernetes以及service域名；
- 在work节点 telnet serviceip:443 或53 端口
eg： 
kubectl exec  busybox_test_20230924 -n test_ns  -- nslookup kubernetes
kubectl exec  busybox_test_20230924 -n test_ns  -- nslookup kubernetes.default.svc.cluster.local
telnet  service_ip  service_por
```
**源码地址：https://github.com/Hukenis/ansible_project.git**
