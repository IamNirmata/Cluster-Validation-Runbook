apt-get update && apt-get install -y fio

echo "Setting up storage test directory..."
echo "GCRNODE: $GCRNODE"
#california timrstamp
timestamp=$(date +%Y%m%d_%H%M%S -d 'TZ="America/Los_Angeles" now')
echo "Timestamp: $timestamp"
mkdir -p /data/storage-tests/$GCRNODE/$timestamp
echo "Storage test directory set up at /data/storage-tests/$GCRNODE/$timestamp"


"""
numjobs read nfiles test
fio numjobs_read_nfiles.fio --output-format=json --output=/data/storage_test/output/numjobs_read_nfiles.json


Numjobs write nfiles test
fio numjobs_write_nfiles.fio --output-format=json --output=/data/storage_test/output/numjobs_write_nfiles.json


Iodepth read 1file test
fio iodepth_read_1file.fio --output-format=json --output=/data/storage_test/output/iodepth_read_1file.json


Iodepth write 1file test
fio iodepth_write_1file.fio --output-format=json --output=/data/storage_test/output/iodepth_write_1file.json


Random read test
fio randread.fio --output-format=json --output=/data/storage_test/output/randread.json


Random write test
fio randwrite.fio --output-format=json --output=/data/storage_test/output/randwrite.json

"""

#write test then read test
echo "Starting storage tests..."

fio write_then_read.fio --output-format=json --output=/data/storage-tests/$GCRNODE/$timestamp/write_then_read.json
