# Qualcomm QCE

* Android bound QCE at `fd400000.qcom, qcedev`; it uses BAM DMA.
* A native QCE module exists, but board DT/DMA/clock integration and exact
  engine version have not been accepted. No crypto-vector or throughput
  acceptance is recorded. Android probe is not a usable native crypto path.
