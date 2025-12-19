echo "Setting up storage test directory..."
echo "GCRNODE: $GCRNODE"
#california timrstamp
timestamp=$(date +%Y%m%d_%H%M%S -d 'TZ="America/Los_Angeles" now')
echo "Timestamp: $timestamp"
mkdir -p /data/storage-tests/$GCRNODE/$timestamp
echo "Storage test directory set up at /data/storage-tests/$GCRNODE/$timestamp"


"""

sdsd



""""