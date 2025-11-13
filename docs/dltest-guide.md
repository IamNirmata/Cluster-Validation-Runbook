# Deep Learning Unit Test – Quick Steps

Minimal steps to launch the Volcano job defined in `ymls/dltest.yml`.

## 1. Check the manifest

- `replicas: n` under the `server` task (adjust if needed).
- Image `nvcr.io/nvidia/pytorch:25.06-py3` available to your cluster. This image exactly matches our baseline test environment so that results are comparable.
- PVC directory exists and is RW enabled for `/data`. ( preferably, otherwise modify the output path $logdir in the script in 00-env.sh )
- Command `/opt/deeplearning_unit_test/run_b200.sh 8` points at the right script and GPU count.

## 2. Run it

```bash
kubectl apply -f ymls/dltest.yml
```

## 3. Watch it

Things to watch
 1. dmesg logs for GPU errors
 2. Volcano job status
 3. STDOUT and STDERR

## 4. Grab outputs

- Results stored under `/data` in each pod ( preferably PVC so logs are secure).
- A seperate log file for each rank will be created in the /opt/deeplearning_unit_test/ directory.
## 5. Clean up

```bash
kubectl delete -f ymls/dltest.yml
```

Remove any temporary secrets once done.
