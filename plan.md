Goal : Evalute cluster performance ( CPU& GPU compute , NVLink performance , Network performance (IB) , Numerical correctness, Scalability etc)

## phases
1. Preparation
   - Define performance metrics and benchmarks to be used.
   - Set up monitoring tools to capture performance data.
   - Ensure all necessary software and drivers are installed on the cluster nodes.

2. Logs and Monitoring Setup - start
   - Dmesg logging configuration
   - STDOUT/STDERR logging configuration
   - Performance monitoring tools setup (e.g., Prometheus, Grafana)

3. Network Performance Testing
    - ping test on google.com to check basic connectivity
    - iperf3 test between cluster nodes to measure bandwidth and latency


4. DL Unit Tests
   - Run DL unit test on individual nodes to verify GPU functionality and performance.

5. Npair tests
   - Latency test
    - Bandwidth test
    - Message rate test

6. Scalability Tests
   1. Latency test
    1.1. SHARP enabled
    1.2. SHARP disabled
   2. Bandwidth test
    2.1. SHARP enabled
    2.2. SHARP disabled


7. Logs and Monitoring Setup - end
   - Collect and analyze logs from dmesg, STDOUT/STDERR.
   - Review performance data from monitoring tools.
   - Ship logs and performance reports to designated storage or analysis team.

8. Reporting
   - Compile results from all tests into a comprehensive report.






