pending_node=`kubectl get csr |  awk '/Pending/{print $1}'`
for i in $pending_node
do 
	kubectl certificate approve $i && sleep 2
done
