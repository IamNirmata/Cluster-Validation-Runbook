
## PVC
mkdir -p /data/cluster_validation/npairs
mkdir -p /data/cluster_validation/dltest
mkdir -p /data/cluster_validation/scalability
mkdir -p /data/cluster_validation/network
mkdir -p /data/cluster_validation/dmesg
today=$(date +%Y%m%d)

if [ ! -d /data/cluster_validation/dltest/"$today" ]; then
  mkdir /data/cluster_validation/dltest/"$today"
fi

if [ ! -d /data/cluster_validation/npairs/"$today" ]; then
  mkdir /data/cluster_validation/npairs/"$today"
fi

if [ ! -d /data/cluster_validation/scalability/"$today" ]; then
  mkdir /data/cluster_validation/scalability/"$today"
fi

if [ ! -d /data/cluster_validation/network/"$today" ]; then
  mkdir /data/cluster_validation/network/"$today"
fi

if [ ! -d /data/cluster_validation/dmesg/"$today" ]; then
  mkdir /data/cluster_validation/dmesg/"$today"
fi



ln -sfn /data/cluster_validation/dltest/"$today" /data/cluster_validation/dltest/latest
ln -sfn /data/cluster_validation/npairs/"$today" /data/cluster_validation/npairs/latest
ln -sfn /data/cluster_validation/scalability/"$today" /data/cluster_validation/scalability/latest
ln -sfn /data/cluster_validation/network/"$today" /data/cluster_validation/network/latest
ln -sfn /data/cluster_validation/dmesg/"$today" /data/cluster_validation/dmesg/latest