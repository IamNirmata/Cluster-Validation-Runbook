echo "Setting up storage test directory..."
echo "GCRNODE: $GCRNODE"
#california timrstamp
timestamp=$(date +%Y%m%d_%H%M%S -d 'TZ="America/Los_Angeles" now')
mkdir -p /data/storage-tests/